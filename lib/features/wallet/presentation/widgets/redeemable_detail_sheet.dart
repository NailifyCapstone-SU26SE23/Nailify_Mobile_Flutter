import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n_x.dart';
import '../../data/models/redeemable_promotion_model.dart';

/// Bottom sheet hiển thị chi tiết voucher redeemable (không kèm ảnh).
/// Cho phép bấm "Đổi điểm" để gọi redeem API trực tiếp trong sheet.
/// Trả về kết quả qua `Navigator.pop`:
///  - `String` (message success/error) nếu user đổi điểm xong
///  - `null` nếu user đóng sheet
class RedeemableDetailSheet extends StatefulWidget {
  final RedeemablePromotionModel promotion;
  final int userBalance;
  final bool canRedeem;

  const RedeemableDetailSheet({
    super.key,
    required this.promotion,
    required this.userBalance,
    required this.canRedeem,
  });

  @override
  State<RedeemableDetailSheet> createState() => RedeemableDetailSheetState();
}

class RedeemableDetailSheetState extends State<RedeemableDetailSheet> {
  bool _isRedeeming = false;
  String? _inlineError;
  String? _successMessage;

  /// Parent gọi sau khi API redeem thành công để hiển thị success + auto-pop.
  void showSuccess(String message) {
    if (!mounted) return;
    setState(() {
      _successMessage = message;
      _isRedeeming = false;
    });
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) {
        Navigator.of(context).pop(message);
      }
    });
  }

  /// Parent gọi khi API redeem lỗi để hiển thị inline error.
  void showError(String message) {
    if (!mounted) return;
    setState(() {
      _inlineError = message;
      _isRedeeming = false;
    });
  }

  Future<void> _onRedeemPressed() async {
    if (_isRedeeming) return;
    // Tự pop ra kết quả "redeemRequested" để parent xử lý.
    Navigator.of(context).pop('__redeem__');
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.promotion;
    final points = p.pointsRequired;
    final enoughPoints = points == null || points <= widget.userBalance;
    final canDo =
        widget.canRedeem && enoughPoints && _successMessage == null;

    final inset = MediaQuery.of(context).viewInsets;

    return Padding(
      padding: EdgeInsets.only(bottom: inset.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.card_giftcard_rounded,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          context.l10n.voucherDetailTitle,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          p.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              _section(
                title: context.l10n.voucherConditions,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        p.discountLabel,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: PointsInline(points: points),
                    ),
                  ],
                ),
              ),
              if (p.description != null && p.description!.isNotEmpty)
                _section(
                  title: context.l10n.voucherDescription,
                  child: Text(
                    p.description!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              _section(
                title: context.l10n.voucherValidity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (p.startDate != null)
                      _dateRow(
                        label: 'Bắt đầu',
                        date: p.startDate!,
                      ),
                    if (p.endDate != null)
                      _dateRow(
                        label: 'Hết hạn',
                        date: p.endDate!,
                      ),
                    if (p.remainingCount != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          context.l10n.walletVoucherRemaining(p.remainingCount!),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                    if (p.userLimit != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Mỗi người dùng tối đa ${p.userLimit} lượt đổi',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              if (_inlineError != null) ...[
                const SizedBox(height: 8),
                _banner(
                  message: _inlineError!,
                  color: Colors.red,
                  icon: Icons.error_outline_rounded,
                ),
              ],
              if (_successMessage != null) ...[
                const SizedBox(height: 8),
                _banner(
                  message: _successMessage!,
                  color: Colors.green,
                  icon: Icons.check_circle_outline_rounded,
                ),
              ],
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isRedeeming
                          ? null
                          : () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        context.l10n.redeemConfirmCancel,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: (canDo && !_isRedeeming)
                          ? _onRedeemPressed
                          : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canDo
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        context.l10n.walletRedeem,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _section({required String title, required Widget child}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
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

  Widget _dateRow({required String label, required DateTime date}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        '$label: ${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year}',
        style: const TextStyle(fontSize: 12),
      ),
    );
  }

  Widget _banner({
    required String message,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Hiển thị badge điểm inline (compact).
class PointsInline extends StatelessWidget {
  final int? points;
  const PointsInline({super.key, required this.points});

  @override
  Widget build(BuildContext context) {
    final hasPoints = points != null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.stars_rounded,
            size: 14,
            color: AppColors.primary,
          ),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              hasPoints
                  ? context.l10n.pointsRequired(points!)
                  : context.l10n.pointsRequiredTba,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
