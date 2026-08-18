import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import '../ai/onnx_service.dart';
import '../ai/yolo_seg_decoder.dart';
import '../painter/advanced_nail_painter.dart';
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

  Future<InferenceWorkerResult> processFrame(
    img.Image frameImage, {
    double confThreshold = 0.60,
    double iouThreshold = 0.45,
    double maskThreshold = 0.5,
  }) async {
    final stopwatch = Stopwatch()..start();
    await init();

    final rawOutputs = await _onnxService.runInference(frameImage, useArModel: false);
    final polygons = YoloSegDecoder.decode(
      rawOutputs: rawOutputs,
      confThreshold: confThreshold,
      iouThreshold: iouThreshold,
      maskThreshold: maskThreshold,
    );

    final rawPoses = await _onnxService.runPoseInferenceOnTensor(rawOutputs.letterbox);
    final List<NailPoseKeypoints?> matchedPoses = List.filled(polygons.length, null);
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

    final List<Map<String, dynamic>> combined = [];
    for (int i = 0; i < polygons.length; i++) {
      combined.add({'poly': polygons[i], 'pose': matchedPoses[i], 'cx': _centroid(polygons[i]).dx});
    }
    combined.sort((a, b) => (a['cx'] as double).compareTo(b['cx'] as double));
    final List<List<Offset>> sortedPolygons = [];
    final List<NailPoseKeypoints?> sortedPoses = [];
    for (final item in combined) {
      sortedPolygons.add(item['poly'] as List<Offset>);
      sortedPoses.add(item['pose'] as NailPoseKeypoints?);
    }
    stopwatch.stop();

    debugPrint('==================================================');
    debugPrint('🤖 [LOCAL ONNX PIPELINE RESULTS]');
    debugPrint('💅 Móng nhận diện (best.onnx): ${sortedPolygons.length}');
    debugPrint('🎯 Pose nhận diện (thanhdtPose.onnx): ${rawPoses.length}');
    debugPrint('⏱️ Tổng thời gian chạy local: ${stopwatch.elapsedMilliseconds} ms');
    debugPrint('==================================================');
    return InferenceWorkerResult(
      polygons: sortedPolygons,
      poseKeypoints: sortedPoses,
      originalWidth: frameImage.width,
      originalHeight: frameImage.height,
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
    final rawOutputs = await _onnxService.runInferenceOnTensor(letterboxResult, useArModel: true);
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
    final List<NailPoseKeypoints?> matchedPoses = List.filled(polygons.length, null);
    final List<Map<String, dynamic>> combined = [];
    for (int i = 0; i < polygons.length; i++) {
      combined.add({'poly': polygons[i], 'pose': matchedPoses[i], 'cx': _centroid(polygons[i]).dx});
    }
    combined.sort((a, b) => (a['cx'] as double).compareTo(b['cx'] as double));
    final List<List<Offset>> sortedPolygons = [];
    final List<NailPoseKeypoints?> sortedPoses = [];
    for (final item in combined) {
      sortedPolygons.add(item['poly'] as List<Offset>);
      sortedPoses.add(item['pose'] as NailPoseKeypoints?);
    }
    stopwatch.stop();
    return InferenceWorkerResult(
      polygons: sortedPolygons,
      poseKeypoints: sortedPoses,
      originalWidth: rawFrame.width,
      originalHeight: rawFrame.height,
      inferenceTime: stopwatch.elapsed,
    );
  }

  static Offset _centroid(List<Offset> poly) {
    double sumX = 0, sumY = 0;
    for (final pt in poly) { sumX += pt.dx; sumY += pt.dy; }
    return Offset(sumX / poly.length, sumY / poly.length);
  }

  Future<InferenceWorkerResult> processCameraFrameOnline(
    RawCameraFrame rawFrame, {
    double confThreshold = 0.35,
    double iouThreshold = 0.45,
    double maskThreshold = 0.5,
  }) {
    return processCameraFrame(rawFrame,
      confThreshold: confThreshold,
      iouThreshold: iouThreshold,
      maskThreshold: maskThreshold,
    );
  }

  void dispose() {
    _onnxService.dispose();
  }
}
