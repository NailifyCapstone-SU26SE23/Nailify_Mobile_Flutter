import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';

class BookingSuccessPage extends StatelessWidget {
  final Map<String, dynamic> bookingDetails;

  const BookingSuccessPage({super.key, required this.bookingDetails});

  @override
  Widget build(BuildContext context) {
    final date = bookingDetails['date'] as DateTime?;
    final dateString =
        date != null ? '${date.day}/${date.month}/${date.year}' : '';
    final bookingId = bookingDetails['bookingId']?.toString();
    final discounts = _discounts;
    final hasPrice = bookingDetails['totalPrice'] != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minHeight =
                constraints.maxHeight > 48 ? constraints.maxHeight - 48 : 0.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 100),
              const SizedBox(height: 24),
              const Text(
                'Đặt lịch thành công!',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cảm ơn bạn đã tin tưởng Nailify. Dưới đây là thông tin chi tiết lịch hẹn của bạn.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildInfoRow(
                      Icons.spa,
                      'Dịch vụ',
                      bookingDetails['serviceName']?.toString() ?? '',
                    ),
                    const Divider(height: 24, color: AppColors.borderLight),
                    _buildInfoRow(Icons.calendar_month, 'Ngày hẹn', dateString),
                    const Divider(height: 24, color: AppColors.borderLight),
                    _buildInfoRow(
                      Icons.access_time,
                      'Thời gian',
                      bookingDetails['time']?.toString().substring(0, 5) ?? '',
                    ),
                    const Divider(height: 24, color: AppColors.borderLight),
                    _buildInfoRow(
                      Icons.face_2,
                      'Nhân viên',
                      bookingDetails['stylistName']?.toString() ?? '',
                    ),
                    if (discounts.isNotEmpty || hasPrice) ...[
                      const Divider(height: 24, color: AppColors.borderLight),
                      if (bookingDetails['price'] != null)
                        _buildAmountRow('Giá gốc', bookingDetails['price']),
                      ...discounts.map(_buildDiscountRow),
                      _buildAmountRow(
                        'Tổng thanh toán',
                        bookingDetails['totalPrice'],
                        isTotal: true,
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 40),
              ElevatedButton(
                onPressed: bookingId == null || bookingId.isEmpty
                    ? null
                    : () => context.go('/my-bookings/detail', extra: bookingId),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'View Booking',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton(
                onPressed: () => context.go('/'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Back to Home',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
                  ],
                ),
              ),
            );
          },
          ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(color: Colors.grey, fontSize: 12),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> get _discounts {
    final raw = bookingDetails['discounts'] ?? bookingDetails['discountBreakdown'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((discount) => Map<String, dynamic>.from(discount))
        .toList();
  }

  Widget _buildAmountRow(String label, dynamic amount, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: isTotal ? AppColors.textPrimary : Colors.grey,
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            PriceFormatter.format(amount ?? 0),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isTotal ? AppColors.primary : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountRow(Map<String, dynamic> discount) {
    final name = discount['name']?.toString() ?? 'Giảm giá';
    final amountDisplay = discount['amountDisplay']?.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(color: Colors.green, fontSize: 14),
            ),
          ),
          Text(
            amountDisplay?.isNotEmpty == true
                ? amountDisplay!
                : PriceFormatter.format(-(discount['amount'] ?? 0)),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ],
      ),
    );
  }
}
