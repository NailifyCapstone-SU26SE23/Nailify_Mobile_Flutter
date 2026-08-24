import 'package:flutter/material.dart';
import 'advanced_nail_painter.dart';

/// Custom Painter to visualize AI Detection Output:
/// 1. Nail Polygons (from best.onnx / Segmentation)
/// 2. Keypoints & Direction Lines (from thanhdtPose.onnx / Pose)
class NailDebugPainter extends CustomPainter {
  final List<List<Offset>> polygons;
  final List<String>? labels;
  final List<NailPoseKeypoints?>? poseKeypoints;

  NailDebugPainter({required this.polygons, this.labels, this.poseKeypoints});

  @override
  void paint(Canvas canvas, Size size) {
    if (polygons.isEmpty && (poseKeypoints == null || poseKeypoints!.isEmpty)) {
      return;
    }

    // 1. Vẽ viền đa giác móng (Polygons từ best.onnx)
    final Paint polyFillPaint = Paint()
      ..color =
          const Color(0x4000E5FF) // Màu xanh cyan trong suốt
      ..style = PaintingStyle.fill;

    final Paint polyBorderPaint = Paint()
      ..color =
          const Color(0xFF00E5FF) // Viền xanh cyan rực rỡ
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0;

    for (int i = 0; i < polygons.length; i++) {
      final poly = polygons[i];
      if (poly.length < 3) continue;

      final path = Path();
      path.moveTo(poly.first.dx, poly.first.dy);
      for (int p = 1; p < poly.length; p++) {
        path.lineTo(poly[p].dx, poly[p].dy);
      }
      path.close();

      canvas.drawPath(path, polyFillPaint);
      canvas.drawPath(path, polyBorderPaint);

      // Nhãn tên ngón tay
      final String label = (labels != null && i < labels!.length)
          ? labels![i]
          : "nail #${i + 1}";
      final textSpan = TextSpan(
        text: label,
        style: const TextStyle(
          color: Colors.yellowAccent,
          fontSize: 14,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black87,
        ),
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      );
      textPainter.layout();
      final Offset centroid = _centroid(poly);
      textPainter.paint(canvas, centroid - Offset(textPainter.width / 2, 24));
    }

    // 2. Vẽ Hướng Móng & Keypoints (từ thanhdtPose.onnx / erikdev/2)
    if (poseKeypoints != null && poseKeypoints!.isNotEmpty) {
      final Paint linePaint = Paint()
        ..color =
            const Color(0xFFFFEA00) // Đường màu vàng nối gốc -> đỉnh
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4.5;

      final Paint tipPaint = Paint()
        ..color =
            const Color(0xFF00FF00) // Chấm xanh lá rực rỡ tại Đỉnh móng (Tip)
        ..style = PaintingStyle.fill;

      final Paint basePaint = Paint()
        ..color =
            const Color(0xFFFF1744) // Chấm đỏ tươi tại Gốc móng (Base)
        ..style = PaintingStyle.fill;

      final Paint blackBorderPaint = Paint()
        ..color = Colors.black
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5;

      for (int i = 0; i < poseKeypoints!.length; i++) {
        final kpt = poseKeypoints![i];
        if (kpt == null) continue;

        // A. Đường kẻ trục móng nối Gốc (Red) -> Đỉnh (Green)
        canvas.drawLine(kpt.base, kpt.tip, linePaint);

        // B. Chấm Gốc móng (🔴 Đỏ)
        canvas.drawCircle(kpt.base, 9.0, basePaint);
        canvas.drawCircle(kpt.base, 10.5, blackBorderPaint);

        // C. Chấm Đỉnh móng (🟢 Xanh lá)
        canvas.drawCircle(kpt.tip, 9.0, tipPaint);
        canvas.drawCircle(kpt.tip, 10.5, blackBorderPaint);

        // D. Nhãn chú thích Gốc & Đỉnh
        _drawSmallLabel(canvas, "Gốc", kpt.base, Colors.redAccent);
        _drawSmallLabel(canvas, "Đỉnh", kpt.tip, Colors.greenAccent);
      }
    }
  }

  static void _drawSmallLabel(
    Canvas canvas,
    String text,
    Offset pos,
    Color color,
  ) {
    final textSpan = TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: 11,
        fontWeight: FontWeight.bold,
        backgroundColor: Colors.black87,
      ),
    );
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, pos + const Offset(12, -8));
  }

  static Offset _centroid(List<Offset> poly) {
    double sumX = 0, sumY = 0;
    for (final pt in poly) {
      sumX += pt.dx;
      sumY += pt.dy;
    }
    return Offset(sumX / poly.length, sumY / poly.length);
  }

  @override
  bool shouldRepaint(covariant NailDebugPainter oldDelegate) =>
      oldDelegate.polygons != polygons ||
      oldDelegate.labels != labels ||
      oldDelegate.poseKeypoints != poseKeypoints;
}
