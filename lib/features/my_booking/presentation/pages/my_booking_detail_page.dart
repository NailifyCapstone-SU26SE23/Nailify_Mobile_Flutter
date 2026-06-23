import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// lib/features/my_booking/presentation/pages/my_booking_detail_page.dart
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/base64_image_converter.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../data/datasources/my_booking_api_service.dart';

class MyBookingDetailPage extends StatefulWidget {
  final String bookingId;

  const MyBookingDetailPage({super.key, required this.bookingId});

  @override
  State<MyBookingDetailPage> createState() => _MyBookingDetailPageState();
}

class _MyBookingDetailPageState extends State<MyBookingDetailPage> {
  final MyBookingApiService _apiService = MyBookingApiService();
  bool _isLoading = true;
  Map<String, dynamic>? _booking;

  @override
  void initState() {
    super.initState();
    _fetchBookingDetail();
  }

  Future<void> _fetchBookingDetail() async {
    try {
      final data = await _apiService.getBookingDetails(widget.bookingId);
      if (!mounted) return;
      setState(() {
        _booking = data;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi tải chi tiết: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_booking == null || _booking!.isEmpty) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () => context.pop(),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: Text('Không tìm thấy thông tin lịch hẹn')),
      );
    }

    final booking = _booking!;
    final bookingDate = DateTime.parse(booking['bookingDate']);
    final items = booking['bookingItems'] as List<dynamic>? ?? [];
    final status = _bookingStatus(booking['status']?.toString());
    final rawQrString = booking['qrCode']?.toString();
    final Uint8List? qrImageBytes = Base64ImageConverter.decode(rawQrString);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Chi tiết lịch hẹn',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: status.backgroundColor,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  status.label,
                  style: TextStyle(
                    color: status.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Thông tin chung',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: Column(
                children: [
                  _buildRow('Chi nhánh', booking['salonName']?.toString()),
                  _buildRow('Kỹ thuật viên', booking['artistName']?.toString()),
                  _buildRow(
                    'Ngày hẹn',
                    '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}',
                  ),
                  _buildRow(
                    'Giờ bắt đầu',
                    booking['startTime']?.toString().substring(0, 5),
                  ),
                  _buildRow('Thời lượng', '${booking['totalDuration']} phút'),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Dịch vụ đã đặt',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...items.map(_buildBookingItem),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.primary.withOpacity(0.2)),
              ),
              child: Column(
                children: [
                  // 1. Giá gốc
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Giá gốc:',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      Text(
                        PriceFormatter.format(booking['price'] ?? 0),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // 2. Khuyến mãi (Giảm giá)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Khuyến mãi:',
                        style: TextStyle(color: Colors.grey, fontSize: 14),
                      ),
                      Text(
                        '${PriceFormatter.format(booking['discount'] ?? 0)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.green, // Dùng màu xanh lá để nhấn mạnh số tiền được giảm
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),

                  // 3. Tổng thanh toán
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng thanh toán:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      Text(
                        PriceFormatter.format(booking['totalPrice'] ?? 0),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (rawQrString != null && rawQrString.isNotEmpty) ...[
              const Text(
                'Mã Check-in',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                ),
                child: Column(
                  children: [
                    const Text(
                      'Đưa mã này cho nhân viên tại quầy',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                    const SizedBox(height: 16),
                    if (qrImageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          qrImageBytes,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const _QrErrorPlaceholder(),
                        ),
                      )
                    else
                      const _QrErrorPlaceholder(),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildBookingItem(dynamic rawItem) {
    final item = rawItem as Map<String, dynamic>;
    final names = [
      item['nailVariantName']?.toString().trim() ?? '',
      item['customerNailName']?.toString().trim() ?? '',
      item['serviceName']?.toString().trim() ?? '',
    ].where((name) => name.isNotEmpty).toList();
    final name = names.isEmpty ? 'Dịch vụ' : names.join(' & ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              name,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              'SL: ${item['quantity'] ?? 1}',
              style: const TextStyle(color: Colors.grey, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              PriceFormatter.format(item['price'] * item['quantity']),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
                fontSize: 14,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value ?? 'N/A',
              style: const TextStyle(fontWeight: FontWeight.w600),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  _BookingStatusView _bookingStatus(String? status) {
    switch (status) {
      case 'Pending':
        return _BookingStatusView(
          'Đang chờ xác nhận',
          Colors.orange.shade50,
          Colors.orange.shade800,
        );
      case 'Assigned':
        return _BookingStatusView(
          'Đã xếp lịch',
          Colors.blue.shade50,
          Colors.blue.shade800,
        );
      case 'Reviewed':
        return _BookingStatusView(
          'Đã xem xét',
          Colors.indigo.shade50,
          Colors.indigo.shade800,
        );
      case 'Approved':
        return _BookingStatusView(
          'Đã chấp nhận',
          Colors.green.shade50,
          Colors.green.shade800,
        );
      case 'Rejected':
        return _BookingStatusView(
          'Đã từ chối',
          Colors.red.shade50,
          Colors.red.shade800,
        );
      case 'Cancelled':
        return _BookingStatusView(
          'Đã hủy',
          Colors.grey.shade200,
          Colors.grey.shade800,
        );
      case 'CheckedIn':
        return _BookingStatusView(
          'Đã Checked In',
          Colors.teal.shade50,
          Colors.teal.shade800,
        );
      case 'InProgress':
        return _BookingStatusView(
          'Đang thực hiện',
          Colors.purple.shade50,
          Colors.purple.shade800,
        );
      case 'Completed':
        return _BookingStatusView(
          'Đã hoàn thành',
          Colors.green.shade50,
          Colors.green.shade800,
        );
      case 'Repaired':
        return _BookingStatusView(
          'Đã bảo hành',
          Colors.cyan.shade50,
          Colors.cyan.shade800,
        );
      default:
        return _BookingStatusView(
          status ?? 'N/A',
          Colors.grey.shade100,
          Colors.grey.shade800,
        );
    }
  }
}

class _BookingStatusView {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const _BookingStatusView(this.label, this.backgroundColor, this.textColor);
}

class _QrErrorPlaceholder extends StatelessWidget {
  const _QrErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 200,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text(
            'Lỗi hiển thị mã QR',
            style: TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
