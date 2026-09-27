import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../ai/letterbox.dart';
import '../ai/onnx_service.dart';
import '../ai/yolo_seg_decoder.dart';
import '../painter/advanced_nail_painter.dart';
import '../services/roboflow_cloud_service.dart';
import 'frame_prep.dart';
import 'polygon_decode.dart';
import 'raw_camera_frame.dart';

class InferenceWorkerResult {
  final List<List<Offset>> polygons;
  final List<NailPoseKeypoints?> poseKeypoints;
  final int originalWidth;
  final int originalHeight;
  final Duration inferenceTime;

  InferenceWorkerResult({
    required this.polygons,
    this.poseKeypoints = const [],
    required this.originalWidth,
    required this.originalHeight,
    required this.inferenceTime,
  });
}

class InferenceWorker {
  final OnnxService _onnxService = OnnxService();
  bool _isInitialized = false;

  Future<void> init() async {
    if (_isInitialized) return;
    await _onnxService.initModel();
    _isInitialized = true;
  }

  /// LEGACY: Pure local ONNX (Segmentation + Pose).
  /// Giữ nguyên cho backwards compat — snapshot page không còn dùng.
  Future<InferenceWorkerResult> processFrame(
    img.Image frameImage, {
    double confThreshold = 0.60,
    double iouThreshold = 0.45,
    double maskThreshold = 0.5,
  }) async {
    final stopwatch = Stopwatch()..start();
    await init();

    final rawOutputs = await _onnxService.runInference(
      frameImage,
      useArModel: false,
    );
    final polygons = YoloSegDecoder.decode(
      rawOutputs: rawOutputs,
      confThreshold: confThreshold,
      iouThreshold: iouThreshold,
      maskThreshold: maskThreshold,
    );

    final rawPoses = await _onnxService.runPoseInferenceOnTensor(
      rawOutputs.letterbox,
    );
    final List<NailPoseKeypoints?> matchedPoses = List.filled(
      polygons.length,
      null,
    );
    final List<Map<String, dynamic>> pairs = [];
    for (int i = 0; i < polygons.length; i++) {
      final Offset c = _centroid(polygons[i]);
      for (int j = 0; j < rawPoses.length; j++) {
        final pose = rawPoses[j];
        final double poseLen = (pose.tip - pose.base).distance;
        if (poseLen < 2.0) continue;
        final Offset poseMid = Offset(
          (pose.tip.dx + pose.base.dx) / 2,
          (pose.tip.dy + pose.base.dy) / 2,
        );
        final double dist = (c - poseMid).distance;
        if (dist < 120.0) pairs.add({'polyIdx': i, 'poseIdx': j, 'dist': dist});
      }
    }
    pairs.sort((a, b) => (a['dist'] as double).compareTo(b['dist'] as double));
    final Set<int> usedPolys = {};
    final Set<int> usedPoses = {};
    for (final pair in pairs) {
      final int polyIdx = pair['polyIdx'];
      final int poseIdx = pair['poseIdx'];
      if (!usedPolys.contains(polyIdx) && !usedPoses.contains(poseIdx)) {
        matchedPoses[polyIdx] = rawPoses[poseIdx];
        usedPolys.add(polyIdx);
        usedPoses.add(poseIdx);
      }
    }

    final combined = _sortByX(polygons, matchedPoses);
    stopwatch.stop();

    debugPrint('==================================================');
    debugPrint('[LOCAL ONNX PIPELINE RESULTS - LEGACY]');
    debugPrint('Mong nhan dien (best.onnx): ${polygons.length}');
    debugPrint('Pose nhan dien (thanhdtPose.onnx): ${rawPoses.length}');
    debugPrint(
      'Tong thoi gian chay local: ${stopwatch.elapsedMilliseconds} ms',
    );
    debugPrint('==================================================');
    return InferenceWorkerResult(
      polygons: combined.polygons,
      poseKeypoints: combined.poses,
      originalWidth: frameImage.width,
      originalHeight: frameImage.height,
      inferenceTime: stopwatch.elapsed,
    );
  }

