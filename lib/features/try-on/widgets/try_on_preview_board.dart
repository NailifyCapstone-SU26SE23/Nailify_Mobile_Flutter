import 'dart:convert';

import 'package:flutter/material.dart';

import '../../nails/data/models/customer_nail_models.dart';
import '../../nails/data/models/nail_shape_model.dart';
import '../../nails/data/models/nail_surface_model.dart';
import '../models/placed_component_draft.dart';
import '../utils/try_on_setup_helpers.dart';

class TryOnPreviewBoard extends StatelessWidget {
  final CustomerNailModel? nail;
  final NailShapeModel? selectedShape;
  final NailSurfaceModel? selectedSurface;
  final String selectedColor;
  final List<String>? gradientStops;
  final Map<int, String> fingerColors;
  final Map<int, List<String>?> fingerGradients;
  final int selectedFingerIndex;
  final int? detailFingerIndex;
  final List<PlacedComponentDraft> placements;
  final int? selectedPlacementId;
  final ValueChanged<int> onSelectPlacement;
  final ValueChanged<int>? onToggleDetailFinger;

  const TryOnPreviewBoard({
    super.key,
    required this.nail,
    required this.selectedShape,
    required this.selectedSurface,
    required this.selectedColor,
    required this.gradientStops,
    required this.fingerColors,
    required this.fingerGradients,
    required this.selectedFingerIndex,
    required this.detailFingerIndex,
    required this.placements,
    required this.selectedPlacementId,
    required this.onSelectPlacement,
    this.onToggleDetailFinger,
  });

  @override
  Widget build(BuildContext context) {
    if (selectedFingerIndex == -1 && detailFingerIndex == null) {
      return AspectRatio(
        aspectRatio: 2.25,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.black12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                for (var finger = 1; finger <= 5; finger++) ...[
                  Expanded(
                    child: FingerPreviewTile(
                      selectedShape: selectedShape,
                      selectedSurface: selectedSurface,
                      color: fingerColors[finger] ?? selectedColor,
                      gradientStops: fingerGradients[finger] ?? gradientStops,
                      placements: placements
                          .where(
                            (p) =>
                                placementMatchesFinger(p.fingerIndex, finger),
                          )
                          .toList(),
                      selectedPlacementId: selectedPlacementId,
                      onSelectPlacement: onSelectPlacement,
                      onTap: () => onToggleDetailFinger?.call(finger),
                      compact: true,
                    ),
                  ),
                  if (finger < 5) const SizedBox(width: 6),
                ],
              ],
            ),
          ),
        ),
      );
    }

    final previewFingerIndex = selectedFingerIndex == -1
        ? (detailFingerIndex ?? 1)
        : selectedFingerIndex;

    return AspectRatio(
      aspectRatio: 1.1,
      child: FingerPreviewTile(
        selectedShape: selectedShape,
        selectedSurface: selectedSurface,
        color: selectedFingerIndex == -1
            ? fingerColors[previewFingerIndex] ?? selectedColor
            : selectedColor,
        gradientStops: selectedFingerIndex == -1
            ? fingerGradients[previewFingerIndex] ?? gradientStops
            : gradientStops,
        placements: placements
            .where(
              (p) => placementMatchesFinger(p.fingerIndex, previewFingerIndex),
            )
            .toList(),
        selectedPlacementId: selectedPlacementId,
        onSelectPlacement: onSelectPlacement,
        onTap: selectedFingerIndex == -1 || detailFingerIndex != null
            ? () => onToggleDetailFinger?.call(previewFingerIndex)
            : null,
      ),
    );
  }
}

class FingerPreviewTile extends StatelessWidget {
  final NailShapeModel? selectedShape;
  final NailSurfaceModel? selectedSurface;
  final String color;
  final List<String>? gradientStops;
  final List<PlacedComponentDraft> placements;
  final int? selectedPlacementId;
  final ValueChanged<int> onSelectPlacement;
  final VoidCallback? onTap;
  final bool compact;

