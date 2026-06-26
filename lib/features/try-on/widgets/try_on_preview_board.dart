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
                    child: _FingerPreviewTile(
                      selectedShape: selectedShape,
                      color: fingerColors[finger] ?? selectedColor,
                      gradientStops: fingerGradients[finger] ?? gradientStops,
                      placements: placements
                          .where(
                            (p) => placementMatchesFinger(p.fingerIndex, finger),
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
      child: _FingerPreviewTile(
        selectedShape: selectedShape,
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

class _FingerPreviewTile extends StatelessWidget {
  final NailShapeModel? selectedShape;
  final String color;
  final List<String>? gradientStops;
  final List<PlacedComponentDraft> placements;
  final int? selectedPlacementId;
  final ValueChanged<int> onSelectPlacement;
  final VoidCallback? onTap;
  final bool compact;

  const _FingerPreviewTile({
    required this.selectedShape,
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
                        final centerX = nailWidth / 2 + placement.posX * nailWidth;
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
                    final size = constraints.maxWidth *
                        0.6 *
                        placement.scale.clamp(0.1, 1.5);
                    final centerX = constraints.maxWidth / 2 +
                        placement.posX * constraints.maxWidth;
                    final centerY = constraints.maxHeight / 2 +
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
