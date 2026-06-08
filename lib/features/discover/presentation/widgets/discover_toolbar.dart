import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class DiscoverToolbar extends StatelessWidget {
  final int designCount;
  final bool isGridView;
  final VoidCallback onGridToggle;
  final VoidCallback onFilterPressed;

  const DiscoverToolbar({
    super.key,
    required this.designCount,
    required this.isGridView,
    required this.onGridToggle,
    required this.onFilterPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              children: [
                const TextSpan(text: 'Showing '),
                TextSpan(
                  text: '$designCount',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const TextSpan(text: ' matching nail designs'),
              ],
            ),
          ),
        ),
        _ToolbarIconButton(
          icon: Icons.grid_view,
          isActive: isGridView,
          onPressed: onGridToggle,
        ),
        const SizedBox(width: 8),
        _ToolbarIconButton(
          icon: Icons.menu,
          isActive: false,
          onPressed: onFilterPressed,
          outlined: true,
        ),
      ],
    );
  }
}

class _ToolbarIconButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final bool outlined;
  final VoidCallback onPressed;

  const _ToolbarIconButton({
    required this.icon,
    required this.isActive,
    required this.onPressed,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isActive && !outlined ? AppColors.bannerGradient : null,
            color: outlined ? Colors.white : (isActive ? null : AppColors.surfaceLight),
            border: outlined ? Border.all(color: AppColors.borderLight) : null,
          ),
          child: Icon(
            icon,
            size: 20,
            color: isActive && !outlined ? Colors.white : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
