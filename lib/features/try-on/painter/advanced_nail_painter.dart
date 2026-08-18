import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/nail_variant_model.dart';

/// Represents keypoint coordinates for nail orientation (Tip: Keypoint 0, Base: Keypoint 1).
class NailPoseKeypoints {
  final Offset tip;  // Keypoint 0 (Đỉnh móng)
  final Offset base; // Keypoint 1 (Gốc móng)

  NailPoseKeypoints({required this.tip, required this.base});

  /// Vector pointing from Cuticle Base toward Fingertip
  Offset get direction {
    final double dx = tip.dx - base.dx;
    final double dy = tip.dy - base.dy;
    final double len = math.sqrt(dx * dx + dy * dy);
    if (len < 1e-4) return const Offset(0, -1);
    return Offset(dx / len, dy / len);
  }
}

/// Advanced Canvas Painter to render Backend API Nail Variants onto detected Nail Polygons.
///
/// Roboflow Polygon Direction Engine v2:
/// Uses Hand-Geometry Layout, Perpendicular Vector Cross Product, and Extremity Tapering.
/// Guarantees 3D Fake Nail Tips (Almond / Coffin / Stiletto) point 100% along
/// the finger axis across all poses (horizontal, vertical, diagonal, single-finger).
class AdvancedNailPainter extends CustomPainter {
  final List<List<Offset>> polygons;
  final List<String>? labels;
  final List<NailPoseKeypoints?>? poseKeypoints;
  final NailVariantModel variant;
  final ui.Image? nailShapeImage;
  final Map<int, ui.Image> componentImages; // componentId -> ui.Image
  final int? selectedFingerIndex;
  final int? selectedComponentId;

  /// Fake nail stays 100% inside the detected fingernail polygon to prevent skin overflow.
  static const double _widthCover = 0.98;

  /// Along the finger axis the shape extends naturally past the fingertip.
  static const double _minHeightCover = 1.20;

  /// Anchor overlap past the cuticle so no skin gap shows at the nail base.
  static const double _cuticleOverlap = 0.02;

