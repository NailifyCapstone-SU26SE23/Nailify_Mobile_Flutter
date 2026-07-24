import 'dart:async';
import 'package:flutter/material.dart';

import '../models/placed_component_draft.dart';

class TryOnPlacementControls extends StatefulWidget {
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
  State<TryOnPlacementControls> createState() => _TryOnPlacementControlsState();
}

class _TryOnPlacementControlsState extends State<TryOnPlacementControls> {
  Timer? _throttleTimer;
  bool _canEmit = true;

  void _handleAction(VoidCallback action) {
    if (!_canEmit) return;
    
    action();
    _canEmit = false;
    _throttleTimer?.cancel();
    _throttleTimer = Timer(const Duration(milliseconds: 66), () {
      if (mounted) {
        _canEmit = true;
      }
    });
  }

  @override
  void dispose() {
    _throttleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.selectedPlacement != null;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant, width: 1),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Bên trái: Thu phóng
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RemoteBtn(
                icon: Icons.add,
                onPressed: enabled ? () => _handleAction(widget.onScaleUp) : null,
              ),
              const SizedBox(height: 16),
              _RemoteBtn(
                icon: Icons.remove,
                onPressed: enabled ? () => _handleAction(widget.onScaleDown) : null,
              ),
            ],
          ),
          
          // Ở giữa: D-Pad
          SizedBox(
            width: 160,
            height: 160,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Positioned(
                  top: 0,
                  child: _RemoteBtn(
                    icon: Icons.keyboard_arrow_up,
                    onPressed: enabled ? () => _handleAction(widget.onMoveUp) : null,
                  ),
                ),
                Positioned(
                  bottom: 0,
                  child: _RemoteBtn(
                    icon: Icons.keyboard_arrow_down,
                    onPressed: enabled ? () => _handleAction(widget.onMoveDown) : null,
                  ),
                ),
                Positioned(
                  left: 0,
                  child: _RemoteBtn(
                    icon: Icons.keyboard_arrow_left,
                    onPressed: enabled ? () => _handleAction(widget.onMoveLeft) : null,
                  ),
                ),
                Positioned(
                  right: 0,
                  child: _RemoteBtn(
                    icon: Icons.keyboard_arrow_right,
                    onPressed: enabled ? () => _handleAction(widget.onMoveRight) : null,
                  ),
                ),
                _RemoteBtn(
                  icon: Icons.delete_outline_rounded,
                  color: const Color(0xFFFFEBEE),
                  iconColor: const Color(0xFFE53935),
                  onPressed: enabled ? widget.onRemove : null,
                ),
              ],
            ),
          ),

          // Bên phải: Xoay
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _RemoteBtn(
                icon: Icons.rotate_right,
                onPressed: enabled ? () => _handleAction(widget.onRotateRight) : null,
              ),
              const SizedBox(height: 16),
              _RemoteBtn(
                icon: Icons.rotate_left,
                onPressed: enabled ? () => _handleAction(widget.onRotateLeft) : null,
              ),
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
          backgroundColor: onPressed == null
              ? Colors.grey.shade100
              : color ?? const Color(0xFFFCE4EC),
          foregroundColor: onPressed == null
              ? Colors.grey.shade400
              : iconColor ?? const Color(0xFFE91E63),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: onPressed == null ? 0 : 1,
          shadowColor: Colors.black.withValues(alpha: 0.1),
        ),
        child: Icon(icon, size: 22),
      ),
    );
  }
}
