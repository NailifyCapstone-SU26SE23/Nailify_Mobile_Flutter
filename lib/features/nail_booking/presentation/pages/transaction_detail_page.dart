import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../generated/l10n.dart';
import '../utils/transaction_status_utils.dart';

class TransactionDetailPage extends StatelessWidget {
  final Map<String, dynamic> transaction;

  const TransactionDetailPage({super.key, required this.transaction});

  @override
  Widget build(BuildContext context) {
    final status = transaction['status']?.toString() ?? '';
    final statusView = transactionStatusView(status);
    final amount = transaction['amount'] ?? 0;
    final policy = transaction['policy']?.toString().trim() ?? '';

    final rawDesc = transaction['orderCode'] ?? transaction['description'];
    final cleanDesc = formatTransactionDescription(rawDesc);
    final isPureNumber = RegExp(r'^\d+$').hasMatch(cleanDesc);

    final customerName = transaction['customerName']?.toString().trim() ?? '';
    final salonName = transaction['salonName']?.toString().trim() ?? '';
    final createdAtStr = _formatDateTime(transaction['createdAt']);
    final paidAtStr = _formatDateTime(transaction['paidAt']);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: const Color(0xFFF1F5F9),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        title: Text(
          S.of(context).transactionDetails,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Header Card (Status & Amount) ─────────────────────
              _buildHeroHeader(statusView, amount),
              const SizedBox(height: 16),

              // ── Details Card ─────────────────────────────────────
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: const [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 18,
                          color: AppColors.primaryDark,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Thông tin chi tiết',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    const SizedBox(height: 12),

                    if (cleanDesc.isNotEmpty)
                      _buildDetailRow(
                        icon: isPureNumber
                            ? Icons.confirmation_number_rounded
                            : Icons.swap_horiz_rounded,
                        label: isPureNumber ? 'Mã đơn hàng' : 'Loại giao dịch',
                        value: isPureNumber ? '#$cleanDesc' : cleanDesc,
                      ),
                    if (customerName.isNotEmpty)
                      _buildDetailRow(
                        icon: Icons.person_outline_rounded,
                        label: 'Khách hàng',
                        value: customerName,
                      ),
                    if (salonName.isNotEmpty)
                      _buildDetailRow(
                        icon: Icons.storefront_rounded,
                        label: 'Cửa hàng / Kênh',
                        value: salonName,
                      ),
                    if (createdAtStr.isNotEmpty)
                      _buildDetailRow(
                        icon: Icons.schedule_rounded,
                        label: 'Thời gian khởi tạo',
                        value: createdAtStr,
                      ),
                    if (paidAtStr.isNotEmpty)
                      _buildDetailRow(
                        icon: Icons.task_alt_rounded,
                        label: 'Thời gian thanh toán',
                        value: paidAtStr,
                        isLast: true,
                      ),
                  ],
                ),
              ),

              // ── Policy Banner (if present) ────────────────────────
              if (policy.isNotEmpty) ...[
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFFBEB),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFDE68A)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.info_outline_rounded,
                        size: 20,
                        color: Color(0xFFD97706),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          policy,
                          style: const TextStyle(
                            color: Color(0xFF92400E),
                            fontSize: 13,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(TransactionStatusView statusView, dynamic amount) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: statusView.color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(
              statusView.icon,
              color: statusView.color,
              size: 28,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: statusView.color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: statusView.color.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              statusView.label,
              style: TextStyle(
                color: statusView.color,
                fontSize: 13.5,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            PriceFormatter.format(amount ?? 0),
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
              color: AppColors.primaryDark,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: AppColors.primaryDark),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: Color(0xFF64748B),
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFF1F5F9)),
          ),
      ],
    );
  }

  String _formatDateTime(dynamic value) {
    if (value == null) return '';
    final str = value.toString().trim();
    if (str.isEmpty) return '';
    final date = DateTime.tryParse(str)?.toLocal();
    if (date == null) return str;
    final day = date.day.toString().padLeft(2, '0');
    final month = date.month.toString().padLeft(2, '0');
    final year = date.year;
    final hour = date.hour.toString().padLeft(2, '0');
    final minute = date.minute.toString().padLeft(2, '0');
    final second = date.second.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute:$second';
  }
}
