import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../painter/advanced_nail_painter.dart';

class RoboflowCloudResult {
  final List<List<Offset>> polygons;
  final List<String> labels;
  final List<NailPoseKeypoints?> poseKeypoints;
  final Duration inferenceTime;

  RoboflowCloudResult({
    required this.polygons,
    required this.labels,
    this.poseKeypoints = const [],
    required this.inferenceTime,
  });
}

class RoboflowCloudService {
  /// Roboflow Segmentation Model (Viền móng)
  static String apiKey = "fcHtZkPLLJYAa2BZnDxk";
  static String segModelId = "nail-segmentation-vic7o-jnf4k";
  static int segVersion = 3;

  /// Roboflow Pose Keypoint Model (Hướng móng: Đỉnh & Gốc - Model YOLOv11 Pose mới train)
  static String poseApiKey = "fcHtZkPLLJYAa2BZnDxk";
  static String poseModelId = "erikdev";
  static int poseVersion = 3;

  /// Safely parses numbers from num or String types
  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  /// Sends image bytes to Roboflow Cloud APIs (Segmentation + Pose) and matches keypoint directions with polygons
  static Future<RoboflowCloudResult> detectNailsOnline(
    Uint8List imageBytes,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      if (apiKey.trim().isEmpty) {
        debugPrint("⚠️ Vui lòng điền Roboflow API Key!");
        return RoboflowCloudResult(
          polygons: [],
          labels: [],
          inferenceTime: Duration.zero,
        );
      }

      final String base64Image = base64Encode(imageBytes);

      // 1. Gọi Roboflow Segmentation API (Viền móng)
      final Uri segUrl = Uri.parse(
        "https://detect.roboflow.com/$segModelId/$segVersion?api_key=$apiKey",
      );

      final segFuture = http.post(
        segUrl,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: base64Image,
      );

      // 2. Gọi Roboflow Pose Keypoint API (Model erikdev version 3)
      final Uri poseUrl = Uri.parse(
        "https://detect.roboflow.com/$poseModelId/$poseVersion?api_key=$poseApiKey",
      );

      final poseFuture = http.post(
        poseUrl,
        headers: {"Content-Type": "application/x-www-form-urlencoded"},
        body: base64Image,
      );

      // Chạy song song 2 API
      final results = await Future.wait([segFuture, poseFuture]);
      final segResponse = results[0];
      final poseResponse = results[1];

      stopwatch.stop();

      final List<List<Offset>> resultPolygons = [];
      final List<String> resultLabels = [];
      final List<NailPoseKeypoints> rawPoseList = [];

      // A. Parse kết quả Segmentation
      if (segResponse.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(segResponse.body);
        final predictions =
            data["predictions"] ?? data["boxes"] as List<dynamic>? ?? [];

        for (final pred in predictions) {
          final points = pred["points"] as List<dynamic>?;
          final String label = (pred["label"] ?? pred["class"] ?? "")
              .toString();

          if (points != null && points.isNotEmpty) {
            final List<Offset> polygon = [];
            for (final pt in points) {
              if (pt is List && pt.length >= 2) {
                polygon.add(Offset(_parseDouble(pt[0]), _parseDouble(pt[1])));
              } else if (pt is Map) {
                polygon.add(
                  Offset(_parseDouble(pt["x"]), _parseDouble(pt["y"])),
                );
              }
            }
            if (polygon.isNotEmpty) {
              resultPolygons.add(polygon);
              resultLabels.add(label);
            }
          }
        }
      } else {
        debugPrint(
          "⚠️ Lỗi Roboflow Segmentation API: ${segResponse.statusCode} - ${segResponse.body}",
        );
      }

      // B. Parse kết quả Pose Keypoints linh hoạt
      if (poseResponse.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(poseResponse.body);
        final predictions =
            data["predictions"] ?? data["boxes"] as List<dynamic>? ?? [];

        for (final pred in predictions) {
          final keypoints = pred["keypoints"] as List<dynamic>?;
          if (keypoints != null && keypoints.isNotEmpty) {
            Offset? kpt0; // Tip (Đỉnh)
            Offset? kpt1; // Base (Gốc)

            for (int idx = 0; idx < keypoints.length; idx++) {
              final kpt = keypoints[idx];
              if (kpt is Map) {
                final int kId = (kpt["id"] is num)
                    ? (kpt["id"] as num).toInt()
                    : (int.tryParse(kpt["id"].toString()) ?? idx);
                final double kx = _parseDouble(kpt["x"]);
                final double ky = _parseDouble(kpt["y"]);

                if (kId == 0) {
                  kpt0 = Offset(kx, ky);
                } else if (kId == 1) {
                  kpt1 = Offset(kx, ky);
                }
              } else if (kpt is List && kpt.length >= 2) {
                final double kx = _parseDouble(kpt[0]);
                final double ky = _parseDouble(kpt[1]);
                if (idx == 0) kpt0 = Offset(kx, ky);
                if (idx == 1) kpt1 = Offset(kx, ky);
              }
            }

            if (kpt0 != null && kpt1 != null) {
              rawPoseList.add(NailPoseKeypoints(tip: kpt0, base: kpt1));
            }
          }
        }
      } else {
        debugPrint(
          "⚠️ Lỗi Roboflow Pose API: ${poseResponse.statusCode} - ${poseResponse.body}",
        );
      }

      // C. Ghép cặp Polygons với Pose Keypoint gần nhất
      final List<NailPoseKeypoints?> matchedPoseKeypoints = [];
      for (final poly in resultPolygons) {
        final Offset c = _centroid(poly);
        NailPoseKeypoints? bestMatch;
        double minDistance = double.infinity;

        for (final pose in rawPoseList) {
          final double poseLen = (pose.tip - pose.base).distance;
          if (poseLen < 2.0) continue;

          final Offset poseMid = Offset(
            (pose.tip.dx + pose.base.dx) / 2,
            (pose.tip.dy + pose.base.dy) / 2,
          );
          final double dist = (c - poseMid).distance;
          if (dist < minDistance) {
            minDistance = dist;
            bestMatch = pose;
          }
        }

        // Gán Pose keypoint tương ứng nếu khoảng cách hợp lý
        if (bestMatch != null && minDistance < 120.0) {
          matchedPoseKeypoints.add(bestMatch);
        } else {
          matchedPoseKeypoints.add(null);
        }
      }

      debugPrint("==================================================");
      debugPrint("☁️ [ROBOFLOW ONLINE API LOG]");
      debugPrint(
        "⏱️ Thời gian phản hồi API: ${stopwatch.elapsedMilliseconds} ms",
      );
      debugPrint("💅 Số lượng móng nhận diện (Seg): ${resultPolygons.length}");
      debugPrint("🎯 Số lượng Pose Keypoint nhận diện: ${rawPoseList.length}");
      for (int i = 0; i < resultPolygons.length; i++) {
        final label = resultLabels[i];
        final kpt = matchedPoseKeypoints[i];
        final kptMatched = kpt != null
            ? "✅ Gốc(${kpt.base.dx.toStringAsFixed(0)}, ${kpt.base.dy.toStringAsFixed(0)}) -> Đỉnh(${kpt.tip.dx.toStringAsFixed(0)}, ${kpt.tip.dy.toStringAsFixed(0)})"
            : "❌ Không ghép được Pose";
        debugPrint("   📍 Viền móng #${i + 1} ($label) -> $kptMatched");
      }
      debugPrint("==================================================");

      return RoboflowCloudResult(
        polygons: resultPolygons,
        labels: resultLabels,
        poseKeypoints: matchedPoseKeypoints,
        inferenceTime: stopwatch.elapsed,
      );
    } catch (e, stack) {
      stopwatch.stop();
      debugPrint("⚠️ Lỗi kết nối Roboflow Cloud: $e\n$stack");
      return RoboflowCloudResult(
        polygons: [],
        labels: [],
        inferenceTime: stopwatch.elapsed,
      );
    }
  }

  static Offset _centroid(List<Offset> poly) {
    double sumX = 0, sumY = 0;
    for (final pt in poly) {
      sumX += pt.dx;
      sumY += pt.dy;
    }
    return Offset(sumX / poly.length, sumY / poly.length);
  }
}
