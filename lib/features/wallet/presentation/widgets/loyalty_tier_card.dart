import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n_x.dart';
import '../../data/models/loyalty_tier_model.dart';

class LoyaltyTierCard extends StatelessWidget {
  final LoyaltyTierModel? tier;
  final int lifetimePoints;
  final double progress;
  final int? pointsToNext;
  final bool hasNextTier;

  const LoyaltyTierCard({
    super.key,
    required this.tier,
    required this.lifetimePoints,
    required this.progress,
    required this.pointsToNext,
    required this.hasNextTier,
  });

  @override
  Widget build(BuildContext context) {
    final tierColor = tier?.parsedBackgroundColor ?? AppColors.primary;
    final tierTextColor = tier?.parsedTextColor ?? Colors.white;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tierColor,
            Color.lerp(tierColor, Colors.black, 0.15) ?? tierColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: tierColor.withValues(alpha: 0.3),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _buildTierIcon(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tier?.name ?? context.l10n.walletTierNone,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: tierTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${context.l10n.walletLifetimePoints}: $lifetimePoints',
                      style: TextStyle(
                        fontSize: 12,
                        color: tierTextColor.withValues(alpha: 0.85),
                      ),
                    ),
                  ],
                ),
              ),
              if ((tier?.discountRate ?? 0) > 0)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    tier!.discountLabel,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: tierTextColor,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.walletTierProgress,
            style: TextStyle(
              fontSize: 12,
              color: tierTextColor.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: Colors.white.withValues(alpha: 0.2),
              color: tierTextColor,
              minHeight: 8,
            ),
          ),
          const SizedBox(height: 6),
          if (hasNextTier && pointsToNext != null)
            Text(
              context.l10n.walletPointsToNext(pointsToNext!),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tierTextColor,
              ),
            )
          else
            Text(
              context.l10n.walletTierMax,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: tierTextColor,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildTierIcon() {
    if (tier?.imageUrl != null && tier!.imageUrl!.isNotEmpty) {
      return Container(
        width: 56,
        height: 56,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.network(
            tier!.imageUrl!,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => const Icon(
              Icons.workspace_premium_rounded,
              color: Colors.white,
              size: 28,
            ),
          ),
        ),
      );
    }
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.3),
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.workspace_premium_rounded,
        color: Colors.white,
        size: 28,
      ),
    );
  }
}
