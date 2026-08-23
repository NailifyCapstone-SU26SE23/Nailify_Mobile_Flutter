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
      backgroundColor: const Color(0xFFFAF8F9),
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
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.pink.withOpacity(0.04),
                                blurRadius: 24,
                                spreadRadius: 4,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const Text(
                                'Số tiền thanh toán',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.grey,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                PriceFormatter.format(amount ?? 0),
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primaryDark,
                                  letterSpacing: -0.5,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 10,
                                    height: 10,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 1.5,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                        AppColors.primary.withOpacity(0.8),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'Đang chờ quét mã...',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              Center(
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.pink.withOpacity(0.06),
                                        blurRadius: 16,
                                        spreadRadius: 2,
                                      ),
                                    ],
                                  ),
                                  child: qrCode.isEmpty
                                      ? const SizedBox(
                                          width: 200,
                                          height: 200,
                                          child: Center(
                                            child: Text(
                                              'Không tìm thấy mã QR.\nVui lòng thử lại.',
                                              textAlign: TextAlign.center,
                                              style: TextStyle(
                                                color: Colors.grey,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        )
                                      : QrImageView(
                                          data: qrCode,
                                          version: QrVersions.auto,
                                          size: 200,
                                          backgroundColor: Colors.white,
                                        ),
                                ),
                              ),
                              const SizedBox(height: 24),
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF9F9FB),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Column(
                                  children: [
                                    _buildInfoRow(
                                      'Mã đơn hàng',
                                      '#${_orderCode.toString()}',
                                    ),
                                    const Divider(height: 16, color: Color(0xFFEEEEEE)),
                                    _buildInfoRow(
                                      'Phương thức',
                                      'Chuyển khoản QR',
                                    ),
                                    const Divider(height: 16, color: Color(0xFFEEEEEE)),
                                    _buildInfoRow(
                                      'Trạng thái',
                                      'Chờ thanh toán',
                                      isStatus: true,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF0F5),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: AppColors.primaryDark,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Chụp ảnh QR này hoặc sử dụng ứng dụng Ngân hàng / Ví điện tử quét mã để thanh toán.',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.primaryDark,
                                          fontWeight: FontWeight.w500,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),
                        TextButton(
                          onPressed: _isCancelling ? null : _cancelPayment,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade600,
                            minimumSize: const Size(double.infinity, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: Text(
                            _isCancelling ? 'Đang hủy...' : 'Hủy giao dịch',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                            ),
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

  Widget _buildInfoRow(String label, String value, {bool isStatus = false}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            color: Colors.grey,
            fontWeight: FontWeight.w500,
          ),
        ),
        if (isStatus)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.orange.shade200, width: 0.5),
            ),
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11,
                color: Colors.orange.shade800,
                fontWeight: FontWeight.bold,
              ),
            ),
          )
        else
          Text(
            value,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
      ],
    );
  }
}
