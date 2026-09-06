import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n_x.dart';

class WalletBalanceCard extends StatelessWidget {
  final int loyaltyPoints;
  final int usableVoucherCount;
  final VoidCallback? onRedeemPressed;
  final VoidCallback? onMyVouchersPressed;

  const WalletBalanceCard({
    super.key,
    required this.loyaltyPoints,
    required this.usableVoucherCount,
    this.onRedeemPressed,
    this.onMyVouchersPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.walletBalance,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$loyaltyPoints',
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  color: AppColors.textPrimary,
                  height: 1,
                ),
              ),
              const SizedBox(width: 6),
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  context.l10n.pointsShort,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.confirmation_number_rounded,
                size: 16,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Text(
                context.l10n.walletVoucherCount(usableVoucherCount),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            context.l10n.walletQuickActions,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _buildAction(
                  context: context,
                  icon: Icons.card_giftcard_rounded,
                  label: context.l10n.walletRedeem,
                  color: AppColors.primary,
                  background: AppColors.primary.withValues(alpha: 0.12),
                  onTap: onRedeemPressed ??
                      () => context.push('/profile/wallet/redeem'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildAction(
                  context: context,
                  icon: Icons.confirmation_number_outlined,
                  label: context.l10n.walletMyVouchers,
                  color: AppColors.primaryDark,
                  background: AppColors.primaryDark.withValues(alpha: 0.12),
                  onTap: onMyVouchersPressed ??
                      () => context.push('/profile/wallet/vouchers'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAction({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required Color background,
    required VoidCallback onTap,
  }) {
    return Material(
      color: background,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Column(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
