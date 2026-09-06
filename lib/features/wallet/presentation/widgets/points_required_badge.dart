import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n_x.dart';

class PointsRequiredBadge extends StatelessWidget {
  final int? pointsRequired;
  final double size;

  const PointsRequiredBadge({
    super.key,
    required this.pointsRequired,
    this.size = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    final hasPoints = pointsRequired != null;
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 8 * size,
        vertical: 4 * size,
      ),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8 * size),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.stars_rounded,
            size: 12 * size,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Text(
            hasPoints
                ? context.l10n.pointsRequired(pointsRequired!)
                : context.l10n.pointsRequiredTba,
            style: TextStyle(
              fontSize: 11 * size,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}
