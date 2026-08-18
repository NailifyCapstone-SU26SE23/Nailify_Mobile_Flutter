import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';
import 'package:image/image.dart' as img;
import '../painter/advanced_nail_painter.dart';
import 'letterbox.dart';
import 'yolo_pose_decoder.dart';

class YoloSegOutputs {
  final dynamic pred; // Output0 [1, 37, 8400] or [1, 8400, 37]
  final dynamic proto; // Output1 [1, 32, 160, 160]
  final LetterboxResult letterbox;

  YoloSegOutputs({
    required this.pred,
    required this.proto,
    required this.letterbox,
  });
}

class OnnxService {
  OrtSession? _segSession;
  OrtSession? _arSession;
  OrtSession? _poseSession;

  Future<void> initModel({bool useArModel = false}) async {
    OrtEnv.instance.init();
    final sessionOptions = OrtSessionOptions();
    sessionOptions.setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableBasic);
    sessionOptions.setIntraOpNumThreads(Platform.numberOfProcessors > 2 ? 2 : Platform.numberOfProcessors);

    // 1. Load Segmentation ONNX Model (best.onnx or ar.onnx)
    if (useArModel) {
      if (_arSession == null) {
        try {
          final rawArBytes = await rootBundle.load('assets/models/ar.onnx');
          final bytesAr = rawArBytes.buffer.asUint8List();
          _arSession = OrtSession.fromBuffer(bytesAr, sessionOptions);
          debugPrint("✅ Đã nạp thành công ar.onnx!");
        } catch (e) {
          debugPrint("⚠️ Lỗi nạp AR ONNX: $e");
        }
      }
    } else {
      if (_segSession == null) {
        try {
          final rawSegBytes = await rootBundle.load('assets/models/best.onnx');
          final bytesSeg = rawSegBytes.buffer.asUint8List();
          _segSession = OrtSession.fromBuffer(bytesSeg, sessionOptions);
          debugPrint("✅ Đã nạp thành công best.onnx!");
        } catch (e) {
          debugPrint("⚠️ Lỗi nạp Segmentation ONNX: $e");
        }
      }
    }

    // 2. Load Pose ONNX Model (thanhdtPose.onnx / thanh.onnx)
    if (_poseSession == null) {
      try {
        ByteData rawPoseBytes;
        try {
          rawPoseBytes = await rootBundle.load('assets/models/thanhdtPose.onnx');
          debugPrint("✅ Đã nạp thành công thanhdtPose.onnx!");
        } catch (_) {
          rawPoseBytes = await rootBundle.load('assets/thanh.onnx');
          debugPrint("✅ Đã nạp thành công thanh.onnx!");
        }
        final bytesPose = rawPoseBytes.buffer.asUint8List();
        _poseSession = OrtSession.fromBuffer(bytesPose, sessionOptions);
      } catch (e) {
        debugPrint("⚠️ Lỗi nạp Pose ONNX: $e");
      }
    }
  }

  Future<YoloSegOutputs> runInference(img.Image rawImage, {bool useArModel = false}) async {
    final letterboxResult = LetterboxProcessor.process(rawImage);
    return runInferenceOnTensor(letterboxResult, useArModel: useArModel);
  }

  /// Runs Segmentation ONNX (best.onnx or ar.onnx)
  Future<YoloSegOutputs> runInferenceOnTensor(LetterboxResult letterboxResult, {bool useArModel = false}) async {
    await initModel(useArModel: useArModel);

    final session = useArModel ? _arSession : _segSession;

    if (session == null) {
      return YoloSegOutputs(pred: null, proto: null, letterbox: letterboxResult);
    }

    final inputOrt = OrtValueTensor.createTensorWithDataList(
      letterboxResult.tensor,
      [1, 3, 640, 640],
    );

    String inputName = 'images';
    if (session!.inputNames.isNotEmpty && !session.inputNames.contains('images')) {
      inputName = session.inputNames.first;
    }

    final runOptions = OrtRunOptions();
    final outputs = await session.runAsync(runOptions, {inputName: inputOrt});
    inputOrt.release();

    dynamic predRaw;
    dynamic protoRaw;

    if (outputs != null && outputs.isNotEmpty) {
      predRaw = outputs[0]?.value;
      if (outputs.length > 1) {
        protoRaw = outputs[1]?.value;
      }
    }

    return YoloSegOutputs(
      pred: predRaw,
      proto: protoRaw,
      letterbox: letterboxResult,
    );
  }

  /// Runs Pose ONNX (thanhdtPose.onnx) directly on device
  Future<List<NailPoseKeypoints>> runPoseInferenceOnTensor(LetterboxResult letterboxResult) async {
    await initModel();

    if (_poseSession == null) return [];

    final inputOrt = OrtValueTensor.createTensorWithDataList(
      letterboxResult.tensor,
      [1, 3, 640, 640],
    );

    String inputName = 'images';
    if (_poseSession!.inputNames.isNotEmpty && !_poseSession!.inputNames.contains('images')) {
      inputName = _poseSession!.inputNames.first;
    }

    final runOptions = OrtRunOptions();
    final outputs = await _poseSession!.runAsync(runOptions, {inputName: inputOrt});
    inputOrt.release();

    dynamic predRaw;
    if (outputs != null && outputs.isNotEmpty) {
      predRaw = outputs[0]?.value;
    }

    return YoloPoseDecoder.decode(
      rawPredOutput: predRaw,
      letterbox: letterboxResult,
    );
  }

  void dispose() {
    _segSession?.release();
    _arSession?.release();
    _poseSession?.release();
  }
}
