import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n_x.dart';
import '../../data/models/wallet_voucher_model.dart';

class VoucherDetailPage extends StatelessWidget {
  final int userVoucherUsageId;
  final WalletVoucherModel? voucher;

  const VoucherDetailPage({
    super.key,
    required this.userVoucherUsageId,
    this.voucher,
  });

  @override
  Widget build(BuildContext context) {
    final v = voucher;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.l10n.voucherDetailTitle,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: v == null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Voucher #$userVoucherUsageId',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            )
          : _buildContent(context, v),
      bottomNavigationBar: v != null && v.isUsableNow
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      // Tạm thời điều hướng tới booking list.
                      context.push('/my-bookings');
                    },
                    icon: const Icon(Icons.shopping_bag_rounded, size: 18),
                    label: Text(
                      context.l10n.voucherUseNow,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildContent(BuildContext context, WalletVoucherModel v) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHero(v),
          const SizedBox(height: 16),
          Text(
            v.promotionName,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w900,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            v.discountLabel,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          _section(
            context,
            title: context.l10n.voucherStatusUsable,
            child: Text(
              _statusText(context, v),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          if (v.description != null && v.description!.isNotEmpty)
            _section(
              context,
              title: context.l10n.voucherDescription,
              child: Text(
                v.description!,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textPrimary,
                  height: 1.45,
                ),
              ),
            ),
          _section(
            context,
            title: context.l10n.voucherValidity,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (v.startDate != null)
                  Text(
                    '${context.l10n.voucherValidity}: ${_fmt(v.startDate!)}',
                    style: const TextStyle(fontSize: 13),
                  ),
                if (v.endDate != null)
                  Text(
                    context.l10n.expiredOn(_fmt(v.endDate!)),
                    style: const TextStyle(fontSize: 13),
                  ),
              ],
            ),
          ),
          _section(
            context,
            title: context.l10n.walletVoucherRemaining(v.receivedCount),
            child: Text(
              context.l10n.walletVoucherUsedCount(
                v.usageCount,
                v.receivedCount,
              ),
              style: const TextStyle(fontSize: 13),
            ),
          ),
          _section(
            context,
            title: context.l10n.voucherConditions,
            child: Text(
              context.l10n.redeemConfirmTerms,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero(WalletVoucherModel v) {
    final url = v.imageUrl;
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: url != null && url.isNotEmpty
            ? Image.network(
                url,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  child: const Center(
                    child: Icon(
                      Icons.local_offer_rounded,
                      color: AppColors.primary,
                      size: 64,
                    ),
                  ),
                ),
              )
            : Container(
                color: AppColors.primary.withValues(alpha: 0.08),
                child: const Center(
                  child: Icon(
                    Icons.local_offer_rounded,
                    color: AppColors.primary,
                    size: 64,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _section(
    BuildContext context, {
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          child,
        ],
      ),
    );
  }

  String _statusText(BuildContext context, WalletVoucherModel v) {
    switch (v.status) {
      case VoucherStatus.usable:
        return context.l10n.voucherStatusUsable;
      case VoucherStatus.used:
        return context.l10n.voucherStatusUsed;
      case VoucherStatus.expired:
        return context.l10n.voucherStatusExpired;
      case VoucherStatus.upcoming:
        return context.l10n.voucherStatusUpcoming;
    }
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}