  AdvancedNailPainter({
    required this.polygons,
    this.labels,
    this.poseKeypoints,
    required this.variant,
    this.nailShapeImage,
    this.componentImages = const {},
    this.selectedFingerIndex,
    this.selectedComponentId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (polygons.isEmpty) return;

    // 1. Compute layout vector across fingernails (Pinky -> Index)
    final Offset? across = _acrossHandAxis(polygons);

    // 2. Estimate palm origin & thumb reference centroid
    final palmInfo = _estimatePalmCenter(polygons, across);

    for (int i = 0; i < polygons.length; i++) {
      final poly = polygons[i];
      if (poly.length < 3) continue;

      int fingerIndex = i + 1; // Default 1: Thumb ... 5: Pinky
      if (labels != null && i < labels!.length) {
        fingerIndex = _labelToFingerIndex(labels![i], defaultIdx: fingerIndex);
      }

      NailPoseKeypoints? poseKpt;
      if (poseKeypoints != null && i < poseKeypoints!.length) {
        poseKpt = poseKeypoints![i];
      }

      _paintSingleNail(
        canvas,
        poly,
        fingerIndex,
        across,
        palmInfo.center,
        palmInfo.reliable,
        palmInfo.indexCentroid,
        poseKeypoint: poseKpt,
      );
    }
  }

  int _labelToFingerIndex(String label, {required int defaultIdx}) {
    final l = label.toLowerCase();
    if (l.contains('thumb')) return 1;
    if (l.contains('index')) return 2;
    if (l.contains('middle')) return 3;
    if (l.contains('ring')) return 4;
    if (l.contains('pinky')) return 5;
    return defaultIdx;
  }

  /// PCA of a single nail polygon: unit major/minor axes, elongation ratio & eigenvalues.
  ({Offset major, Offset minor, double elongation, double lMajor}) _nailPca(
    List<Offset> poly,
    Offset c,
  ) {
    final int n = poly.length;
    double covXX = 0, covXY = 0, covYY = 0;
    for (final pt in poly) {
      final double dx = pt.dx - c.dx;
      final double dy = pt.dy - c.dy;
      covXX += dx * dx;
      covXY += dx * dy;
      covYY += dy * dy;
    }
    covXX /= n;
    covXY /= n;
    covYY /= n;

    final double theta = 0.5 * math.atan2(2 * covXY, covXX - covYY);
    final Offset major = Offset(math.cos(theta), math.sin(theta));
    final Offset minor = Offset(-major.dy, major.dx);

    final double tr = covXX + covYY;
    final double disc = math.sqrt(math.max(
        0.0, (covXX - covYY) * (covXX - covYY) / 4 + covXY * covXY));
    final double lMajor = tr / 2 + disc;
    final double lMinor = tr / 2 - disc;
    final double elong = lMinor > 1e-6 ? lMajor / lMinor : double.infinity;
    return (major: major, minor: minor, elongation: elong, lMajor: lMajor);
  }

  /// Global "across the hand" axis from nail centroids layout (Pinky -> Index).
  Offset? _acrossHandAxis(List<List<Offset>> polys) {
    final List<Offset> cs = [];
    for (final poly in polys) {
      if (poly.length >= 3) cs.add(_centroid(poly));
    }
    if (cs.length < 3) return null;

    double mx = 0, my = 0;
    for (final c in cs) {
      mx += c.dx;
      my += c.dy;
    }
    mx /= cs.length;
    my /= cs.length;

    double covXX = 0, covXY = 0, covYY = 0;
    for (final c in cs) {
      final double dx = c.dx - mx;
      final double dy = c.dy - my;
      covXX += dx * dx;
      covXY += dx * dy;
      covYY += dy * dy;
    }
    covXX /= cs.length;
    covXY /= cs.length;
    covYY /= cs.length;

    final double tr = covXX + covYY;
    final double disc = math.sqrt(math.max(
        0.0, (covXX - covYY) * (covXX - covYY) / 4 + covXY * covXY));
    final double lMajor = tr / 2 + disc;
    final double lMinor = tr / 2 - disc;
    if (lMajor < 1e-6) return null;
    if ((1 - lMinor / lMajor) < 0.35) return null;

    final double theta = 0.5 * math.atan2(2 * covXY, covXX - covYY);
    return Offset(math.cos(theta), math.sin(theta));
  }

  /// Selects major or minor PCA axis based on alignment with hand orientation.
  ({Offset dir, double conf}) _fingerAxis(
    List<Offset> poly,
    Offset c,
    Offset? across, {
    int fingerIndex = 0,
  }) {
    final pca = _nailPca(poly, c);
    // For thumb (fingerIndex == 1), always use pca.major because thumb spreads out
    if (fingerIndex == 1 || across == null) {
      final double conf =
          pca.elongation.isFinite ? (1 - 1 / pca.elongation).clamp(0.0, 1.0) : 1.0;
      return (dir: pca.major, conf: conf);
    }
    final Offset perpA = Offset(-across.dy, across.dx);
    final double alignMajor =
        (pca.major.dx * perpA.dx + pca.major.dy * perpA.dy).abs();
    final double alignMinor =
        (pca.minor.dx * perpA.dx + pca.minor.dy * perpA.dy).abs();
    return alignMajor >= alignMinor
        ? (dir: pca.major, conf: alignMajor)
        : (dir: pca.minor, conf: alignMinor);
  }

  /// Estimates palm center & retrieves index finger centroid for thumb reference.
  ({Offset center, bool reliable, Offset? indexCentroid}) _estimatePalmCenter(
    List<List<Offset>> polys,
    Offset? across,
  ) {
    double a11 = 0, a12 = 0, a22 = 0, b1 = 0, b2 = 0;
    double sumCos2 = 0, sumSin2 = 0, wSum = 0;
    int used = 0;
    double meanX = 0, meanY = 0;
    int count = 0;
    Offset? idxCentroid;

    for (int i = 0; i < polys.length; i++) {
      final poly = polys[i];
      if (poly.length < 3) continue;
      final Offset c = _centroid(poly);
      meanX += c.dx;
      meanY += c.dy;
      count++;

      int fingerIdx = i + 1;
      if (labels != null && i < labels!.length) {
        fingerIdx = _labelToFingerIndex(labels![i], defaultIdx: fingerIdx);
      }

      if (fingerIdx == 2) {
        idxCentroid = c;
      }

      final fa = _fingerAxis(poly, c, across, fingerIndex: fingerIdx);
      final double w = fa.conf;
      if (w < 0.35) continue;
      final double dx = fa.dir.dx, dy = fa.dir.dy;

      final double m11 = w * (1 - dx * dx);
      final double m12 = w * (-dx * dy);
      final double m22 = w * (1 - dy * dy);
      a11 += m11;
      a12 += m12;
      a22 += m22;
      b1 += m11 * c.dx + m12 * c.dy;
      b2 += m12 * c.dx + m22 * c.dy;

      final double theta = math.atan2(dy, dx);
      sumCos2 += w * math.cos(2 * theta);
      sumSin2 += w * math.sin(2 * theta);
      wSum += w;
      used++;
    }

    final Offset meanCentroid =
        count > 0 ? Offset(meanX / count, meanY / count) : Offset.zero;

    if (used < 2 || wSum < 1e-6) {
      return (center: meanCentroid, reliable: false, indexCentroid: idxCentroid);
    }

    final double r = math.sqrt(sumCos2 * sumCos2 + sumSin2 * sumSin2) / wSum;
    final double det = a11 * a22 - a12 * a12;
    if (r > 0.97 || det.abs() < 1e-6) {
      return (center: meanCentroid, reliable: false, indexCentroid: idxCentroid);
    }

    final double px = (a22 * b1 - a12 * b2) / det;
    final double py = (a11 * b2 - a12 * b1) / det;
    return (center: Offset(px, py), reliable: true, indexCentroid: idxCentroid);
  }

  void _paintSingleNail(
    Canvas canvas,
    List<Offset> poly,
    int fingerIndex,
    Offset? across,
    Offset palmCenter,
    bool palmReliable,
    Offset? indexCentroid, {
    NailPoseKeypoints? poseKeypoint,
  }) {
    final Offset center = _centroid(poly);

    final bool isPoseValid = (poseKeypoint != null) &&
        (poseKeypoint.tip - poseKeypoint.base).distance >= 2.0 &&
        poseKeypoint.tip.dx > 5 && poseKeypoint.tip.dy > 5 &&
        poseKeypoint.base.dx > 5 && poseKeypoint.base.dy > 5;

    // 1. Calculate unit vector pointing from cuticle toward fingertip
    final Offset tipDir = isPoseValid
        ? poseKeypoint.direction
        : _tipDirection(
            poly,
            center,
            across,
            palmCenter,
            palmReliable,
            fingerIndex,
            indexCentroid,
          );

    // Canvas rotation mapping local -Y (up) onto fingertip direction
    final double angle = math.atan2(tipDir.dx, -tipDir.dy);

    // 2. Measure local oriented bounding box in finger frame
    final List<Offset> localPts = [
      for (final pt in poly) _rotate(pt - center, -angle),
    ];
    double minX = double.infinity, minY = double.infinity;
    double maxX = -double.infinity, maxY = -double.infinity;
    for (final lp in localPts) {
      if (lp.dx < minX) minX = lp.dx;
      if (lp.dy < minY) minY = lp.dy;
      if (lp.dx > maxX) maxX = lp.dx;
      if (lp.dy > maxY) maxY = lp.dy;
    }
    final Rect localBounds = Rect.fromLTRB(minX, minY, maxX, maxY);
    if (localBounds.width < 2 || localBounds.height < 2) return;

    // 3. Base gel color + HSL offsets from API
    final Color nailColor =
        _applySurfaceHsl(_getFingerColor(fingerIndex), variant.nailSurface);

    final double? poseLength = isPoseValid
        ? (poseKeypoint.tip - poseKeypoint.base).distance
        : null;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);

    if (nailShapeImage != null) {
      _paintShapeNail(canvas, localBounds, nailColor, fingerIndex, poseLength: poseLength);
    } else {
      _paintNaturalNail(canvas, localPts, localBounds, nailColor, fingerIndex);
    }

    if (selectedFingerIndex != null && (selectedFingerIndex == fingerIndex || selectedFingerIndex == -1)) {
      _drawFingerHighlight(canvas, localBounds);
    }

    _renderComponentBoundingBoxOverlay(canvas, localBounds, fingerIndex, poseLength: poseLength);

    canvas.restore();
  }

