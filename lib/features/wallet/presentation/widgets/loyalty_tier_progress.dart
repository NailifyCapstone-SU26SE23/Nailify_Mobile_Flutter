import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

class LoyaltyTierProgress extends StatelessWidget {
  final double progress;
  final int? pointsToNext;
  final bool hasNextTier;
  final Color color;

  const LoyaltyTierProgress({
    super.key,
    required this.progress,
    required this.pointsToNext,
    required this.hasNextTier,
    this.color = AppColors.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            backgroundColor: color.withValues(alpha: 0.15),
            color: color,
            minHeight: 8,
          ),
        ),
      ],
    );
  }
}
