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
    final baseColor = tier?.parsedBackgroundColor ?? AppColors.primary;
    final tierColor = baseColor == AppColors.primary ? const Color(0xFF7C3AED) : baseColor;
    final tierTextColor = tier?.parsedTextColor ?? Colors.white;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tierColor,
            Color.lerp(tierColor, Colors.black, 0.35) ?? tierColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: tierColor.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.15),
          width: 1.2,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            // Decorative background circle glow
            Positioned(
              right: -25,
              bottom: -25,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      _buildTierIcon(tierColor),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              tier?.name ?? context.l10n.walletTierNone,
                              style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                                color: tierTextColor,
                                letterSpacing: -0.3,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              '${context.l10n.walletLifetimePoints}: $lifetimePoints',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w500,
                                color: tierTextColor.withValues(alpha: 0.85),
                              ),
                            ),
                          ],
                        ),
                      ),
                      if ((tier?.discountRate ?? 0) > 0)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.22),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.3),
                            ),
                          ),
                          child: Text(
                            tier!.discountLabel,
                            style: TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w900,
                              color: tierTextColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        context.l10n.walletTierProgress,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: tierTextColor.withValues(alpha: 0.85),
                        ),
                      ),
                      Text(
                        '${(progress.clamp(0.0, 1.0) * 100).toInt()}%',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: tierTextColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Stack(
                    children: [
                      Container(
                        height: 10,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress.clamp(0.05, 1.0),
                        child: Container(
                          height: 10,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.white70, Colors.white],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withValues(alpha: 0.5),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (hasNextTier && pointsToNext != null)
                    Text(
                      context.l10n.walletPointsToNext(pointsToNext!),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: tierTextColor.withValues(alpha: 0.9),
                      ),
                    )
                  else
                    Text(
                      context.l10n.walletTierMax,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: tierTextColor,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTierIcon(Color tierColor) {
    return Container(
      width: 58,
      height: 58,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.4),
          width: 1.5,
        ),
      ),
      child: Center(
        child: tier?.imageUrl != null && tier!.imageUrl!.isNotEmpty
            ? ClipOval(
                child: Image.network(
                  tier!.imageUrl!,
                  fit: BoxFit.cover,
                  width: 46,
                  height: 46,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              )
            : const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 30,
              ),
      ),
    );
  }
}

