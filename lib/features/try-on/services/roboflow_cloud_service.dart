import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/app_constants.dart';
import '../painter/advanced_nail_painter.dart';

class RoboflowCloudException implements Exception {
  final String message;
  RoboflowCloudException(this.message);
  @override
  String toString() => message;
}

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
  /// Roboflow Segmentation Model (Viền móng) - lấy từ AppConstants
  static String get apiKey => AppConstants.roboflowApiKey;
  static String get segModelId => AppConstants.roboflowSegModelId;
  static int get segVersion => AppConstants.roboflowSegVersion;
  static Duration get requestTimeout => AppConstants.roboflowTimeout;

  /// Safely parses numbers from num or String types
  static double _parseDouble(dynamic val) {
    if (val == null) return 0.0;
    if (val is num) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  /// POST với timeout riêng để tránh treo UI khi mạng chậm
  static Future<http.Response> _postWithTimeout(Uri url, String body) async {
    try {
      return await http
          .post(
            url,
            headers: {"Content-Type": "application/x-www-form-urlencoded"},
            body: body,
          )
          .timeout(requestTimeout);
    } on TimeoutException {
      throw RoboflowCloudException(
        'Roboflow request timeout after ${requestTimeout.inSeconds}s',
      );
    } catch (e) {
      throw RoboflowCloudException('Roboflow network error: $e');
    }
  }

  /// Sends image bytes to Roboflow Cloud Segmentation API.
  /// Lưu ý: Hướng Hybrid hiện không gọi Roboflow Pose ở đây nữa —
  /// pose keypoints sẽ chạy local với thanhdtPose.onnx ở InferenceWorker.
  /// Method vẫn trả về poseKeypoints mặc định = rỗng để giữ tương thích.
  static Future<RoboflowCloudResult> detectNailsOnline(
    Uint8List imageBytes,
  ) async {
    final stopwatch = Stopwatch()..start();
    try {
      if (apiKey.trim().isEmpty) {
        debugPrint("Vui long dien Roboflow API Key trong AppConstants!");
        return RoboflowCloudResult(
          polygons: [],
          labels: [],
          inferenceTime: Duration.zero,
        );
      }

      final String base64Image = base64Encode(imageBytes);

      // Gọi Roboflow Segmentation API (Viền móng)
      final Uri segUrl = Uri.parse(
        "https://detect.roboflow.com/$segModelId/$segVersion?api_key=$apiKey",
      );

      final segResponse = await _postWithTimeout(segUrl, base64Image);

      stopwatch.stop();

      final List<List<Offset>> resultPolygons = [];
      final List<String> resultLabels = [];

      // Parse kết quả Segmentation
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
                polygon.add(
                  Offset(_parseDouble(pt[0]), _parseDouble(pt[1])),
                );
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
          "Loi Roboflow Segmentation API: ${segResponse.statusCode} - ${segResponse.body}",
        );
        throw RoboflowCloudException(
          'Roboflow Segmentation API error ${segResponse.statusCode}',
        );
      }

      debugPrint("==================================================");
      debugPrint("[ROBOFLOW ONLINE API LOG - SEG ONLY]");
      debugPrint(
        "Thoi gian phan hoi API: ${stopwatch.elapsedMilliseconds} ms",
      );
      debugPrint("So luong mong nhan dien (Seg): ${resultPolygons.length}");
      debugPrint("==================================================");

      return RoboflowCloudResult(
        polygons: resultPolygons,
        labels: resultLabels,
        poseKeypoints: const [],
        inferenceTime: stopwatch.elapsed,
      );
    } catch (e, stack) {
      stopwatch.stop();
      debugPrint("Loi ket noi Roboflow Cloud: $e\n$stack");
      if (e is RoboflowCloudException) rethrow;
      return RoboflowCloudResult(
        polygons: [],
        labels: [],
        inferenceTime: stopwatch.elapsed,
      );
    }
  }
}
