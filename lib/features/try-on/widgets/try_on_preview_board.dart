import 'package:flutter/material.dart';

import '../../nails/data/models/customer_nail_models.dart';
import '../../nails/data/models/nail_shape_model.dart';
import '../models/placed_component_draft.dart';
import '../utils/try_on_setup_helpers.dart';

class TryOnPreviewBoard extends StatelessWidget {
  final CustomerNailModel? nail;
  final NailShapeModel? selectedShape;
  final String selectedColor;
  final List<String>? gradientStops;
  final int selectedFingerIndex;
  final List<PlacedComponentDraft> placements;
  final int? selectedPlacementId;
  final ValueChanged<int> onSelectPlacement;

  const TryOnPreviewBoard({
    super.key,
    required this.nail,
    required this.selectedShape,
    required this.selectedColor,
    required this.gradientStops,
    required this.selectedFingerIndex,
    required this.placements,
    required this.selectedPlacementId,
    required this.onSelectPlacement,
  });

  @override
  Widget build(BuildContext context) {
    final filteredPlacements = placements.where((p) {
      return placementMatchesFinger(p.fingerIndex, selectedFingerIndex);
    }).toList();

    return AspectRatio(
      aspectRatio: 1.1,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final nailWidth = constraints.maxWidth * 0.6;
            final nailHeight = constraints.maxHeight * 0.8;
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
                      color: selectedColor,
                      gradientStops: gradientStops,
                    ),
                  )
                else
                  Align(
                    alignment: Alignment.bottomCenter,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        selectedShape?.name ?? 'Select nail shape',
                        style: const TextStyle(fontWeight: FontWeight.w800),
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
                      children: filteredPlacements.map((placement) {
                        final size = nailWidth * placement.scale.clamp(0.1, 1.5);
                        final centerX = nailWidth / 2 + placement.posX * nailWidth;
                        final centerY = nailHeight / 2 + placement.posY * nailHeight;
                        return Positioned(
                          left: centerX - size / 2,
                          top: centerY - size / 2,
                          child: GestureDetector(
                            onTap: () => onSelectPlacement(placement.localId),
                            child: Transform.rotate(
                              angle: placement.rotation * 3.14159265359 / 180,
                              child: Container(
                                width: size,
                                height: size,
                                padding: const EdgeInsets.all(2),
                                decoration: BoxDecoration(
                                  color: Colors.transparent,
                                  border: Border.all(
                                    color: selectedPlacementId == placement.localId
                                        ? Colors.purple
                                        : Colors.transparent,
                                    width: selectedPlacementId == placement.localId ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: placement.imageUrl.isEmpty
                                    ? const Icon(Icons.auto_awesome, color: Colors.purple, size: 16)
                                    : Image.network(
                                        placement.imageUrl,
                                        fit: BoxFit.contain,
                                        errorBuilder: (_, _, _) =>
                                            const Icon(Icons.auto_awesome, color: Colors.purple, size: 16),
                                      ),
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  )
                else
                  ...filteredPlacements.map((placement) {
                    final size = constraints.maxWidth * 0.6 * placement.scale.clamp(0.1, 1.5);
                    final centerX = constraints.maxWidth / 2 + placement.posX * constraints.maxWidth;
                    final centerY = constraints.maxHeight / 2 + placement.posY * constraints.maxHeight;
                    return Positioned(
                      left: centerX - size / 2,
                      top: centerY - size / 2,
                      child: GestureDetector(
                        onTap: () => onSelectPlacement(placement.localId),
                        child: Transform.rotate(
                          angle: placement.rotation * 3.14159265359 / 180,
                          child: Container(
                            width: size,
                            height: size,
                            padding: const EdgeInsets.all(4),
                            decoration: BoxDecoration(
                              color: Colors.transparent,
                              border: Border.all(
                                color: selectedPlacementId == placement.localId
                                    ? Colors.purple
                                    : Colors.transparent,
                                width: selectedPlacementId == placement.localId ? 2 : 1,
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: placement.imageUrl.isEmpty
                                ? const Icon(Icons.auto_awesome, color: Colors.purple)
                                : Image.network(
                                    placement.imageUrl,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, _, _) =>
                                        const Icon(Icons.auto_awesome, color: Colors.purple),
                                  ),
                          ),
                        ),
                      ),
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

class _NailColorPreview extends StatelessWidget {
  final String imageUrl;
  final String color;
  final List<String>? gradientStops;

  const _NailColorPreview({
    required this.imageUrl,
    required this.color,
    required this.gradientStops,
  });

  @override
  Widget build(BuildContext context) {
    final stops = gradientStops;
    if (stops == null || stops.length < 2) {
      return Image.network(
        imageUrl,
        fit: BoxFit.contain,
        color: parseTryOnHexColor(color),
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (_, _, _) => const SizedBox.shrink(),
      );
    }

    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: (bounds) => LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: stops.take(3).map(parseTryOnHexColor).toList(),
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
}

class _TryOnPreviewFallback extends StatelessWidget {
  const _TryOnPreviewFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: Colors.white,
    );
  }
}
