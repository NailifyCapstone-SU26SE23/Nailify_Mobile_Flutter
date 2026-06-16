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
      if (mounted) {
        setState(() {
          _booking = data;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi tải chi tiết: $e')),
        );
      }
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
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: () => context.pop()),
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: const Center(child: Text('Không tìm thấy thông tin lịch hẹn')),
      );
    }

    final booking = _booking!;
    final bookingDate = DateTime.parse(booking['bookingDate']);
    final isUpcoming = bookingDate.isAfter(DateTime.now());
    final items = booking['bookingItems'] as List<dynamic>? ?? [];

    // XỬ LÝ MÃ QR BASE64
    final String? rawQrString = booking['qrCode']?.toString();
    final Uint8List? qrImageBytes = Base64ImageConverter.decode(rawQrString);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: () => context.pop()),
        title: const Text('Chi tiết lịch hẹn', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
            // Header Trạng thái
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: isUpcoming ? Colors.orange.shade50 : Colors.green.shade50, borderRadius: BorderRadius.circular(20)),
                child: Text(isUpcoming ? 'Sắp tới (Upcoming)' : 'Đã hoàn thành (Completed)', style: TextStyle(color: isUpcoming ? Colors.orange.shade800 : Colors.green.shade800, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),

            // Thông tin cơ bản
            const Text('Thông tin chung', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderLight)),
              child: Column(
                children: [
                  _buildRow('Chi nhánh', booking['salonName']),
                  _buildRow('Kỹ thuật viên', booking['artistName']),
                  _buildRow('Ngày hẹn', '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}'),
                  _buildRow('Giờ bắt đầu', booking['startTime']?.substring(0, 5)),
                  _buildRow('Thời lượng', '${booking['totalDuration']} phút'),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Danh sách Dịch vụ (Đã tùy chỉnh hiển thị 1 hàng)
            const Text('Dịch vụ đã đặt', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...items.map((item) {
              // 1. Lấy và lọc tên hợp lệ (bỏ qua null hoặc chuỗi rỗng)
              final List<String> validNames = [];
              final String variantName = item['nailVariantName']?.toString().trim() ?? '';
              final String serviceName = item['serviceName']?.toString().trim() ?? '';

              if (variantName.isNotEmpty) validNames.add(variantName);
              if (serviceName.isNotEmpty) validNames.add(serviceName);

              // Nếu cả 2 đều trống thì để mặc định
              final String finalName = validNames.isNotEmpty ? validNames.join(' & ') : 'Dịch vụ';

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderLight)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Cột 1: Tên dịch vụ
                    Expanded(
                        flex: 5,
                        child: Text(
                          finalName,
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        )
                    ),

                    // Cột 2: Số lượng
                    Expanded(
                        flex: 2,
                        child: Text(
                          'SL: ${item['quantity'] ?? 1}',
                          style: const TextStyle(color: Colors.grey, fontSize: 13),
                          textAlign: TextAlign.center,
                        )
                    ),

                    // Cột 3: Giá tiền format
                    Expanded(
                        flex: 4,
                        child: Text(
                          PriceFormatter.format(item['price']),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 14),
                          textAlign: TextAlign.right,
                        )
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 24),

            // Thanh toán
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.05), borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.primary.withOpacity(0.2))),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng thanh toán:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  Text(PriceFormatter.format(booking['totalPrice']), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mã QR CODE
            if (rawQrString != null && rawQrString.isNotEmpty) ...[
              const Text('Mã Check-in', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    const Text('Đưa mã này cho nhân viên tại quầy', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 16),

                    if (qrImageBytes != null)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          qrImageBytes,
                          width: 200,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => const _QrErrorPlaceholder(),
                        ),
                      )
                    else
                      const _QrErrorPlaceholder(),
                  ],
                ),
              ),
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String? value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          const SizedBox(width: 16),
          Expanded(child: Text(value ?? 'N/A', style: const TextStyle(fontWeight: FontWeight.w600), textAlign: TextAlign.right)),
        ],
      ),
    );
  }
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
        border: Border.all(color: Colors.grey.shade300, style: BorderStyle.solid),
      ),
      child: const Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
          SizedBox(height: 8),
          Text('Lỗi hiển thị mã QR', style: TextStyle(color: Colors.grey, fontSize: 12)),
        ],
      ),
    );
  }
}