  /// 💅 FAKE NAIL TIP EXTENSION MODE (Almond / Coffin / Stiletto shape PNG).
  /// Anchored at cuticle and extends past fingertip along the finger direction vector.
  void _paintShapeNail(
    Canvas canvas,
    Rect nb,
    Color color,
    int fingerIndex, {
    double? poseLength,
  }) {
    final ui.Image shape = nailShapeImage!;
    final Rect src =
        Rect.fromLTWH(0, 0, shape.width.toDouble(), shape.height.toDouble());

    final double effectiveHeight = (poseLength != null && poseLength > 0)
        ? math.max(nb.height, poseLength)
        : nb.height;

    // Fit width snugly to cyan polygon width + 15% margin to cover natural nail
    final double fitWidth = nb.width * _widthCover;
    final double aspect = src.height / src.width;
    final double fitHeight =
        math.max(fitWidth * aspect, effectiveHeight * _minHeightCover);

    // Anchored at cuticle (bottom of local box, +Y) extending toward tip (-Y)
    final double bottom = nb.bottom + effectiveHeight * _cuticleOverlap;
    final Rect dest = Rect.fromLTWH(
      nb.center.dx - fitWidth / 2,
      bottom - fitHeight,
      fitWidth,
      fitHeight,
    );

    canvas.saveLayer(dest.inflate(dest.width), Paint());

    // Tint Almond 3D white shape PNG with gel color using BlendMode.modulate
    final Paint shapePaint = Paint()
      ..isAntiAlias = true
      ..colorFilter = ColorFilter.mode(
        color.withValues(alpha: 0.96),
        BlendMode.modulate,
      );
    canvas.drawImageRect(shape, src, dest, shapePaint);

    // ✨ Surface Shader Effects (Glossy, Chrome, Matte...)
    _applySurfaceShader(canvas, dest, variant.nailSurface);

    // 💍 Accessories / Charms / Stickers
    _renderComponents(canvas, dest.center, dest.width, dest.height, fingerIndex);

    // Mask to shape silhouette
    canvas.drawImageRect(
      shape,
      src,
      dest,
      Paint()..blendMode = BlendMode.dstIn,
    );

    canvas.restore();
  }

