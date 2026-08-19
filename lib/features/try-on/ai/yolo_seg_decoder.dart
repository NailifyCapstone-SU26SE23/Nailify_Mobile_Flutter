import 'dart:math';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'mask_reconstruct.dart';
import 'marching_squares.dart';
import 'nms.dart';
import 'onnx_service.dart';
import 'polygon_resampler.dart';

class YoloSegDecoder {
  static double _sigmoid(double x) => 1.0 / (1.0 + exp(-x));

  static String getClassName(int classId) {
    const Map<int, String> names = {
      0: 'index',
      1: 'middle',
      2: 'pinky',
      3: 'ring',
      4: 'thumb',
    };
    return names[classId] ?? 'nail';
  }

  /// Master Ultralytics Decoder: Anchor Parsing -> NMS -> ROI Reconstruct -> Contour -> Undo Letterbox
  static List<List<Offset>> decode({
    required YoloSegOutputs rawOutputs,
    double confThreshold = 0.60,
    double iouThreshold = 0.45,
    double maskThreshold = 0.5,
  }) {
    if (rawOutputs.pred == null) return [];

    final List<List<Offset>> resultPolygons = [];

    // Step 1: Parse prediction anchors
    final candidates = _parseOutput0(rawOutputs.pred, confThreshold);
    if (candidates.isEmpty) {
      debugPrint(
        "🔍 [YOLO AI] Không có anchor nào đạt confThreshold (>= $confThreshold)",
      );
      return [];
    }

    // Step 2: NMS Filtering (Cap at 5 fingernails max per hand)
    final nmsDetections = NmsProcessor.filter(
      candidates: candidates,
      iouThreshold: 0.35,
      maxKeep: 5,
    );

    if (nmsDetections.isEmpty) return [];

    debugPrint("--------------------------------------------------");
    debugPrint("🤖 [YOLO SEG DECODER RESULTS]");
    debugPrint(
      "🔍 Anchors ứng viên: ${candidates.length} -> NMS giữ lại: ${nmsDetections.length} móng",
    );
    for (int i = 0; i < nmsDetections.length; i++) {
      final det = nmsDetections[i];
      final label = getClassName(det.classId);
      debugPrint(
        "   📌 Móng #${i + 1}: ClassID = ${det.classId} ($label) | Score = ${(det.score * 100).toStringAsFixed(1)}% | Box = (cx: ${det.cx.toStringAsFixed(1)}, cy: ${det.cy.toStringAsFixed(1)}, w: ${det.w.toStringAsFixed(1)}, h: ${det.h.toStringAsFixed(1)})",
      );
    }
    debugPrint("--------------------------------------------------");

    final double imgW = rawOutputs.letterbox.originalWidth.toDouble();
    final double imgH = rawOutputs.letterbox.originalHeight.toDouble();

    // Step 3 & 4: Mask ROI Reconstruction & Marching Squares Contour Extraction
    for (var det in nmsDetections) {
      LocalizedMaskRoi? maskRoi;
      if (rawOutputs.proto != null) {
        maskRoi = MaskReconstructionProcessor.reconstructRoiMask(
          det: det,
          rawProto: rawOutputs.proto,
          maskThreshold: maskThreshold,
        );
      }

      List<Offset> polygon640 = [];
      if (maskRoi != null) {
        polygon640 = MarchingSquaresProcessor.extractContour(maskRoi);
      }

      // Ellipse fallback if contour extraction returns empty
      if (polygon640.isEmpty) {
        polygon640 = _generateBoxEllipsePoints(det);
      }

      // Step 4b: Resample to a fixed-length, angle-canonical polygon. This
      // smooths the pixel-stairstepped raw contour, which matters most for
      // Snapshot Try-On (a single still shape with nothing to hide behind).
      polygon640 = PolygonResampler.resample(polygon640);

      // Step 5: Undo Letterbox to Original Image Coordinates
      final List<Offset> origPolygon = [];
      for (var pt in polygon640) {
        double origX =
            (pt.dx - rawOutputs.letterbox.padLeft) / rawOutputs.letterbox.scale;
        double origY =
            (pt.dy - rawOutputs.letterbox.padTop) / rawOutputs.letterbox.scale;

        origX = origX.clamp(0.0, imgW);
        origY = origY.clamp(0.0, imgH);

        origPolygon.add(Offset(origX, origY));
      }

      if (origPolygon.length >= 3) {
        resultPolygons.add(origPolygon);
      }
    }

    return resultPolygons;
  }