  /// HYBRID: Roboflow Cloud Segmentation + YOLO Pose local.
  /// - Polygons (viền móng): Roboflow API (cloud).
  /// - Pose keypoints (hướng móng): thanhdtPose.onnx (local).
  ///
  /// Input là raw image bytes (JPEG/PNG). Trả về polygons + matched pose keypoints
  /// theo toạ độ pixel của ảnh gốc (không qua letterbox).
  Future<InferenceWorkerResult> detectWithRoboflow(
    Uint8List imageBytes, {
    int? imageWidth,
    int? imageHeight,
  }) async {
    final stopwatch = Stopwatch()..start();
    await init();

    int width = imageWidth ?? 0;
    int height = imageHeight ?? 0;
    if (width == 0 || height == 0) {
      final decoded = img.decodeImage(imageBytes);
      if (decoded == null) {
        return InferenceWorkerResult(
          polygons: const [],
          originalWidth: 0,
          originalHeight: 0,
          inferenceTime: stopwatch.elapsed,
        );
      }
      width = decoded.width;
      height = decoded.height;
    }

    // 1. Roboflow Cloud Segmentation
    final roboflowResult = await RoboflowCloudService.detectNailsOnline(
      imageBytes,
    );
    if (roboflowResult.polygons.isEmpty) {
      stopwatch.stop();
      debugPrint('==================================================');
      debugPrint('[HYBRID ROBOFLOW + YOLO POSE RESULTS]');
      debugPrint(
        'Roboflow segmentation: 0 mong (api=${stopwatch.elapsedMilliseconds}ms)',
      );
      debugPrint('==================================================');
      return InferenceWorkerResult(
        polygons: const [],
        poseKeypoints: const [],
        originalWidth: width,
        originalHeight: height,
        inferenceTime: stopwatch.elapsed,
      );
    }

    // 2. YOLO Pose local (hướng móng)
    LetterboxResult letterbox;
    try {
      letterbox = LetterboxProcessor.processFromBytes(imageBytes);
    } catch (e) {
      debugPrint('Loi letterbox cho pose inference: $e');
      stopwatch.stop();
      return InferenceWorkerResult(
        polygons: roboflowResult.polygons,
        poseKeypoints: List.filled(roboflowResult.polygons.length, null),
        originalWidth: width,
        originalHeight: height,
        inferenceTime: stopwatch.elapsed,
      );
    }
    final rawPoses = await _onnxService.runPoseInferenceOnTensor(letterbox);

    // 3. Match pose → polygon theo centroid distance
    final matchedPoses = _matchPosesToPolygons(
      roboflowResult.polygons,
      rawPoses,
    );

    // 4. Sort theo X centroid (trái → phải)
    final combined = _sortByX(roboflowResult.polygons, matchedPoses);
    stopwatch.stop();

    debugPrint('==================================================');
    debugPrint('[HYBRID ROBOFLOW + YOLO POSE RESULTS]');
    debugPrint('Roboflow seg: ${roboflowResult.polygons.length} mong');
    debugPrint('YOLO Pose local: ${rawPoses.length} keypoints');
    debugPrint(
      'Tong thoi gian: ${stopwatch.elapsedMilliseconds} ms (Roboflow: ${roboflowResult.inferenceTime.inMilliseconds}ms)',
    );
    debugPrint('==================================================');

    return InferenceWorkerResult(
      polygons: combined.polygons,
      poseKeypoints: combined.poses,
      originalWidth: width,
      originalHeight: height,
      inferenceTime: stopwatch.elapsed,
    );
  }