  /// 🎨 NATURAL NAIL BED COLOR FILL MODE
  void _paintNaturalNail(
    Canvas canvas,
    List<Offset> localPts,
    Rect nb,
    Color color,
    int fingerIndex,
  ) {
    final Path nailPath = Path()..addPolygon(localPts, true);

    canvas.save();
    canvas.clipPath(nailPath);

    canvas.drawPath(
      nailPath,
      Paint()
        ..color = color.withValues(alpha: 0.88)
        ..style = PaintingStyle.fill,
    );

    _applySurfaceShader(canvas, nb, variant.nailSurface);
    _renderComponents(canvas, nb.center, nb.width, nb.height, fingerIndex);

    canvas.restore();
  }

  /// Unit vector from cuticle toward fingertip.
  /// Solves TRAP 1 (Thumb Spreading), TRAP 2 (Hand Direction), and TRAP 3 (Single-Nail Extremity Tapering).
  Offset _tipDirection(
    List<Offset> poly,
    Offset center,
    Offset? across,
    Offset palmCenter,
    bool palmReliable,
    int fingerIndex,
    Offset? indexCentroid,
  ) {
    final fa = _fingerAxis(poly, center, across, fingerIndex: fingerIndex);
    Offset axis = fa.dir;

    // 📌 TRAP 1 FIX: THUMB ANATOMICAL SPREAD (fingerIndex == 1)
    if (fingerIndex == 1) {
      if (palmReliable) {
        final Offset radial = center - palmCenter;
        final double proj = axis.dx * radial.dx + axis.dy * radial.dy;
        axis = proj >= 0 ? axis : -axis;
      } else {
        axis = _signByExtremityTaper(poly, center, axis);
      }
      return axis;
    }

    // 📌 TRAP 2 FIX: MULTI-NAIL PALM CONTEXT
    if (palmReliable) {
      final Offset radial = center - palmCenter;
      final double proj = axis.dx * radial.dx + axis.dy * radial.dy;
      return proj >= 0 ? axis : -axis;
    }

    // 📌 TRAP 3 FIX: SINGLE-NAIL EXTREMITY TAPERING (Polygon Curvature Width Ratio)
    return _signByExtremityTaper(poly, center, axis);
  }

