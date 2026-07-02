import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/base64_image_converter.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../data/datasources/my_booking_api_service.dart';
import '../utils/booking_status_utils.dart';
import '../widgets/cancel_booking_dialog.dart';

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
  Map<String, dynamic>? _rating;

  @override
  void initState() {
    super.initState();
    _fetchBookingDetail();
  }

  Future<void> _fetchBookingDetail() async {
    try {
      final data = await _apiService.getBookingDetails(widget.bookingId);
      Map<String, dynamic>? rating;
      if (bookingIsRated(data)) {
        try {
          rating = await _apiService.getRatingByBooking(widget.bookingId);
        } catch (e) {
          debugPrint('==== Lỗi tải đánh giá booking: $e ====');
        }
      }
      if (!mounted) return;
      setState(() {
        _booking = data;
        _rating = rating;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Lỗi tải chi tiết: $e')));
    }
  }

  void _showMapPopup(
    BuildContext context,
    String salonName,
    String? address,
    double? latitude,
    double? longitude,
  ) {
    // Tọa độ
    final double lat = latitude ?? 10.993592755518687;
    final double lng = longitude ?? 106.65636465428618;
    final LatLng targetPosition = LatLng(lat, lng);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (BuildContext context) {
        final double height = MediaQuery.of(context).size.height * 0.8;

        return Container(
          height: height,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Thanh kéo & Thông tin
              Container(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 20,
                ),
                child: Column(
                  children: [
                    Container(
                      width: 40,
                      height: 5,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Vị trí: $salonName',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      address ?? 'Chi nhánh của Nailify',
                      style: const TextStyle(fontSize: 13, color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Bản đồ
              Expanded(
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(20),
                  ),
                  child: FlutterMap(
                    options: MapOptions(
                      initialCenter: targetPosition,
                      initialZoom: 16.0,
                    ),
                    children: [
                      TileLayer(
                        // Dùng CartoDB
                        urlTemplate:
                            'https://basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.nailify.app',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: targetPosition,
                            width: 50,
                            height: 50,
                            child: const Icon(
                              Icons.location_on,
                              color: AppColors.primary,
                              size: 40,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
    final rawStatus = booking['status']?.toString();
    final status = bookingStatusView(rawStatus);
    final discounts = _discounts;
    final isRated = bookingIsRated(booking);
    final rawQrString = booking['qrCode']?.toString();
    final Uint8List? qrImageBytes = Base64ImageConverter.decode(rawQrString);
    final canCancel =
        rawStatus == 'Pending' ||
        rawStatus == 'Approved' ||
        rawStatus == 'Assigned';
    final canRate = rawStatus == 'Completed' && !isRated;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => context.go('/my-bookings'),
          // context.pop(),
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
            // Header Trạng thái
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
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
                  //_buildRow('Chi nhánh', booking['salonName']?.toString()),
                  //map xịn
                  Material(
                    color: Colors
                        .transparent, // Đảm bảo hiệu ứng chạm hiển thị đúng
                    child: InkWell(
                      onTap: () {
                        final salonName =
                            _booking?['salonName']?.toString() ??
                            'Chi nhánh Nailify';
                        final address = _booking?['salonAddress']?.toString();
                        final latitude = _booking?['latitude'] as double?;
                        final longitude = _booking?['longitude'] as double?;
                        _showMapPopup(
                          context,
                          salonName,
                          address,
                          latitude,
                          longitude,
                        );
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text(
                                    'Chi nhánh',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _booking?['salonName']?.toString() ??
                                          'Đang tải...',
                                      textAlign: TextAlign.right,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 15,
                                        color: AppColors.primary,
                                        decorationColor: AppColors.primary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
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

            // Thanh toán
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
                  if (discounts.isNotEmpty)
                    ...discounts.map(_buildDiscountRow)
                  else
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Khuyến mãi:',
                          style: TextStyle(color: Colors.grey, fontSize: 14),
                        ),
                        Text(
                          PriceFormatter.format(booking['discount'] ?? 0),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: Colors
                                .green, // Dùng màu xanh lá để nhấn mạnh số tiền được giảm
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
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
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

            // Mã QR CODE
            if (isRated) ...[
              const Text(
                'Đánh giá của bạn',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              _buildRatingCard(),
              const SizedBox(height: 24),
            ],

            if (!isRated && rawQrString != null && rawQrString.isNotEmpty) ...[
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
                          errorBuilder: (_, _, _) =>
                              const _QrErrorPlaceholder(),
                        ),
                      )
                    else
                      const _QrErrorPlaceholder(),
                  ],
                ),
              ),
            ],
            if (canCancel) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => CancelBookingDialog(
                        bookingId: widget.bookingId,
                        onConfirm: (reason) async {
                          /* TODO: Bỏ chú thích khi API hoàn thiện
                          try {
                            final success = await _apiService.cancelBooking(
                              widget.bookingId, 
                              reason: reason,
                            );
                            if (success && mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Hủy lịch thành công')),
                              );
                              _fetchBookingDetail(); // Load lại trang
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Hủy lịch thất bại')),
                              );
                            }
                          } catch (e) {
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text('Lỗi: $e')),
                              );
                            }
                          }
                          */
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('API chưa hoàn thiện'),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Hủy đặt lịch',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            if (canRate) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => context.push(
                    '/my-bookings/rate',
                    extra: widget.bookingId,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.star, color: Colors.white),
                  label: const Text(
                    'Rate',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 24),
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

  List<Map<String, dynamic>> get _discounts {
    final raw = _booking?['discounts'] ?? _booking?['discountBreakdown'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((discount) => Map<String, dynamic>.from(discount))
        .toList();
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
              style: const TextStyle(color: Colors.grey, fontSize: 14),
            ),
          ),
          Text(
            amountDisplay?.isNotEmpty == true
                ? amountDisplay!
                : PriceFormatter.format(-(discount['amount'] ?? 0)),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: Colors.green,
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

  Widget _buildRatingCard() {
    final rating = _rating;
    if (rating == null || rating.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: const Text(
          'Chưa tải được thông tin đánh giá.',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    final comment = rating['comment']?.toString().trim() ?? '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Add image if URL exists
          if (rating['imageUrl'] != null &&
              rating['imageUrl'].toString().isNotEmpty) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                rating['imageUrl'],
                width: double.infinity,
                height: 200,
                fit: BoxFit.cover,
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Center(child: CircularProgressIndicator()),
                  );
                },
                errorBuilder: (context, error, stackTrace) {
                  return Container(
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.broken_image, size: 50),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
          ],

          _buildRatingRow('Tổng thể', rating['overallScore']),
          _buildRatingRow('Chất lượng dịch vụ', rating['serviceQuality']),
          _buildRatingRow('Đúng giờ', rating['punctuality']),
          _buildRatingRow('Sạch sẽ', rating['cleanliness']),

          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text(
              'Nhận xét',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(comment, style: const TextStyle(color: AppColors.textPrimary)),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingRow(String label, dynamic score) {
    final value = int.tryParse(score?.toString() ?? '') ?? 0;
    final normalizedValue = value.clamp(0, 5);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Row(
            children: List.generate(5, (index) {
              return Icon(
                index < normalizedValue ? Icons.star : Icons.star_border,
                size: 18,
                color: Colors.amber,
              );
            }),
          ),
          const SizedBox(width: 8),
          Text(
            '$normalizedValue/5',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
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
