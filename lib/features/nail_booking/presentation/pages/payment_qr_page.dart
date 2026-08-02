import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../data/datasources/payment_api_service.dart';

import '../../../../generated/l10n.dart';

class PaymentQrPage extends StatefulWidget {
  final Map<String, dynamic> paymentData;

  const PaymentQrPage({super.key, required this.paymentData});

  @override
  State<PaymentQrPage> createState() => _PaymentQrPageState();
}

class _PaymentQrPageState extends State<PaymentQrPage> {
  final PaymentApiService _paymentApiService = PaymentApiService();
  Timer? _statusTimer;
  bool _isChecking = false;
  bool _isCancelling = false;
  bool _hasNavigated = false;

  int get _orderCode {
    final raw = widget.paymentData['orderCode'];
    if (raw is num) return raw.toInt();
    return int.tryParse(raw?.toString() ?? '') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPaymentStatus(showError: false);
    });
    _statusTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _checkPaymentStatus(showError: false),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    super.dispose();
  }

  Future<void> _checkPaymentStatus({bool showError = true}) async {
    if (_isChecking || _hasNavigated || _orderCode <= 0) return;
    setState(() => _isChecking = true);
    try {
      final status = await _paymentApiService.getPaymentStatus(_orderCode);
      if (!mounted) return;
      final normalized = status.toUpperCase();
      if (normalized == 'PAID' ||
          normalized == 'SUCCESS' ||
          normalized == 'COMPLETED') {
        _navigateOnce('/payment-success');
      } else if (normalized == 'CANCELLED' ||
          normalized == 'CANCELED' ||
          normalized == 'EXPIRED') {
        _navigateOnce('/payment-cancelled');
      } else if (showError) {
        _showSnackBar('Thanh toán vẫn đang chờ xử lý.');
      }
    } catch (e) {
      if (mounted && showError) {
        _showSnackBar('Không thể kiểm tra thanh toán: $e');
      }
    } finally {
      if (mounted && !_hasNavigated) setState(() => _isChecking = false);
    }
  }

  void _navigateOnce(String location) {
    if (_hasNavigated || !mounted) return;
    _hasNavigated = true;
    _statusTimer?.cancel();
    context.go(location, extra: widget.paymentData);
  }

  Future<void> _cancelPayment() async {
    if (_isCancelling || _hasNavigated || _orderCode <= 0) return;
    setState(() => _isCancelling = true);
    try {
      await _paymentApiService.cancelPayment(_orderCode);
      if (!mounted) return;
      _navigateOnce('/payment-cancelled');
    } catch (e) {
      if (mounted) _showSnackBar('Không thể hủy thanh toán: $e');
    } finally {
      if (mounted && !_hasNavigated) setState(() => _isCancelling = false);
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final qrCode = widget.paymentData['qrCode']?.toString() ?? '';
    final amount = widget.paymentData['amount'];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.primaryDark),
          onPressed: () => context.pop(),
        ),
        title: Text(
          S.of(context).paymentTitle,
          style: const TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
            color: AppColors.primaryDark,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Quét mã QR để thanh toán',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.orange.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Vui lòng thanh toán 20% tiền cọc trước',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.orange.shade800,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (qrCode.isEmpty)
                      const Text(
                        'Không có mã QR cho giao dịch này.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      )
                    else
                      QrImageView(
                        data: qrCode,
                        version: QrVersions.auto,
                        size: 260,
                        backgroundColor: Colors.white,
                      ),
                    const SizedBox(height: 20),
                    _buildInfoRow('Mã đơn', _orderCode.toString()),
                    const SizedBox(height: 8),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      'Số tiền',
                      PriceFormatter.format(amount ?? 0),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              OutlinedButton(
                onPressed: _isCancelling ? null : _cancelPayment,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  _isCancelling ? 'Đang hủy...' : 'Hủy thanh toán',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 90,
          child: Text(label, style: const TextStyle(color: Colors.grey)),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