  /// 📌 TRAP 3 ENGINE: Measures contour width at +25% vs -25% along the candidate axis.
  /// Tip is narrower than Cuticle. Points vector from Cuticle -> Tip.
  Offset _signByExtremityTaper(List<Offset> poly, Offset center, Offset axis) {
    final double angle = math.atan2(axis.dx, -axis.dy);
    double minL = double.infinity, maxL = -double.infinity;

    final List<Offset> localPts = [];
    for (final pt in poly) {
      final lp = _rotate(pt - center, -angle);
      localPts.add(lp);
      if (lp.dy < minL) minL = lp.dy;
      if (lp.dy > maxL) maxL = lp.dy;
    }

    final double height = maxL - minL;
    if (height < 2) return axis.dy > 0 ? -axis : axis;

    final double yTop = minL + height * 0.25;
    final double yBottom = minL + height * 0.75;

    final double topWidth = _polygonWidthAtY(localPts, yTop);
    final double bottomWidth = _polygonWidthAtY(localPts, yBottom);

    if (topWidth <= bottomWidth) {
      return axis;
    } else {
      return -axis;
    }
  }

  double _polygonWidthAtY(List<Offset> localPts, double targetY) {
    double minX = double.infinity;
    double maxX = -double.infinity;

    for (int i = 0; i < localPts.length; i++) {
      final p1 = localPts[i];
      final p2 = localPts[(i + 1) % localPts.length];

      if ((p1.dy <= targetY && p2.dy >= targetY) || (p2.dy <= targetY && p1.dy >= targetY)) {
        if ((p1.dy - p2.dy).abs() > 1e-5) {
          final double t = (targetY - p1.dy) / (p2.dy - p1.dy);
          final double x = p1.dx + t * (p2.dx - p1.dx);
          if (x < minX) minX = x;
          if (x > maxX) maxX = x;
        }
      }
    }

    if (minX == double.infinity || maxX == -double.infinity) return 0.0;
    return maxX - minX;
  }

  static Offset _centroid(List<Offset> poly) {
    double sumX = 0, sumY = 0;
    for (final pt in poly) {
      sumX += pt.dx;
      sumY += pt.dy;
    }
    return Offset(sumX / poly.length, sumY / poly.length);
  }

  static Offset _rotate(Offset v, double angle) {
    final double c = math.cos(angle);
    final double s = math.sin(angle);
    return Offset(v.dx * c - v.dy * s, v.dx * s + v.dy * c);
  }

  /// Extracts color for the specific finger from colorConfig JSON
  Color _getFingerColor(int fingerIndex) {
    if (variant.colorConfig.fingers.isNotEmpty) {
      for (final f in variant.colorConfig.fingers) {
        if (f.fingerIndex == fingerIndex) {
          return _hexToColor(f.color);
        }
      }
      return _hexToColor(variant.colorConfig.fingers.first.color);
    }
    return const Color(0xFFFF4081); // Default Pink
  }

  Color _hexToColor(String hexString) {
    final buffer = StringBuffer();
    if (hexString.length == 6 || hexString.length == 7) buffer.write('ff');
    buffer.write(hexString.replaceFirst('#', ''));
    return Color(int.parse(buffer.toString(), radix: 16));
  }

  /// Applies surface lightness/saturation/hue offsets
  Color _applySurfaceHsl(Color color, NailSurface surface) {
    double frac(double v) => v.abs() > 1.0 ? v / 100.0 : v;
    final double dl = frac(surface.lightnessOffset);
    final double ds = frac(surface.saturationOffset);
    final double dh = surface.hueOffset % 360.0;
    if (dl == 0 && ds == 0 && dh == 0) return color;

    HSLColor hsl = HSLColor.fromColor(color);
    hsl = hsl
        .withHue((hsl.hue + dh) % 360.0)
        .withSaturation((hsl.saturation + ds).clamp(0.0, 1.0))
        .withLightness((hsl.lightness + dl).clamp(0.0, 1.0));
    return hsl.toColor();
  }