  Future<InferenceWorkerResult> processCameraFrame(
    RawCameraFrame rawFrame, {
    double confThreshold = 0.60,
    double iouThreshold = 0.45,
    double maskThreshold = 0.5,
  }) async {
    final stopwatch = Stopwatch()..start();
    await init();
    final letterboxResult = await compute(prepareFrameForInference, rawFrame);
    final rawOutputs = await _onnxService.runInferenceOnTensor(
      letterboxResult,
      useArModel: true,
    );
    final polygons = await compute(
      decodePolygons,
      DecodeInput(
        pred: rawOutputs.pred,
        proto: rawOutputs.proto,
        letterbox: letterboxResult,
        confThreshold: confThreshold,
        iouThreshold: iouThreshold,
        maskThreshold: maskThreshold,
      ),
    );
    final List<NailPoseKeypoints?> matchedPoses = List.filled(
      polygons.length,
      null,
    );
    final combined = _sortByX(polygons, matchedPoses);
    stopwatch.stop();
    return InferenceWorkerResult(
      polygons: combined.polygons,
      poseKeypoints: combined.poses,
      originalWidth: rawFrame.width,
      originalHeight: rawFrame.height,
      inferenceTime: stopwatch.elapsed,
    );
  }

  Future<InferenceWorkerResult> processCameraFrameOnline(
    RawCameraFrame rawFrame, {
    double confThreshold = 0.35,
    double iouThreshold = 0.45,
    double maskThreshold = 0.5,
  }) {
    return processCameraFrame(
      rawFrame,
      confThreshold: confThreshold,
      iouThreshold: iouThreshold,
      maskThreshold: maskThreshold,
    );
  }

  void dispose() {
    _onnxService.dispose();
  }

  // ------------------ Helpers ------------------

  static Offset _centroid(List<Offset> poly) {
    double sumX = 0, sumY = 0;
    for (final pt in poly) {
      sumX += pt.dx;
      sumY += pt.dy;
    }
    return Offset(sumX / poly.length, sumY / poly.length);
  }

  static _SortedPair _sortByX(
    List<List<Offset>> polygons,
    List<NailPoseKeypoints?> poses,
  ) {
    final combined = <Map<String, dynamic>>[];
    for (int i = 0; i < polygons.length; i++) {
      combined.add({
        'poly': polygons[i],
        'pose': poses[i],
        'cx': _centroid(polygons[i]).dx,
      });
    }
    combined.sort((a, b) => (a['cx'] as double).compareTo(b['cx'] as double));
    final sortedPolygons = <List<Offset>>[];
    final sortedPoses = <NailPoseKeypoints?>[];
    for (final item in combined) {
      sortedPolygons.add(item['poly'] as List<Offset>);
      sortedPoses.add(item['pose'] as NailPoseKeypoints?);
    }
    return _SortedPair(sortedPolygons, sortedPoses);
  }

  static List<NailPoseKeypoints?> _matchPosesToPolygons(
    List<List<Offset>> polygons,
    List<NailPoseKeypoints> rawPoses,
  ) {
    final matched = List<NailPoseKeypoints?>.filled(polygons.length, null);
    if (polygons.isEmpty || rawPoses.isEmpty) return matched;

    final pairs = <Map<String, dynamic>>[];
    for (int i = 0; i < polygons.length; i++) {
      final Offset c = _centroid(polygons[i]);
      for (int j = 0; j < rawPoses.length; j++) {
        final pose = rawPoses[j];
        final double poseLen = (pose.tip - pose.base).distance;
        if (poseLen < 2.0) continue;
        final Offset poseMid = Offset(
          (pose.tip.dx + pose.base.dx) / 2,
          (pose.tip.dy + pose.base.dy) / 2,
        );
        final double dist = (c - poseMid).distance;
        if (dist < 120.0) {
          pairs.add({'polyIdx': i, 'poseIdx': j, 'dist': dist});
        }
      }
    }
    pairs.sort((a, b) => (a['dist'] as double).compareTo(b['dist'] as double));
    final usedPolys = <int>{};
    final usedPoses = <int>{};
    for (final pair in pairs) {
      final int polyIdx = pair['polyIdx'];
      final int poseIdx = pair['poseIdx'];
      if (!usedPolys.contains(polyIdx) && !usedPoses.contains(poseIdx)) {
        matched[polyIdx] = rawPoses[poseIdx];
        usedPolys.add(polyIdx);
        usedPoses.add(poseIdx);
      }
    }
    return matched;
  }
}

class _SortedPair {
  final List<List<Offset>> polygons;
  final List<NailPoseKeypoints?> poses;
  _SortedPair(this.polygons, this.poses);
}
