import 'package:flutter/material.dart';

import '../models/placed_component_draft.dart';

class TryOnPlacementControls extends StatelessWidget {
  final PlacedComponentDraft? selectedPlacement;
  final VoidCallback onMoveLeft;
  final VoidCallback onMoveRight;
  final VoidCallback onMoveUp;
  final VoidCallback onMoveDown;
  final VoidCallback onScaleDown;
  final VoidCallback onScaleUp;
  final VoidCallback onRotateLeft;
  final VoidCallback onRotateRight;
  final VoidCallback onRemove;

  const TryOnPlacementControls({
    super.key,
    required this.selectedPlacement,
    required this.onMoveLeft,
    required this.onMoveRight,
    required this.onMoveUp,
    required this.onMoveDown,
    required this.onScaleDown,
    required this.onScaleUp,
    required this.onRotateLeft,
    required this.onRotateRight,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = selectedPlacement != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                selectedPlacement?.name ?? 'Select a placed component',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            ),
            IconButton(
              onPressed: enabled ? onRemove : null,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            IconButton.filledTonal(
              onPressed: enabled ? onMoveLeft : null,
              icon: const Icon(Icons.chevron_left),
            ),
            IconButton.filledTonal(
              onPressed: enabled ? onMoveUp : null,
              icon: const Icon(Icons.keyboard_arrow_up),
            ),
            IconButton.filledTonal(
              onPressed: enabled ? onMoveDown : null,
              icon: const Icon(Icons.keyboard_arrow_down),
            ),
            IconButton.filledTonal(
              onPressed: enabled ? onMoveRight : null,
              icon: const Icon(Icons.chevron_right),
            ),
            IconButton.filledTonal(
              onPressed: enabled ? onScaleDown : null,
              icon: const Icon(Icons.remove),
            ),
            IconButton.filledTonal(
              onPressed: enabled ? onScaleUp : null,
              icon: const Icon(Icons.add),
            ),
            IconButton.filledTonal(
              onPressed: enabled ? onRotateLeft : null,
              icon: const Icon(Icons.rotate_left),
            ),
            IconButton.filledTonal(
              onPressed: enabled ? onRotateRight : null,
              icon: const Icon(Icons.rotate_right),
            ),
          ],
        ),
      ],
    );
  }
}