  /// Shader Effects Engine (Glossy, Chrome, Matte, Cat Eye...)
  void _applySurfaceShader(Canvas canvas, Rect bounds, NailSurface surface) {
    final SurfaceShaderParams p = surface.params;
    final String type = p.resolveType(surface.name);

    switch (type) {
      case 'chrome':
        final double refl = p.reflectivity.clamp(0.0, 1.0);
        final Paint chromePaint = Paint()
          ..shader = ui.Gradient.linear(
            bounds.topLeft,
            bounds.bottomRight,
            [
              Colors.white.withValues(alpha: 0.70 * refl),
              Colors.transparent,
              Colors.white.withValues(alpha: 0.40 * refl),
              Colors.black.withValues(alpha: 0.30 * p.metallic.clamp(0.0, 1.0)),
              Colors.white.withValues(alpha: 0.80 * refl),
            ],
            [0.0, 0.3, 0.5, 0.7, 1.0],
          )
          ..blendMode = BlendMode.overlay;
        canvas.drawRect(bounds, chromePaint);
        break;

      case 'cateye':
        final Paint catEyePaint = Paint()
          ..shader = ui.Gradient.linear(
            bounds.topRight,
            bounds.bottomLeft,
            [
              Colors.transparent,
              Colors.white.withValues(alpha: 0.85),
              Colors.transparent,
            ],
            [0.35, 0.50, 0.65],
          )
          ..blendMode = BlendMode.screen;
        canvas.drawRect(bounds, catEyePaint);
        break;

      case 'matte':
        final double roughness = p.roughness.clamp(0.0, 1.0);
        final Paint mattePaint = Paint()
          ..color = Colors.white.withValues(alpha: 0.06 + 0.10 * roughness)
          ..blendMode = BlendMode.softLight;
        canvas.drawRect(bounds, mattePaint);
        break;

      default:
        if (!p.shineEnabled) return;
        final double shine = p.shineOpacity.clamp(0.0, 1.0);
        final Paint glossyPaint = Paint()
          ..shader = ui.Gradient.radial(
            bounds.centerLeft - const Offset(0, 10),
            bounds.width * 0.6,
            [
              Colors.white.withValues(alpha: 0.60 * shine),
              Colors.white.withValues(alpha: 0.0),
            ],
          )
          ..blendMode = BlendMode.screen;
        canvas.drawRect(bounds, glossyPaint);
    }
  }

  /// Renders Charms/Stickers from normalized posX/posY (-1 to 1)
  void _renderComponents(
    Canvas canvas,
    Offset center,
    double nailWidth,
    double nailHeight,
    int fingerIndex,
  ) {
    for (final compItem in variant.nailComponents) {
      if (compItem.fingerIndex != -1 && compItem.fingerIndex != fingerIndex) {
        continue;
      }

      final ui.Image? charmImage =
          componentImages[compItem.component.componentId];
      if (charmImage == null) continue;

      final double charmPixelX = center.dx + compItem.posX * (nailWidth / 2);
      final double charmPixelY = center.dy + compItem.posY * (nailHeight / 2);

      final double charmTargetWidth = nailWidth * compItem.scale;
      final double charmAspectRatio = charmImage.height / charmImage.width;
      final double charmTargetHeight = charmTargetWidth * charmAspectRatio;

      canvas.save();
      canvas.translate(charmPixelX, charmPixelY);
      canvas.rotate(compItem.rotation * math.pi / 180.0);

      canvas.drawImageRect(
        charmImage,
        Rect.fromLTWH(
            0, 0, charmImage.width.toDouble(), charmImage.height.toDouble()),
        Rect.fromCenter(
          center: Offset.zero,
          width: charmTargetWidth,
          height: charmTargetHeight,
        ),
        Paint()..isAntiAlias = true,
      );

      canvas.restore();
    }
  }

