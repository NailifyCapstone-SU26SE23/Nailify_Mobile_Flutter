import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n_x.dart';
import '../../data/models/loyalty_tier_model.dart';

class WalletEntryCard extends StatelessWidget {
  final int lifetimePoints;
  final int loyaltyPoints;
  final int voucherCount;
  final String? tierName;
  final String? tierImageUrl;
  final LoyaltyTierModel? tier;

  const WalletEntryCard({
    super.key,
    required this.lifetimePoints,
    required this.loyaltyPoints,
    required this.voucherCount,
    this.tierName,
    this.tierImageUrl,
    this.tier,
  });

  @override
  Widget build(BuildContext context) {
    final tierColor = tier?.parsedBackgroundColor ?? AppColors.primary;
    final tierTextColor = tier?.parsedTextColor ?? Colors.white;

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/profile/wallet'),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                tierColor,
                Color.lerp(tierColor, Colors.white, 0.55) ?? tierColor,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: tierColor.withValues(alpha: 0.25),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Row(
            children: [
              _buildTierIcon(tierTextColor),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.walletTitle,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: tierTextColor,
                            ),
                          ),
                        ),
                        if (voucherCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              context
                                  .l10n
                                  .walletVoucherCount(voucherCount),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: tierTextColor,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      context.l10n.walletEntrySubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: tierTextColor.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _buildStat(
                          icon: Icons.stars_rounded,
                          label: context.l10n.walletLifetimePoints,
                          value: '$lifetimePoints',
                          color: tierTextColor,
                        ),
                        const SizedBox(width: 12),
                        if (tierName != null && tierName!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.25),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 14,
                                  color: tierTextColor,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  tierName!,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: tierTextColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: tierTextColor,
                size: 28,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTierIcon(Color textColor) {
    if (tierImageUrl != null && tierImageUrl!.isNotEmpty) {
      return Container(
        width: 56,
        height: 56,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.25),
          shape: BoxShape.circle,
        ),
        child: ClipOval(
          child: Image.network(
            tierImageUrl!,
            fit: BoxFit.contain,
            errorBuilder: (_, _, _) => Icon(
              Icons.workspace_premium_rounded,
              color: textColor,
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
        color: Colors.white.withValues(alpha: 0.25),
        shape: BoxShape.circle,
      ),
      child: Icon(
        Icons.account_balance_wallet_rounded,
        color: textColor,
        size: 28,
      ),
    );
  }

  Widget _buildStat({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 10,
                      color: color.withValues(alpha: 0.85),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
