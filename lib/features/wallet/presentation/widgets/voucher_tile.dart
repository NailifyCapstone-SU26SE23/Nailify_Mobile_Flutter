import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n_x.dart';
import '../../data/models/wallet_voucher_model.dart';

class VoucherTile extends StatelessWidget {
  final WalletVoucherModel voucher;
  final VoidCallback? onTap;
  final bool showCountdown;

  const VoucherTile({
    super.key,
    required this.voucher,
    this.onTap,
    this.showCountdown = true,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.shade100),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            voucher.promotionName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        _buildStatusChip(context),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      voucher.discountLabel,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (voucher.description != null &&
                        voucher.description!.isNotEmpty)
                      Text(
                        voucher.description!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        if (voucher.remainingCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              context.l10n.walletVoucherRemaining(
                                voucher.remainingCount,
                              ),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        if (voucher.remainingCount > 0)
                          const SizedBox(width: 6),
                        if (voucher.endDate != null)
                          Text(
                            context.l10n.expiredOn(
                              _formatDate(voucher.endDate!),
                            ),
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        const Spacer(),
                        if (showCountdown && _shouldShowCountdown())
                          _buildCountdownBadge(context),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildImage() {
    final imageUrl = voucher.imageUrl;
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: imageUrl != null && imageUrl.isNotEmpty
          ? ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const Icon(
                  Icons.local_offer_rounded,
                  color: AppColors.primary,
                ),
              ),
            )
          : const Icon(Icons.local_offer_rounded, color: AppColors.primary),
    );
  }

  Widget _buildStatusChip(BuildContext context) {
    final status = voucher.status;
    Color bg;
    Color fg;
    String text;
    switch (status) {
      case VoucherStatus.usable:
        bg = Colors.green.withValues(alpha: 0.12);
        fg = Colors.green.shade700;
        text = context.l10n.voucherStatusUsable;
        break;
      case VoucherStatus.used:
        bg = Colors.grey.withValues(alpha: 0.18);
        fg = Colors.grey.shade700;
        text = context.l10n.voucherStatusUsed;
        break;
      case VoucherStatus.expired:
        bg = Colors.red.withValues(alpha: 0.12);
        fg = Colors.red.shade700;
        text = context.l10n.voucherStatusExpired;
        break;
      case VoucherStatus.upcoming:
        bg = Colors.blue.withValues(alpha: 0.12);
        fg = Colors.blue.shade700;
        text = context.l10n.voucherStatusUpcoming;
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        text,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }

  Widget _buildCountdownBadge(BuildContext context) {
    final text = voucher.countdownLabel;
    if (text == null) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        context.l10n.expiringIn(text),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w800,
          color: Colors.orange.shade800,
        ),
      ),
    );
  }

  bool _shouldShowCountdown() {
    final days = voucher.daysUntilExpiry;
    if (days == null) return false;
    return days >= 0 && days <= 7;
  }

  String _formatDate(DateTime d) {
    return '${d.day.toString().padLeft(2, '0')}/'
        '${d.month.toString().padLeft(2, '0')}/'
        '${d.year}';
  }
}