  void _drawFingerHighlight(Canvas canvas, Rect nb) {
    final Paint paint = Paint()
      ..color = const Color(0xFFFF4081).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2;

    final RRect rrect = RRect.fromRectAndRadius(
      nb.inflate(3),
      const Radius.circular(8),
    );
    canvas.drawRRect(rrect, paint);
  }

  void _renderComponentBoundingBoxOverlay(
    Canvas canvas,
    Rect nb,
    int fingerIndex, {
    double? poseLength,
  }) {
    if (selectedComponentId == null) return;

    for (final compItem in variant.nailComponents) {
      if (compItem.nailComponentId != selectedComponentId) continue;
      if (compItem.fingerIndex != -1 && compItem.fingerIndex != fingerIndex) continue;

      final ui.Image? charmImage = componentImages[compItem.component.componentId];
      if (charmImage == null) continue;

      final double effectiveHeight = (poseLength != null && poseLength > 0)
          ? math.max(nb.height, poseLength)
          : nb.height;

      final double fitWidth = nb.width * _widthCover;
      final double fitHeight = nailShapeImage != null
          ? math.max(fitWidth * (nailShapeImage!.height / nailShapeImage!.width), effectiveHeight * _minHeightCover)
          : nb.height;

      final double bottom = nb.bottom + effectiveHeight * _cuticleOverlap;
      final Rect dest = Rect.fromLTWH(
        nb.center.dx - fitWidth / 2,
        bottom - fitHeight,
        fitWidth,
        fitHeight,
      );

      final double charmPixelX = dest.center.dx + compItem.posX * (dest.width / 2);
      final double charmPixelY = dest.center.dy + compItem.posY * (dest.height / 2);

      final double charmTargetWidth = dest.width * compItem.scale;
      final double charmAspectRatio = charmImage.height / charmImage.width;
      final double charmTargetHeight = charmTargetWidth * charmAspectRatio;

      canvas.save();
      canvas.translate(charmPixelX, charmPixelY);
      canvas.rotate(compItem.rotation * math.pi / 180.0);

      final Rect boxRect = Rect.fromCenter(
        center: Offset.zero,
        width: charmTargetWidth + 6,
        height: charmTargetHeight + 6,
      );

      final Paint boxPaint = Paint()
        ..color = const Color(0xFFFF4081)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0;

      canvas.drawRect(boxRect, boxPaint);

      // 1. Top-Right handle (Scale / Rotate)
      final Offset trHandle = boxRect.topRight;
      final Paint trBgPaint = Paint()..color = const Color(0xFFFF4081);
      canvas.drawCircle(trHandle, 11, trBgPaint);

      final Paint iconPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round;

      canvas.drawLine(trHandle + const Offset(-4, 4), trHandle + const Offset(4, -4), iconPaint);
      canvas.drawLine(trHandle + const Offset(4, -4), trHandle + const Offset(1, -4), iconPaint);
      canvas.drawLine(trHandle + const Offset(4, -4), trHandle + const Offset(4, -1), iconPaint);

      // 2. Bottom-Left handle (Delete 'X')
      final Offset blHandle = boxRect.bottomLeft;
      final Paint blBgPaint = Paint()..color = Colors.redAccent.shade700;
      canvas.drawCircle(blHandle, 11, blBgPaint);

      canvas.drawLine(blHandle + const Offset(-4, -4), blHandle + const Offset(4, 4), iconPaint);
      canvas.drawLine(blHandle + const Offset(-4, 4), blHandle + const Offset(4, -4), iconPaint);

      canvas.restore();
    }
  }

