import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/datasources/booking_api_service.dart';

class PaymentSuccessPage extends StatefulWidget {
  final Map<String, dynamic> paymentData;

  const PaymentSuccessPage({super.key, required this.paymentData});

  @override
  State<PaymentSuccessPage> createState() => _PaymentSuccessPageState();
}

class _PaymentSuccessPageState extends State<PaymentSuccessPage> {
  final BookingApiService _bookingApiService = BookingApiService();
  bool _isLoadingBooking = false;

  Future<void> _openBookingDetail() async {
    if (_isLoadingBooking) return;

    final directBookingId = widget.paymentData['bookingId']?.toString() ?? '';
    if (directBookingId.isNotEmpty) {
      context.go('/my-bookings/detail', extra: directBookingId);
      return;
    }

    final orderCode = _orderCode;
    if (orderCode == null) {
      _showError('Không tìm thấy mã thanh toán.');
      return;
    }

    setState(() => _isLoadingBooking = true);
    try {
      final bookingId = await _bookingApiService.getBookingIdByOrderCode(
        orderCode,
      );
      if (!mounted) return;

      if (bookingId.isEmpty) {
        _showError('Chưa tìm thấy lịch hẹn cho thanh toán này.');
        return;
      }

      context.go('/my-bookings/detail', extra: bookingId);
    } catch (e) {
      if (!mounted) return;
      _showError('Không thể lấy lịch hẹn: $e');
    } finally {
      if (mounted) setState(() => _isLoadingBooking = false);
    }
  }

  int? get _orderCode {
    final raw = widget.paymentData['orderCode'];
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '');
  }

  void _showError(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return _PaymentResultView(
      icon: Icons.check_circle,
      iconColor: Colors.green,
      title: 'Thanh toán thành công',
      message: 'Giao dịch đã được xác nhận. Cảm ơn bạn đã thanh toán.',
      primaryLabel: 'Xem lịch hẹn',
      isLoading: _isLoadingBooking,
      onPrimaryPressed: _openBookingDetail,
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
      primaryLabel: 'Về trang chủ',
      isLoading: false,
      onPrimaryPressed: () => context.go('/'),
    );
  }
}

class _PaymentResultView extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String message;
  final String primaryLabel;
  final bool isLoading;
  final VoidCallback onPrimaryPressed;

  const _PaymentResultView({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.isLoading,
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

              const SizedBox(height: 36),
              ElevatedButton(
                onPressed: isLoading ? null : onPrimaryPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Text(
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