  static List<YoloDetection> _parseOutput0(
    dynamic rawOut0,
    double confThreshold,
  ) {
    final List<YoloDetection> candidates = [];

    dynamic matrix = rawOut0;
    if (matrix is List && matrix.length == 1 && matrix[0] is List) {
      matrix = matrix[0];
    }

    if (matrix is! List || matrix.isEmpty) return candidates;

    int dimA = matrix.length;
    int dimB = (matrix[0] is List) ? (matrix[0] as List).length : 0;

    const int numMaskCoeffs = 32;

    // Case 1: [Channels][Anchors] e.g. [37][8400] for 1 class or [41][8400] for 5 classes
    if (dimA < dimB) {
      final int numChannels = dimA;
      final int numAnchors = dimB;
      final int numClasses = max(1, numChannels - 4 - numMaskCoeffs);

      final List rowCX = matrix[0] as List;
      final List rowCY = matrix[1] as List;
      final List rowW = matrix[2] as List;
      final List rowH = matrix[3] as List;

      for (int i = 0; i < numAnchors; i++) {
        double maxScore = -1.0;
        int maxClassId = 0;

        for (int c = 0; c < numClasses; c++) {
          double rawScore = ((matrix[4 + c] as List)[i] as num).toDouble();
          double score = (rawScore > 1.0 || rawScore < 0.0)
              ? _sigmoid(rawScore)
              : rawScore;
          if (score > maxScore) {
            maxScore = score;
            maxClassId = c;
          }
        }

        if (maxScore >= confThreshold) {
          double cx = (rowCX[i] as num).toDouble();
          double cy = (rowCY[i] as num).toDouble();
          double w = (rowW[i] as num).toDouble();
          double h = (rowH[i] as num).toDouble();

          // Filter out false positive padding artifacts along letterbox borders
          if (cy < 40.0 || cy > 600.0 || cx < 40.0 || cx > 600.0) continue;

          int maskStartChannel = 4 + numClasses;
          List<double> coeffs = [];
          for (
            int c = 0;
            c < numMaskCoeffs && (maskStartChannel + c) < numChannels;
            c++
          ) {
            coeffs.add(
              ((matrix[maskStartChannel + c] as List)[i] as num).toDouble(),
            );
          }

          candidates.add(
            YoloDetection(
              cx: cx,
              cy: cy,
              w: w,
              h: h,
              score: maxScore,
              classId: maxClassId,
              maskCoeffs: coeffs,
            ),
          );
        }
      }
    }
    // Case 2: [Anchors][Channels] e.g. [8400][37] or [8400][41]
    else if (dimA >= dimB && dimB > 0) {
      final int numAnchors = dimA;
      final int numChannels = dimB;
      final int numClasses = max(1, numChannels - 4 - numMaskCoeffs);

      for (int i = 0; i < numAnchors; i++) {
        final List anchorData = matrix[i] as List;

        double maxScore = -1.0;
        int maxClassId = 0;

        for (int c = 0; c < numClasses; c++) {
          double rawScore = (anchorData[4 + c] as num).toDouble();
          double score = (rawScore > 1.0 || rawScore < 0.0)
              ? _sigmoid(rawScore)
              : rawScore;
          if (score > maxScore) {
            maxScore = score;
            maxClassId = c;
          }
        }

        if (maxScore >= confThreshold) {
          double cx = (anchorData[0] as num).toDouble();
          double cy = (anchorData[1] as num).toDouble();
          double w = (anchorData[2] as num).toDouble();
          double h = (anchorData[3] as num).toDouble();

          // Filter out false positive padding artifacts along letterbox borders
          if (cy < 40.0 || cy > 600.0 || cx < 40.0 || cx > 600.0) continue;

          int maskStartChannel = 4 + numClasses;
          List<double> coeffs = [];
          for (
            int c = 0;
            c < numMaskCoeffs && (maskStartChannel + c) < numChannels;
            c++
          ) {
            coeffs.add((anchorData[maskStartChannel + c] as num).toDouble());
          }

          candidates.add(
            YoloDetection(
              cx: cx,
              cy: cy,
              w: w,
              h: h,
              score: maxScore,
              classId: maxClassId,
              maskCoeffs: coeffs,
            ),
          );
        }
      }
    }

    return candidates;
  }

  static List<Offset> _generateBoxEllipsePoints(YoloDetection det) {
    final List<Offset> points = [];
    const int steps = 16;
    for (int i = 0; i < steps; i++) {
      double angle = (2 * pi * i) / steps;
      double px = det.cx + (det.w / 2.0) * cos(angle);
      double py = det.cy + (det.h / 2.0) * sin(angle);
      points.add(Offset(px, py));
    }
    return points;
  }
}
