import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n_x.dart';
import '../../data/models/loyalty_tier_model.dart';

class LoyaltyRewardsCard extends StatelessWidget {
  final LoyaltyTierModel? tier;
  final int loyaltyPoints;
  final int lifetimePoints;
  final double progress;
  final int? pointsToNext;
  final bool hasNextTier;
  final int usableVoucherCount;
  final VoidCallback? onConvertPointsPressed;
  final VoidCallback onRedeemPressed;
  final VoidCallback onMyVouchersPressed;
  final VoidCallback onHistoryPressed;

  const LoyaltyRewardsCard({
    super.key,
    required this.tier,
    required this.loyaltyPoints,
    required this.lifetimePoints,
    required this.progress,
    required this.pointsToNext,
    required this.hasNextTier,
    required this.usableVoucherCount,
    this.onConvertPointsPressed,
    required this.onRedeemPressed,
    required this.onMyVouchersPressed,
    required this.onHistoryPressed,
  });

  @override
  Widget build(BuildContext context) {
    final baseColor = tier?.parsedBackgroundColor ?? AppColors.primary;
    final tierColor = baseColor == AppColors.primary
        ? const Color(0xFF6B46C1)
        : baseColor;
    final tierTextColor = tier?.parsedTextColor ?? Colors.white;

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            tierColor,
            Color.lerp(tierColor, Colors.black, 0.4) ?? tierColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: tierColor.withValues(alpha: 0.35),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.18),
          width: 1.5,
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(26),
        child: Stack(
          children: [
            // Decorative glow orb
            Positioned(
              right: -30,
              bottom: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.08),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // 1. Tier Header: Icon, Name, Lifetime points, Discount rate
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
                            const SizedBox(height: 2),
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
                  const SizedBox(height: 16),

                  // 2. Progress Track Section
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
                        height: 9,
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      FractionallySizedBox(
                        widthFactor: progress.clamp(0.05, 1.0),
                        child: Container(
                          height: 9,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFFFFD700), Colors.white],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(
                                  0xFFFFD700,
                                ).withValues(alpha: 0.6),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        hasNextTier && pointsToNext != null
                            ? context.l10n.walletPointsToNext(pointsToNext!)
                            : context.l10n.walletTierMax,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: tierTextColor.withValues(alpha: 0.85),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Divider(
                    color: Colors.white.withValues(alpha: 0.15),
                    height: 1,
                  ),
                  const SizedBox(height: 16),

                  // 3. Current Available Points & Voucher Count Row
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFD700).withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.stars_rounded,
                          size: 18,
                          color: Color(0xFFFFD700),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Điểm thưởng khả dụng',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: tierTextColor.withValues(alpha: 0.75),
                              ),
                            ),
                            Text(
                              '$loyaltyPoints điểm',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w900,
                                color: Color(0xFFFFD700),
                                height: 1.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (onConvertPointsPressed != null) ...[
                        InkWell(
                          onTap: onConvertPointsPressed,
                          borderRadius: BorderRadius.circular(12),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFD700).withValues(alpha: 0.22),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFFFFD700).withValues(alpha: 0.4),
                              ),
                            ),
                            child: const Row(
                              children: [
                                Icon(
                                  Icons.published_with_changes_rounded,
                                  size: 14,
                                  color: Color(0xFFFFD700),
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'Đổi từ ví',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFFFD700),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                      ],
                      InkWell(
                        onTap: onHistoryPressed,
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.18),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.history_rounded,
                                size: 14,
                                color: Colors.white,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                context.l10n.pointsHistoryTitle,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Voucher count chip
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.confirmation_number_rounded,
                          size: 14,
                          color: Color(0xFFFFD700),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          context.l10n.walletVoucherCount(usableVoucherCount),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: tierTextColor,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 18),

                  // 4. Quick Action Buttons: "Đổi điểm" & "Voucher của tôi"
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.card_giftcard_rounded,
                          label: context.l10n.walletRedeem,
                          gradientColors: [
                            const Color(0xFFFF66C4),
                            const Color(0xFFC44569),
                          ],
                          onTap: onRedeemPressed,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionTile(
                          icon: Icons.confirmation_number_outlined,
                          label: context.l10n.walletMyVouchers,
                          gradientColors: [
                            Colors.white.withValues(alpha: 0.25),
                            Colors.white.withValues(alpha: 0.12),
                          ],
                          onTap: onMyVouchersPressed,
                        ),
                      ),
                    ],
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
      width: 54,
      height: 54,
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
                  width: 44,
                  height: 44,
                  errorBuilder: (_, _, _) => const Icon(
                    Icons.workspace_premium_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                ),
              )
            : const Icon(
                Icons.workspace_premium_rounded,
                color: Colors.white,
                size: 28,
              ),
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String label,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 18),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
