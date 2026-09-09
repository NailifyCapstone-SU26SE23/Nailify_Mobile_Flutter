import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n_x.dart';
import '../../data/models/loyalty_transaction_model.dart';

/// Một dòng trong danh sách lịch sử điểm.
///
/// - `points > 0`  → chip xanh "Cộng +N điểm"
/// - `points < 0`  → chip cam "Trừ -N điểm"
/// - `points == 0` → hiển thị "0 điểm"
class LoyaltyTransactionTile extends StatelessWidget {
  final LoyaltyTransactionModel transaction;

  const LoyaltyTransactionTile({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final isCredit = transaction.isCredit;
    final isDebit = transaction.isDebit;
    final color = isCredit
        ? Colors.green.shade600
        : isDebit
        ? Colors.deepOrange.shade600
        : Colors.grey.shade600;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _buildIcon(isCredit, isDebit),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.typeLabelVi,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(transaction.createdAt),
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                ),
                if (transaction.bookingId != null &&
                    transaction.bookingId!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    context.l10n.pointsHistoryBookingRef(
                      transaction.bookingId!.substring(
                        0,
                        transaction.bookingId!.length.clamp(0, 8),
                      ),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _formatPoints(transaction.points),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.pointsShort,
                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIcon(bool isCredit, bool isDebit) {
    final IconData icon;
    final Color bg;
    final Color fg;
    if (isCredit) {
      icon = Icons.add_circle_rounded;
      bg = Colors.green.shade50;
      fg = Colors.green.shade600;
    } else if (isDebit) {
      icon = Icons.remove_circle_rounded;
      bg = Colors.deepOrange.shade50;
      fg = Colors.deepOrange.shade600;
    } else {
      icon = Icons.info_outline_rounded;
      bg = Colors.grey.shade100;
      fg = Colors.grey.shade600;
    }
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
      child: Icon(icon, color: fg, size: 22),
    );
  }

  String _formatPoints(int points) {
    if (points == 0) return '0';
    final sign = points > 0 ? '+' : '-';
    return '$sign${points.abs()}';
  }

  String _formatDate(DateTime dt) {
    final local = dt.toLocal();
    return '${_two(local.day)}/${_two(local.month)}/${local.year} '
        '${_two(local.hour)}:${_two(local.minute)}';
  }

  String _two(int n) => n.toString().padLeft(2, '0');
}
