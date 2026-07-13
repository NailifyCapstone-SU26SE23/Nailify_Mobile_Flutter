import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';

class PaymentSuccessPage extends StatelessWidget {
  final Map<String, dynamic> paymentData;

  const PaymentSuccessPage({super.key, required this.paymentData});

  @override
  Widget build(BuildContext context) {
    return _PaymentResultView(
      icon: Icons.check_circle,
      iconColor: Colors.green,
      title: 'Thanh toán thành công',
      message: 'Giao dịch đã được xác nhận. Cảm ơn bạn đã thanh toán.',
      bookingId: paymentData['bookingId']?.toString() ?? '',
      primaryLabel: 'Xem lịch hẹn',
      onPrimaryPressed: () {
        final bookingId = paymentData['bookingId']?.toString() ?? '';
        context.go('/my-bookings/detail', extra: bookingId);
      },
    );
  }
}

class PaymentCancelledPage extends StatelessWidget {
  final Map<String, dynamic> paymentData;

  const PaymentCancelledPage({super.key, required this.paymentData});

  @override
  Widget build(BuildContext context) {
    return _PaymentResultView(
      icon: Icons.cancel,
      iconColor: Colors.red,
      title: 'Thanh toán đã bị hủy',
      message: 'Giao dịch thanh toán không hoàn tất hoặc đã bị hủy.',
      bookingId: paymentData['bookingId']?.toString() ?? '',
      primaryLabel: 'Về trang chủ',
      onPrimaryPressed: () => context.go('/'),
    );
  }
}

class _PaymentResultView extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String bookingId;
  final String primaryLabel;
  final VoidCallback onPrimaryPressed;

  const _PaymentResultView({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.bookingId,
    required this.primaryLabel,
    required this.onPrimaryPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Icon(icon, color: iconColor, size: 100),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.grey, height: 1.5),
              ),
              if (bookingId.isNotEmpty) ...[
                const SizedBox(height: 24),
                Text(
                  'Mã lịch hẹn: $bookingId',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ],
              const SizedBox(height: 36),
              ElevatedButton(
                onPressed: onPrimaryPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  primaryLabel,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
