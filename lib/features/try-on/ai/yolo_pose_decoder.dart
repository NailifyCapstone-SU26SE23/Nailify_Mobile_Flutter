import 'dart:ui';
import 'package:flutter/foundation.dart';
import '../painter/advanced_nail_painter.dart';
import 'letterbox.dart';

class YoloPoseDecoder {
  /// Decodes local ONNX tensor output from thanhdtPose.onnx into NailPoseKeypoints
  static List<NailPoseKeypoints> decode({
    required dynamic rawPredOutput,
    required LetterboxResult letterbox,
    double confThreshold = 0.45,
    double iouThreshold = 0.45,
  }) {
    if (rawPredOutput == null) return [];

    final List<NailPoseKeypoints> rawPoses = [];

    try {
      // Shape can be [1, 11, 8400] or [1, 8400, 11]
      final List<dynamic> flatList = (rawPredOutput is List)
          ? rawPredOutput.cast<dynamic>()
          : [];

      if (flatList.isEmpty) return [];

      // Determine dimensions: e.g. 1 x 11 x 8400 or 1 x 56 x 8400
      int channels = 11;
      int numAnchors = 8400;

      // Handle 1D flat list flattening
      List<double> values = [];
      if (flatList.first is List) {
        final List<dynamic> batch0 = flatList.first;
        if (batch0.first is List) {
          // [1, C, 8400]
          channels = batch0.length;
          numAnchors = (batch0.first as List).length;
          for (var col in batch0) {
            for (var val in (col as List)) {
              values.add((val as num).toDouble());
            }
          }
        }
      }

      if (values.length < channels * numAnchors) {
        // Fallback for flat Float32List
        if (rawPredOutput is Float32List) {
          values = rawPredOutput.toList();
        }
      }

      if (values.isEmpty) return [];

      final double scale = letterbox.scale;
      final double padX = letterbox.padLeft.toDouble();
      final double padY = letterbox.padTop.toDouble();

      for (int i = 0; i < numAnchors; i++) {
        final double score = values[4 * numAnchors + i];
        if (score < confThreshold) continue;

        // Keypoint 0: Tip
        double k0x = values[5 * numAnchors + i];
        double k0y = values[6 * numAnchors + i];
        double k0conf = values[7 * numAnchors + i];

        // Keypoint 1: Base
        double k1x = values[8 * numAnchors + i];
        double k1y = values[9 * numAnchors + i];
        double k1conf = values[10 * numAnchors + i];

        if (k0conf < 0.50 || k1conf < 0.50) continue;
        if (k0x <= 1.0 || k0y <= 1.0 || k1x <= 1.0 || k1y <= 1.0) continue;

        final double tipX = (k0x - padX) / scale;
        final double tipY = (k0y - padY) / scale;
        final double baseX = (k1x - padX) / scale;
        final double baseY = (k1y - padY) / scale;
        final Offset tip = Offset(tipX, tipY);
        final Offset base = Offset(baseX, baseY);
        if ((tip - base).distance < 2.0) continue;

        rawPoses.add(NailPoseKeypoints(tip: tip, base: base));
      }

      debugPrint('🤖 [LOCAL ONNX POSE DECODER]');
      debugPrint('🎯 Nhận diện thành công ${rawPoses.length} Pose Keypoints từ thanhdtPose.onnx!');
    } catch (e, stack) {
      debugPrint('⚠️ Lỗi decode thanhdtPose.onnx: $e\n$stack');
    }

    return rawPoses;
  }
}
