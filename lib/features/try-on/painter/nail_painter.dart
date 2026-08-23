import 'package:flutter/material.dart';

class NailPainter extends CustomPainter {
  final List<List<Offset>> polygons;
  final Color nailColor;
  final double? imageWidth;
  final double? imageHeight;
  final bool drawBorder;
  final Color borderColor;
  final double borderWidth;
  final bool isFrontCamera;

  NailPainter({
    required this.polygons,
    required this.nailColor,
    this.imageWidth,
    this.imageHeight,
    this.drawBorder = true,
    this.borderColor = const Color(0xFFFFFFFF),
    this.borderWidth = 1.5,
    this.isFrontCamera = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (polygons.isEmpty) return;

    final double imgW = (imageWidth != null && imageWidth! > 0) ? imageWidth! : size.width;
    final double scaleX = (imageWidth != null && imageWidth! > 0)
        ? size.width / imageWidth!
        : 1.0;
    final double scaleY = (imageHeight != null && imageHeight! > 0)
        ? size.height / imageHeight!
        : 1.0;

    for (var polygon in polygons) {
      if (polygon.length < 3) continue;

      final path = Path();
      double firstX = isFrontCamera ? (imgW - polygon.first.dx) : polygon.first.dx;
      final Offset firstScaled = Offset(
        firstX * scaleX,
        polygon.first.dy * scaleY,
      );
      path.moveTo(firstScaled.dx, firstScaled.dy);

      for (int i = 1; i < polygon.length; i++) {
        double px = isFrontCamera ? (imgW - polygon[i].dx) : polygon[i].dx;
        path.lineTo(
          px * scaleX,
          polygon[i].dy * scaleY,
        );
      }
      path.close();

      // 1. Phủ màu móng & Glossy coat trong khuôn móng (tách biệt Da & Móng)
      canvas.save();
      // Cắt khuôn móng tay (Clipping)
      canvas.clipPath(path);

      // Phủ màu móng gel (BlendMode.multiply giúp giữ độ bóng móng gốc)
      final Paint paint = Paint()
        ..color = nailColor.withValues(alpha: 0.85)
        ..blendMode = BlendMode.multiply;
      canvas.drawPath(path, paint);

      // Tạo hiệu ứng bóng móng long lanh (Glossy Top Coat)
      final Paint glossPaint = Paint()
        ..shader = LinearGradient(
          colors: [Colors.white.withValues(alpha: 0.4), Colors.transparent],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(path.getBounds())
        ..blendMode = BlendMode.screen;
      canvas.drawPath(path, glossPaint);

      canvas.restore();

      // 2. Vẽ viền móng (Nail Border / Outline) giúp phân biệt rõ nét ranh giới Da & Móng
      if (drawBorder && borderWidth > 0) {
        final Paint borderPaint = Paint()
          ..color = borderColor.withValues(alpha: 0.8)
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round;
        canvas.drawPath(path, borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant NailPainter oldDelegate) =>
      oldDelegate.polygons != polygons ||
      oldDelegate.nailColor != nailColor ||
      oldDelegate.imageWidth != imageWidth ||
      oldDelegate.imageHeight != imageHeight ||
      oldDelegate.drawBorder != drawBorder ||
      oldDelegate.borderColor != borderColor ||
      oldDelegate.borderWidth != borderWidth ||
      oldDelegate.isFrontCamera != isFrontCamera;
}
