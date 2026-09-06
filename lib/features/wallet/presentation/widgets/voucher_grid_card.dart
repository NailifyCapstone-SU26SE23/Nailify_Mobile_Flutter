import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n_x.dart';
import '../../data/models/redeemable_promotion_model.dart';

class VoucherGridCard extends StatelessWidget {
  final RedeemablePromotionModel promotion;
  final int userBalance;
  final bool canRedeem;
  final VoidCallback? onTap;

  const VoucherGridCard({
    super.key,
    required this.promotion,
    required this.userBalance,
    required this.canRedeem,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final points = promotion.pointsRequired;
    final enoughPoints = points == null || points <= userBalance;

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
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildImage(),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      promotion.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      promotion.discountLabel,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(child: _buildPointsBadge(context, points)),
                        if (promotion.remainingCount != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              context
                                  .l10n
                                  .walletVoucherRemaining(
                                      promotion.remainingCount!),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: onTap,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: canRedeem
                              ? AppColors.primary
                              : Colors.grey.shade300,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        child: Text(
                          _buttonLabel(context, canRedeem, enoughPoints),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
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
    final imageUrl = promotion.imageUrl;
    return AspectRatio(
      aspectRatio: 16 / 9,
      child: imageUrl != null && imageUrl.isNotEmpty
          ? Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                color: AppColors.primary.withValues(alpha: 0.08),
                child: const Center(
                  child: Icon(
                    Icons.card_giftcard_rounded,
                    color: AppColors.primary,
                    size: 40,
                  ),
                ),
              ),
            )
          : Container(
              color: AppColors.primary.withValues(alpha: 0.08),
              child: const Center(
                child: Icon(
                  Icons.card_giftcard_rounded,
                  color: AppColors.primary,
                  size: 40,
                ),
              ),
            ),
    );
  }

  Widget _buildPointsBadge(BuildContext context, int? points) {
    final hasPoints = points != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.stars_rounded,
            size: 12,
            color: AppColors.primary,
          ),
          const SizedBox(width: 2),
          Flexible(
            child: Text(
              hasPoints
                  ? context.l10n.pointsRequired(points)
                  : context.l10n.pointsRequiredTba,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _buttonLabel(
    BuildContext context,
    bool canRedeem,
    bool enoughPoints,
  ) {
    if (!canRedeem) return context.l10n.redeemSoldOut;
    if (!enoughPoints) return context.l10n.redeemInsufficientPoints;
    return context.l10n.voucherDetail;
  }
}
