import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  List<Color> _getTierGradient(LoyaltyTierModel? tier) {
    // 1. Ưu tiên lấy dải màu trực tiếp từ API nếu backend có trả về backgroundColor
    final apiColor = tier?.parsedBackgroundColor;
    if (apiColor != null && apiColor != Colors.transparent) {
      final darker = Color.lerp(apiColor, Colors.black, 0.35) ?? apiColor;
      final deepest = Color.lerp(darker, Colors.black, 0.3) ?? darker;
      return [apiColor, darker, deepest];
    }

    final tierNameLower = (tier?.name ?? '').toLowerCase();

    // 2. ĐỒNG (Bronze)
    if (tierNameLower.contains('đồng') ||
        tierNameLower.contains('dong') ||
        tierNameLower.contains('bronz')) {
      return const [
        Color(0xFFA77044),
        Color(0xFF7B4A26),
        Color(0xFF4A2B12),
      ];
    }

    // 3. BẠC (Silver)
    if (tierNameLower.contains('bạc') ||
        tierNameLower.contains('bac') ||
        tierNameLower.contains('silv')) {
      return const [
        Color(0xFFB0B0B0),
        Color(0xFF757575),
        Color(0xFF424242),
      ];
    }

    // 4. VÀNG (Gold)
    if (tierNameLower.contains('vàng') ||
        tierNameLower.contains('vang') ||
        tierNameLower.contains('gold')) {
      return const [
        Color(0xFFFFD700),
        Color(0xFFC59B27),
        Color(0xFF7A5C07),
      ];
    }

    // 5. KIM CƯƠNG (Diamond)
    if (tierNameLower.contains('kim') || tierNameLower.contains('diamond')) {
      return const [
        Color(0xFFB9E3DE),
        Color(0xFF5C8D89),
        Color(0xFF284845),
      ];
    }

    // Default fallback to Silver metallic
    return const [
      Color(0xFFB0B0B0),
      Color(0xFF757575),
      Color(0xFF424242),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final gradientColors = _getTierGradient(tier);
    final primaryColor = gradientColors[1];
    final tierTextColor = tier?.parsedTextColor ?? Colors.white;

    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push('/profile/wallet'),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withValues(alpha: 0.3),
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
                              context.l10n.walletVoucherCount(voucherCount),
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
              Icon(Icons.chevron_right_rounded, color: tierTextColor, size: 28),
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
