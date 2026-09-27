import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n_x.dart';
import '../../data/models/redeem_result_model.dart';

/// Bottom sheet xác nhận redeem voucher.
/// Tự xử lý loading state, hiển thị success và error inline.
/// Trả về `RedeemResultModel` qua Navigator.pop nếu thành công.
class ConfirmRedeemSheet extends StatefulWidget {
  final String voucherName;
  final int pointsRequired;
  final int userBalance;
  final Future<RedeemResultModel?> Function() onConfirm;

  const ConfirmRedeemSheet({
    super.key,
    required this.voucherName,
    required this.pointsRequired,
    required this.userBalance,
    required this.onConfirm,
  });

  @override
  State<ConfirmRedeemSheet> createState() => _ConfirmRedeemSheetState();
}

class _ConfirmRedeemSheetState extends State<ConfirmRedeemSheet> {
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _submit() async {
    if (_isSubmitting) return;
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    try {
      final result = await widget.onConfirm();
      if (!mounted) return;
      if (result != null) {
        Navigator.of(context).pop(result);
      } else {
        setState(() {
          _isSubmitting = false;
          _errorMessage = context.l10n.redeemFailed;
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSubmitting = false;
        _errorMessage = _humanizeError(e);
      });
    }
  }

  String _humanizeError(Object e) {
    final raw = e.toString().toLowerCase();
    if (raw.contains('insufficient') ||
        raw.contains('not enough') ||
        raw.contains('points') ||
        raw.contains('400')) {
      return context.l10n.redeemInsufficientPoints;
    }
    if (raw.contains('sold out') || raw.contains('usage limit')) {
      return context.l10n.redeemSoldOut;
    }
    return context.l10n.redeemFailed;
  }

  @override
  Widget build(BuildContext context) {
    final remaining = (widget.userBalance - widget.pointsRequired).clamp(
      0,
      1 << 30,
    );
    final canAfford = widget.userBalance >= widget.pointsRequired;
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
                          context.l10n.redeemConfirmTitle,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.voucherName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  children: [
                    _row(
                      label: context.l10n.walletRedeem,
                      value: context.l10n.pointsRequired(widget.pointsRequired),
                      highlight: true,
                    ),
                    const Divider(height: 16),
                    _row(
                      label: context.l10n.walletBalance,
                      value: context.l10n.pointsRequired(widget.userBalance),
                    ),
                    const SizedBox(height: 6),
                    _row(
                      label: context.l10n.balanceHint(remaining),
                      value: context.l10n.pointsRequired(widget.pointsRequired),
                      dim: true,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Text(
                context.l10n.redeemConfirmTerms,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                  height: 1.4,
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isSubmitting
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
                      onPressed: (!_isSubmitting && canAfford) ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: canAfford
                            ? AppColors.primary
                            : Colors.grey.shade300,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Text(
                              context.l10n.redeemConfirmCta,
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

  Widget _row({
    required String label,
    required String value,
    bool highlight = false,
    bool dim = false,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
              color: dim ? Colors.grey.shade700 : AppColors.textPrimary,
            ),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: highlight ? 16 : 13,
            fontWeight: FontWeight.w800,
            color: highlight ? AppColors.primary : AppColors.textPrimary,
          ),
        ),
      ],
    );
  }
}