  const FingerPreviewTile({
    required this.selectedShape,
    required this.selectedSurface,
    required this.color,
    required this.gradientStops,
    required this.placements,
    required this.selectedPlacementId,
    required this.onSelectPlacement,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final nailWidth = constraints.maxWidth * (compact ? 0.86 : 0.72);
            final nailHeight = constraints.maxHeight * (compact ? 0.9 : 0.9);
            final nailLeft = (constraints.maxWidth - nailWidth) / 2;
            final nailTop = (constraints.maxHeight - nailHeight) / 2;

            return Stack(
              children: [
                const Positioned.fill(child: _TryOnPreviewFallback()),
                if (selectedShape?.imageUrl.isNotEmpty == true)
                  Positioned(
                    left: nailLeft,
                    top: nailTop,
                    width: nailWidth,
                    height: nailHeight,
                    child: _NailColorPreview(
                      imageUrl: selectedShape!.imageUrl,
                      color: color,
                      gradientStops: gradientStops,
                      surface: selectedSurface,
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        selectedShape?.name ?? 'Select nail shape',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: compact ? 11 : null,
                        ),
                      ),
                    ),
                  ),
                if (selectedShape?.imageUrl.isNotEmpty == true)
                  Positioned(
                    left: nailLeft,
                    top: nailTop,
                    width: nailWidth,
                    height: nailHeight,
                    child: Stack(
                      children: placements.map((placement) {
                        final size =
                            nailWidth * placement.scale.clamp(0.1, 1.5);
                        final centerX =
                            nailWidth / 2 + placement.posX * nailWidth;
                        final centerY =
                            nailHeight / 2 + placement.posY * nailHeight;
                        return _PlacedComponentPreview(
                          placement: placement,
                          selected: selectedPlacementId == placement.localId,
                          size: size,
                          left: centerX - size / 2,
                          top: centerY - size / 2,
                          compact: compact,
                          onSelectPlacement: onSelectPlacement,
                        );
                      }).toList(),
                    ),
                  )
                else
                  ...placements.map((placement) {
                    final size =
                        constraints.maxWidth *
                        0.6 *
                        placement.scale.clamp(0.1, 1.5);
                    final centerX =
                        constraints.maxWidth / 2 +
                        placement.posX * constraints.maxWidth;
                    final centerY =
                        constraints.maxHeight / 2 +
                        placement.posY * constraints.maxHeight;
                    return _PlacedComponentPreview(
                      placement: placement,
                      selected: selectedPlacementId == placement.localId,
                      size: size,
                      left: centerX - size / 2,
                      top: centerY - size / 2,
                      compact: compact,
                      onSelectPlacement: onSelectPlacement,
                    );
                  }),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PlacedComponentPreview extends StatelessWidget {
  final PlacedComponentDraft placement;
  final bool selected;
  final double size;
  final double left;
  final double top;
  final bool compact;
  final ValueChanged<int> onSelectPlacement;

  const _PlacedComponentPreview({
    required this.placement,
    required this.selected,
    required this.size,
    required this.left,
    required this.top,
    required this.compact,
    required this.onSelectPlacement,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: left,
      top: top,
      child: GestureDetector(
        onTap: () => onSelectPlacement(placement.localId),
        child: Transform.rotate(
          angle: placement.rotation * 3.14159265359 / 180,
          child: Container(
            width: size,
            height: size,
            padding: EdgeInsets.all(compact ? 1 : 2),
            decoration: BoxDecoration(
              color: Colors.transparent,
              border: Border.all(
                color: selected ? Colors.purple : Colors.transparent,
                width: selected ? 2 : 1,
              ),
              borderRadius: BorderRadius.circular(compact ? 3 : 4),
            ),
            child: placement.imageUrl.isEmpty
                ? Icon(
                    Icons.auto_awesome,
                    color: Colors.purple,
                    size: compact ? 12 : 16,
                  )
                : Image.network(
                    placement.imageUrl,
                    fit: BoxFit.contain,
                    errorBuilder: (_, _, _) => Icon(
                      Icons.auto_awesome,
                      color: Colors.purple,
                      size: compact ? 12 : 16,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _NailColorPreview extends StatelessWidget {
  final String imageUrl;
  final String color;
  final List<String>? gradientStops;
  final NailSurfaceModel? surface;

  const _NailColorPreview({
    required this.imageUrl,
    required this.color,
    required this.gradientStops,
    required this.surface,
  });

  @override
  Widget build(BuildContext context) {
    final stops = gradientStops;
    final baseColor = _applySurfaceOffsets(parseTryOnHexColor(color), surface);
    final adjustedStops = stops
        ?.take(3)
        .map((item) => _applySurfaceOffsets(parseTryOnHexColor(item), surface))
        .toList();
    final shader = _SurfaceShader.fromSurface(surface);

    Widget nailImage;
    if (stops == null || stops.length < 2) {
      nailImage = Image.network(
        imageUrl,
        fit: BoxFit.contain,
        color: baseColor,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    } else {
      nailImage = ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (bounds) => LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: adjustedStops ?? [baseColor, baseColor],
        ).createShader(bounds),
        child: Image.network(
          imageUrl,
          fit: BoxFit.contain,
          color: Colors.white,
          colorBlendMode: BlendMode.srcIn,
          errorBuilder: (_, _, _) => const SizedBox.shrink(),
        ),
      );
    }

    return Stack(
      fit: StackFit.expand,
      children: [
        nailImage,
        if (shader.matte)
          _GradientNailLayer(
            imageUrl: imageUrl,
            gradient: LinearGradient(
              colors: [
                Colors.black.withOpacity(0.08),
                Colors.black.withOpacity(0.08),
              ],
            ),
          ),
        if (shader.gradient)
          _GradientNailLayer(
            imageUrl: imageUrl,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.black.withOpacity(0.18),
                Colors.transparent,
                Colors.white.withOpacity(0.22),
              ],
            ),
          ),
        if (shader.stripe)
          _GradientNailLayer(
            imageUrl: imageUrl,
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              colors: [
                Colors.transparent,
                Colors.white.withOpacity(0.42),
                Colors.transparent,
              ],
              stops: const [0.38, 0.5, 0.62],
            ),
          ),
        if (shader.rainbow)
          _GradientNailLayer(
            imageUrl: imageUrl,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.red.withOpacity(0.28),
                Colors.yellow.withOpacity(0.24),
                Colors.green.withOpacity(0.22),
                Colors.blue.withOpacity(0.24),
                Colors.purple.withOpacity(0.28),
              ],
            ),
          ),
        if (shader.metallic)
          _GradientNailLayer(
            imageUrl: imageUrl,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.white.withOpacity(0.52),
                Colors.transparent,
                Colors.black.withOpacity(0.16),
                Colors.white.withOpacity(0.36),
              ],
              stops: const [0, 0.32, 0.62, 1],
            ),
          ),
        if (shader.shine)
          _GradientNailLayer(
            imageUrl: imageUrl,
            gradient: RadialGradient(
              center: shader.shineAlignment,
              radius: shader.shineSize,
              colors: [
                Colors.white.withOpacity(shader.shineOpacity),
                Colors.white.withOpacity(0),
              ],
            ),
          ),
      ],
    );
  }
}

class _GradientNailLayer extends StatelessWidget {
  final String imageUrl;
  final Gradient gradient;

  const _GradientNailLayer({required this.imageUrl, required this.gradient});

  @override
  Widget build(BuildContext context) {
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: gradient.createShader,
      child: Image.network(
        imageUrl,
        fit: BoxFit.contain,
        color: Colors.white,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      ),
    );
  }
}

Color _applySurfaceOffsets(Color color, NailSurfaceModel? surface) {
  if (surface == null) return color;
  final hsl = HSLColor.fromColor(color);
  return hsl
      .withHue((hsl.hue + surface.hueOffset) % 360)
      .withSaturation(
        (hsl.saturation + surface.saturationOffset).clamp(0.0, 1.0),
      )
      .withLightness((hsl.lightness + surface.lightnessOffset).clamp(0.0, 1.0))
      .toColor();
}

class _SurfaceShader {
  final bool matte;
  final bool shine;
  final bool metallic;
  final bool stripe;
  final bool gradient;
  final bool rainbow;
  final Alignment shineAlignment;
  final double shineSize;
  final double shineOpacity;

  const _SurfaceShader({
    required this.matte,
    required this.shine,
    required this.metallic,
    required this.stripe,
    required this.gradient,
    required this.rainbow,
    required this.shineAlignment,
    required this.shineSize,
    required this.shineOpacity,
  });

  factory _SurfaceShader.fromSurface(NailSurfaceModel? surface) {
    final params = _decodeShaderParams(surface?.shaderParam);
    final name = surface?.name.toLowerCase() ?? '';
    final shine = _asMap(params['shine']);
    final metalness = _asMap(params['metalness']);
    final stripe = _asMap(params['stripe']);
    final gradient = _asMap(params['gradient']);
    final prism = _asMap(params['prism']);
    final rainbow = _asMap(params['rainbow']);
    final iridescence = _asMap(params['iridescence']);

    return _SurfaceShader(
      matte:
          name.contains('matte') ||
          _asMap(params['texture'])?['type'] == 'matte',
      shine: _asEnabled(shine),
      metallic: name.contains('chrome') || _asEnabled(metalness),
      stripe: name.contains('cat') || _asEnabled(stripe),
      gradient: _asEnabled(gradient),
      rainbow:
          name.contains('holographic') ||
          _asEnabled(prism) ||
          _asEnabled(rainbow) ||
          _asEnabled(iridescence),
      shineAlignment: _alignmentFromPosition(shine?['position']?.toString()),
      shineSize: (_asDouble(shine?['size'], fallback: 0.42)).clamp(0.18, 0.9),
      shineOpacity: (_asDouble(
        shine?['opacity'],
        fallback: 0.55,
      )).clamp(0.0, 1.0),
    );
  }
}

Map<String, dynamic> _decodeShaderParams(String? value) {
  if (value == null || value.trim().isEmpty) return const {};
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return const {};
}

Map<String, dynamic>? _asMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return null;
}

bool _asEnabled(Map<String, dynamic>? value) => value?['enabled'] == true;

double _asDouble(dynamic value, {required double fallback}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

Alignment _alignmentFromPosition(String? value) {
  switch (value) {
    case 'top-left':
      return Alignment.topLeft;
    case 'top-right':
      return Alignment.topRight;
    case 'center':
      return Alignment.center;
    default:
      return Alignment.topRight;
  }
}

class _TryOnPreviewFallback extends StatelessWidget {
  const _TryOnPreviewFallback();

  @override
  Widget build(BuildContext context) {
    return Container(alignment: Alignment.center, color: Colors.white);
  }
}
