import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'advanced_nail_painter.dart';

/// Custom Painter to visualize AI Detection Output:
/// 1. Nail Polygons (from best.onnx / Segmentation) với viền + fill màu
/// 2. Keypoints & Direction Lines (from thanhdtPose.onnx / Pose)
/// 3. Mũi tên hướng ngón tay ước tính từ PCA polygon (khi không có pose)
class NailDebugPainter extends CustomPainter {
  final List<List<Offset>> polygons;
  final List<String>? labels;
  final List<NailPoseKeypoints?>? poseKeypoints;

  NailDebugPainter({required this.polygons, this.labels, this.poseKeypoints});

  // Màu sắc cho từng ngón tay
  static const List<Color> _fingerColors = [
    Color(0xFF00E5FF), // Cyan   - index
    Color(0xFF69FF47), // Green  - middle
    Color(0xFFFF1744), // Red    - pinky
    Color(0xFFFF9100), // Orange - ring
    Color(0xFFD500F9), // Purple - thumb
  ];

  Color _colorForLabel(String? label, int fallbackIdx) {
    if (label == null) return _fingerColors[fallbackIdx % _fingerColors.length];
    switch (label.toLowerCase()) {
      case 'thumb':  return _fingerColors[4];
      case 'index':  return _fingerColors[0];
      case 'middle': return _fingerColors[1];
      case 'ring':   return _fingerColors[3];
      case 'pinky':  return _fingerColors[2];
      default:       return _fingerColors[fallbackIdx % _fingerColors.length];
    }
  }

  String _fingerNameFromIndex(int fingerIndex) {
    switch (fingerIndex) {
      case 1: return 'Ngón cái';
      case 2: return 'Ngón trỏ';
      case 3: return 'Ngón giữa';
      case 4: return 'Ngón áp út';
      case 5: return 'Ngón út';
      default: return 'Móng $fingerIndex';
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (polygons.isEmpty && (poseKeypoints == null || poseKeypoints!.isEmpty)) {
      return;
    }

    // ── 1. Vẽ viền đa giác móng (Polygons từ best.onnx) ──────────────────────
    final List<int> uniqueIndices =
        AdvancedNailPainter.resolveUniqueFingerIndices(polygons, labels);

    for (int i = 0; i < polygons.length; i++) {
      final poly = polygons[i];
      if (poly.length < 3) continue;

      final int fingerIndex = uniqueIndices[i];
      final Color col = _fingerColors[(fingerIndex - 1).clamp(0, _fingerColors.length - 1)];

      final Paint fillPaint = Paint()
        ..color = col.withValues(alpha: 0.22)
        ..style = PaintingStyle.fill;

      final Paint borderPaint = Paint()
        ..color = col
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0;

      final path = Path();
      path.moveTo(poly.first.dx, poly.first.dy);
      for (int p = 1; p < poly.length; p++) {
        path.lineTo(poly[p].dx, poly[p].dy);
      }
      path.close();

      canvas.drawPath(path, fillPaint);
      canvas.drawPath(path, borderPaint);

      // Chấm ở từng đỉnh polygon để thấy độ chi tiết contour
      final Paint dotPaint = Paint()
        ..color = col
        ..style = PaintingStyle.fill;
      for (final pt in poly) {
        canvas.drawCircle(pt, 2.5, dotPaint);
      }

      // ── Nhãn tên ngón tay ─────────────────────────────────────────────────
      final String viLabel = _fingerNameFromIndex(fingerIndex);
      final Offset centroid = _centroid(poly);
      _drawLabel(canvas, viLabel, centroid - Offset(0, 22), col);

      // ── Mũi tên hướng móng (hướng áp dụng nail thực tế) ───────────────────
      final NailPoseKeypoints? poseKpt = (poseKeypoints != null &&
              i < poseKeypoints!.length)
          ? poseKeypoints![i]
          : null;

      final Offset arrowDir = AdvancedNailPainter.getNailDirection(
        poly: poly,
        allPolygons: polygons,
        fingerIndex: fingerIndex,
        labels: labels,
        poseKeypoint: poseKpt,
      );
      _drawArrow(canvas, centroid, arrowDir, col, length: 42);
    }

    // ── 2. Vẽ Hướng Móng & Keypoints (từ thanhdtPose.onnx) ───────────────────
    if (poseKeypoints != null && poseKeypoints!.isNotEmpty) {
      for (int i = 0; i < poseKeypoints!.length; i++) {
        final kpt = poseKeypoints![i];
        if (kpt == null) continue;

        final String? label = (labels != null && i < labels!.length) ? labels![i] : null;
        final Color col = _colorForLabel(label, i);

        // A. Đường kẻ trục móng nối Gốc -> Đỉnh
        final Paint linePaint = Paint()
          ..color = col
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4.5
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(kpt.base, kpt.tip, linePaint);

        // B. Vẽ mũi tên tại đỉnh
        final Offset dir = kpt.direction;
        _drawArrowHead(canvas, kpt.tip, dir, col, size: 12);

        // C. Chấm Gốc móng (đỏ)
        final Paint basePaint = Paint()..color = Colors.redAccent..style = PaintingStyle.fill;
        final Paint blackBorder = Paint()..color = Colors.black..style = PaintingStyle.stroke..strokeWidth = 2.5;
        canvas.drawCircle(kpt.base, 8.0, basePaint);
        canvas.drawCircle(kpt.base, 9.5, blackBorder);

        // D. Chấm Đỉnh móng (xanh lá)
        final Paint tipPaint = Paint()..color = Colors.greenAccent..style = PaintingStyle.fill;
        canvas.drawCircle(kpt.tip, 8.0, tipPaint);
        canvas.drawCircle(kpt.tip, 9.5, blackBorder);

        _drawSmallLabel(canvas, 'Gốc', kpt.base, Colors.redAccent);
        _drawSmallLabel(canvas, 'Đỉnh', kpt.tip, Colors.greenAccent);
      }
    }
  }

  /// Vẽ mũi tên từ origin theo hướng dir với độ dài length
  void _drawArrow(Canvas canvas, Offset origin, Offset dir, Color color, {double length = 45}) {
    final Paint paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    final Offset tip = origin + Offset(dir.dx * length, dir.dy * length);
    canvas.drawLine(origin, tip, paint);
    _drawArrowHead(canvas, tip, dir, color, size: 10);
  }

  /// Vẽ đầu mũi tên tại điểm tip
  void _drawArrowHead(Canvas canvas, Offset tip, Offset dir, Color color, {double size = 10}) {
    final double angle = math.atan2(dir.dy, dir.dx);
    final Offset left = Offset(
      tip.dx - size * math.cos(angle - 0.45),
      tip.dy - size * math.sin(angle - 0.45),
    );
    final Offset right = Offset(
      tip.dx - size * math.cos(angle + 0.45),
      tip.dy - size * math.sin(angle + 0.45),
    );
    final Path head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(head, Paint()..color = color..style = PaintingStyle.fill);
  }

  void _drawLabel(Canvas canvas, String text, Offset pos, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          backgroundColor: color.withValues(alpha: 0.85),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, pos - Offset(textPainter.width / 2, 0));
  }

  static void _drawSmallLabel(Canvas canvas, String text, Offset pos, Color color) {
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.bold,
          backgroundColor: Colors.black87,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
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