  /// Computes transformation info for all detected fingernails
  List<FingerTransformInfo> computeTransforms() {
    if (polygons.isEmpty) return [];

    final Offset? across = _acrossHandAxis(polygons);
    final palmInfo = _estimatePalmCenter(polygons, across);
    final List<FingerTransformInfo> result = [];

    for (int i = 0; i < polygons.length; i++) {
      final poly = polygons[i];
      if (poly.length < 3) continue;

      int fingerIndex = i + 1;
      if (labels != null && i < labels!.length) {
        fingerIndex = _labelToFingerIndex(labels![i], defaultIdx: fingerIndex);
      }

      NailPoseKeypoints? poseKpt;
      if (poseKeypoints != null && i < poseKeypoints!.length) {
        poseKpt = poseKeypoints![i];
      }

      final Offset center = _centroid(poly);
      final bool isPoseValid = (poseKpt != null) &&
          (poseKpt.tip - poseKpt.base).distance >= 2.0 &&
          poseKpt.tip.dx > 5 && poseKpt.tip.dy > 5 &&
          poseKpt.base.dx > 5 && poseKpt.base.dy > 5;

      final Offset tipDir = isPoseValid
          ? poseKpt.direction
          : _tipDirection(
              poly,
              center,
              across,
              palmInfo.center,
              palmInfo.reliable,
              fingerIndex,
              palmInfo.indexCentroid,
            );

      final double angle = math.atan2(tipDir.dx, -tipDir.dy);

      final List<Offset> localPts = [
        for (final pt in poly) _rotate(pt - center, -angle),
      ];
      double minX = double.infinity, minY = double.infinity;
      double maxX = -double.infinity, maxY = -double.infinity;
      for (final lp in localPts) {
        if (lp.dx < minX) minX = lp.dx;
        if (lp.dy < minY) minY = lp.dy;
        if (lp.dx > maxX) maxX = lp.dx;
        if (lp.dy > maxY) maxY = lp.dy;
      }
      final Rect localBounds = Rect.fromLTRB(minX, minY, maxX, maxY);
      if (localBounds.width < 2 || localBounds.height < 2) continue;

      final double effectiveHeight = (isPoseValid && (poseKpt.tip - poseKpt.base).distance > 0)
          ? math.max(localBounds.height, (poseKpt.tip - poseKpt.base).distance)
          : localBounds.height;

      final double fitWidth = localBounds.width * _widthCover;
      final double fitHeight = nailShapeImage != null
          ? math.max(fitWidth * (nailShapeImage!.height / nailShapeImage!.width), effectiveHeight * _minHeightCover)
          : localBounds.height;

      final double bottom = localBounds.bottom + effectiveHeight * _cuticleOverlap;
      final Rect dest = Rect.fromLTWH(
        localBounds.center.dx - fitWidth / 2,
        bottom - fitHeight,
        fitWidth,
        fitHeight,
      );

      result.add(FingerTransformInfo(
        fingerIndex: fingerIndex,
        polygonCentroid: center,
        angle: angle,
        localBounds: localBounds,
        destRect: dest,
        polygonPoints: poly,
      ));
    }

    return result;
  }

  @override
  bool shouldRepaint(covariant AdvancedNailPainter oldDelegate) =>
      oldDelegate.polygons != polygons ||
      oldDelegate.labels != labels ||
      oldDelegate.poseKeypoints != poseKeypoints ||
      oldDelegate.variant != variant ||
      oldDelegate.nailShapeImage != nailShapeImage ||
      oldDelegate.componentImages != componentImages ||
      oldDelegate.selectedFingerIndex != selectedFingerIndex ||
      oldDelegate.selectedComponentId != selectedComponentId;
}

class FingerTransformInfo {
  final int fingerIndex;
  final Offset polygonCentroid;
  final double angle;
  final Rect localBounds;
  final Rect destRect;
  final List<Offset> polygonPoints;

  FingerTransformInfo({
    required this.fingerIndex,
    required this.polygonCentroid,
    required this.angle,
    required this.localBounds,
    required this.destRect,
    required this.polygonPoints,
  });

  /// Converts point from Canvas (Image) coordinates to Finger Local space
  Offset canvasToLocal(Offset canvasPoint) {
    final Offset rel = canvasPoint - polygonCentroid;
    final double c = math.cos(-angle);
    final double s = math.sin(-angle);
    return Offset(rel.dx * c - rel.dy * s, rel.dx * s + rel.dy * c);
  }

  /// Converts point from Finger Local space to Canvas (Image) coordinates
  Offset localToCanvas(Offset localPoint) {
    final double c = math.cos(angle);
    final double s = math.sin(angle);
    final Offset rotated = Offset(localPoint.dx * c - localPoint.dy * s, localPoint.dx * s + localPoint.dy * c);
    return polygonCentroid + rotated;
  }
}
