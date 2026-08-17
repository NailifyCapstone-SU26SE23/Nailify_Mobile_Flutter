import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../generated/l10n.dart';
import '../../data/datasources/payment_api_service.dart';

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
        _showSnackBar('Thanh toan van dang cho xu ly.');
      }
    } catch (e) {
      if (mounted && showError) {
        _showSnackBar('Khong the kiem tra thanh toan: $e');
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
      if (mounted) _showSnackBar('Khong the huy thanh toan: $e');
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.primaryDark,
          ),
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
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 40,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderLight),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Quét mã QR để thanh toán',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 18),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.borderLight,
                                    ),
                                  ),
                                  child: qrCode.isEmpty
                                      ? const SizedBox(
                                          width: 240,
                                          height: 240,
                                          child: Center(
                                            child: Text(
                                              'Khong co ma QR cho giao dich nay.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                        )
                                      : QrImageView(
                                          data: qrCode,
                                          version: QrVersions.auto,
                                          size: 240,
                                          backgroundColor: Colors.white,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: Colors.orange.shade50,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: Colors.orange.shade200,
                                  ),
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
                                        'Vui lòng thanh toán 20% tiền cọc trước',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: Colors.orange.shade800,
                                          fontWeight: FontWeight.w500,
                                          height: 1.25,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 18),
                              Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  children: [
                                    _buildInfoRow(
                                      'Ma don',
                                      _orderCode.toString(),
                                    ),
                                    const Divider(height: 18),
                                    _buildInfoRow(
                                      'So tien',
                                      PriceFormatter.format(amount ?? 0),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 20),
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
                            _isCancelling ? 'Đang hủy...' : 'Hủy thanh toán',
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
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
