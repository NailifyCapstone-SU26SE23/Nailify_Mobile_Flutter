import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../generated/l10n.dart';
import '../../data/datasources/payment_api_service.dart';

class BookingSuccessPage extends StatefulWidget {
  final Map<String, dynamic> bookingDetails;

  const BookingSuccessPage({super.key, required this.bookingDetails});

  @override
  State<BookingSuccessPage> createState() => _BookingSuccessPageState();
}

class _BookingSuccessPageState extends State<BookingSuccessPage> {
  final PaymentApiService _paymentApiService = PaymentApiService();
  bool _isCreatingPayment = false;

  Map<String, dynamic> get bookingDetails => widget.bookingDetails;

  Future<void> _createPayment(String bookingId) async {
    if (_isCreatingPayment) return;
    setState(() => _isCreatingPayment = true);
    try {
      final paymentData = await _paymentApiService.createPayment(bookingId);
      if (!mounted) return;
      context.go('/payment-qr', extra: paymentData);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(S.of(context).bookingPaymentError(e.toString())),
        ),
      );
    } finally {
      if (mounted) setState(() => _isCreatingPayment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final date = bookingDetails['date'] as DateTime?;
    final dateString = date != null
        ? '${date.day}/${date.month}/${date.year}'
        : '';
    final bookingId = bookingDetails['bookingId']?.toString();
    final discounts = _discounts;
    final hasPrice = bookingDetails['totalPrice'] != null;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final minHeight = constraints.maxHeight > 48
                ? constraints.maxHeight - 48
                : 0.0;

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: minHeight),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.green.withOpacity(0.15),
                            blurRadius: 20,
                            spreadRadius: 4,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.check_circle_rounded,
                        color: Colors.green,
                        size: 68,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      S.of(context).bookingSuccessTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      S.of(context).bookingSuccessSubtitle,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey.shade100),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.02),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        children: [
                          _buildInfoRow(
                            Icons.spa_rounded,
                            S.of(context).bookingInfoService,
                            bookingDetails['serviceName']?.toString() ?? '',
                          ),
                          const Divider(height: 24, color: Color(0xFFFFF0F5)),
                          _buildInfoRow(
                            Icons.calendar_month_rounded,
                            S.of(context).bookingInfoDate,
                            dateString,
                          ),
                          const Divider(height: 24, color: Color(0xFFFFF0F5)),
                          _buildInfoRow(
                            Icons.access_time_rounded,
                            S.of(context).bookingInfoTime,
                            bookingDetails['time']?.toString().substring(
                                  0,
                                  5,
                                ) ??
                                '',
                          ),
                          const Divider(height: 24, color: Color(0xFFFFF0F5)),
                          _buildInfoRow(
                            Icons.face_3_rounded,
                            S.of(context).bookingInfoStaff,
                            bookingDetails['stylistName']?.toString() ?? '',
                          ),
                          if (discounts.isNotEmpty || hasPrice) ...[
                            const Divider(height: 24, color: Color(0xFFFFF0F5)),
                            if (bookingDetails['price'] != null)
                              _buildAmountRow(
                                S.of(context).bookingInfoOriginalPrice,
                                bookingDetails['price'],
                              ),
                            ...discounts.map(_buildDiscountRow),
                            _buildAmountRow(
                              S.of(context).bookingInfoTotal,
                              bookingDetails['totalPrice'],
                              isTotal: true,
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),
                    if (bookingId != null && bookingId.isNotEmpty) ...[
                      Container(
                        height: 50,
                        width: double.infinity,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(25),
                          gradient: LinearGradient(
                            colors: _isCreatingPayment
                                ? [Colors.grey.shade400, Colors.grey.shade500]
                                : [AppColors.primary, const Color(0xFFFF80AB)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          boxShadow: [
                            if (!_isCreatingPayment)
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.3),
                                blurRadius: 10,
                                offset: const Offset(0, 4),
                              ),
                          ],
                        ),
                        child: ElevatedButton(
                          onPressed: _isCreatingPayment
                              ? null
                              : () => _createPayment(bookingId),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            foregroundColor: Colors.white,
                            shadowColor: Colors.transparent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                            elevation: 0,
                          ),
                          child: _isCreatingPayment
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(
                                  S.of(context).bookingPayBtn,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: () => context.go(
                            '/my-bookings/detail',
                            extra: bookingId,
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFFFF5F8),
                            foregroundColor: const Color(0xFFC44569),
                            elevation: 0,
                            side: const BorderSide(
                              color: Color(0xFFFFD1E3),
                              width: 1,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(25),
                            ),
                          ),
                          child: Text(
                            S.of(context).bookingViewBtn,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextButton.icon(
                      onPressed: () => context.go('/'),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFFC44569),
                        padding: const EdgeInsets.symmetric(
                          vertical: 12,
                          horizontal: 24,
                        ),
                      ),
                      icon: const Icon(Icons.home_rounded, size: 18),
                      label: Text(
                        S.of(context).bookingGoHome,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
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
    final raw =
        bookingDetails['discounts'] ?? bookingDetails['discountBreakdown'];
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
    final name = discount['name']?.toString() ?? S.of(context).bookingDiscount;
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
                ? _formatDiscountDisplay(amountDisplay!)
                : PriceFormatter.format(-(discount['amount'] ?? 0)),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDiscountDisplay(String value) {
    final text = value.trim();
    if (text.isEmpty) return text;
    final lower = text.toLowerCase();
    if (lower.contains('đ') || lower.contains('vnd')) return text;
    return '$text VNĐ';
  }
}
