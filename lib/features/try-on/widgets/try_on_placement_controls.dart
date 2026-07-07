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
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.grey.shade200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Bên trái: Thu phóng
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RemoteBtn(icon: Icons.add, onPressed: enabled ? onScaleUp : null),
              const SizedBox(height: 16),
              _RemoteBtn(icon: Icons.remove, onPressed: enabled ? onScaleDown : null),
            ],
          ),
          
          // Ở giữa: D-Pad
          SizedBox(
            width: 140,
            height: 140,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(top: 0, child: _RemoteBtn(icon: Icons.keyboard_arrow_up, onPressed: enabled ? onMoveUp : null)),
                Positioned(bottom: 0, child: _RemoteBtn(icon: Icons.keyboard_arrow_down, onPressed: enabled ? onMoveDown : null)),
                Positioned(left: 0, child: _RemoteBtn(icon: Icons.keyboard_arrow_left, onPressed: enabled ? onMoveLeft : null)),
                Positioned(right: 0, child: _RemoteBtn(icon: Icons.keyboard_arrow_right, onPressed: enabled ? onMoveRight : null)),
                _RemoteBtn(
                  icon: Icons.delete_outline,
                  color: Colors.red.shade50,
                  iconColor: Colors.red.shade400,
                  onPressed: enabled ? onRemove : null,
                ),
              ],
            ),
          ),

          // Bên phải: Xoay
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RemoteBtn(icon: Icons.rotate_right, onPressed: enabled ? onRotateRight : null),
              const SizedBox(height: 16),
              _RemoteBtn(icon: Icons.rotate_left, onPressed: enabled ? onRotateLeft : null),
            ],
          ),
        ],
      ),
    );
  }
}

class _RemoteBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onPressed;
  final Color? color;
  final Color? iconColor;

  const _RemoteBtn({
    required this.icon,
    this.onPressed,
    this.color,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 48,
      child: FilledButton.tonal(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          padding: EdgeInsets.zero,
          backgroundColor: color ?? Theme.of(context).colorScheme.primaryContainer,
          foregroundColor: iconColor ?? Theme.of(context).colorScheme.primary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: Icon(icon, size: 24),
      ),
    );
  }
}
