import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import '../../../../generated/l10n.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/base64_image_converter.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../nails/data/models/nail_variant_model.dart';
import '../../../nails/data/models/shape_method_config_model.dart';
import '../../../nails/data/repositories/nail_variant_repository.dart';
import '../../../nail_booking/data/datasources/payment_api_service.dart';
import '../../../my_studio/data/datasources/studio_api_service.dart';
import '../../../my_studio/data/models/customer_nail_model.dart' as studio;
import '../../data/datasources/my_booking_api_service.dart';
import '../utils/booking_status_utils.dart';
import '../widgets/cancel_booking_dialog.dart';
import '../widgets/reschedule_booking_dialog.dart';

class MyBookingDetailPage extends StatefulWidget {
  final String bookingId;

  const MyBookingDetailPage({super.key, required this.bookingId});

  @override
  State<MyBookingDetailPage> createState() => _MyBookingDetailPageState();
}

class _MyBookingDetailPageState extends State<MyBookingDetailPage> {
  final MyBookingApiService _apiService = MyBookingApiService();
  final PaymentApiService _paymentApiService = PaymentApiService();
  final StudioApiService _studioApiService = StudioApiService();
  final NailVariantRepository _nailVariantRepository =
      getIt<NailVariantRepository>();
  bool _isLoading = true;
  bool _isCreatingPayment = false;
  Map<String, dynamic>? _booking;
  Map<String, dynamic>? _rating;
  final Map<int, NailVariantModel> _nailVariantsById = {};
  final Map<int, ShapeMethodConfigModel> _shapeMethodsById = {};
  final Map<String, studio.CustomerNailModel> _customerNailRequestsById = {};

  @override
  void initState() {
    super.initState();
    _fetchBookingDetail();
  }

  Future<void> _fetchBookingDetail() async {
    try {
      final data = await _apiService.getBookingDetails(widget.bookingId);
      await _fetchNailVariants(data);

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

  Future<void> _fetchNailVariants(Map<String, dynamic> booking) async {
    final items = booking['bookingItems'] as List<dynamic>? ?? [];
    final ids = items
        .whereType<Map>()
        .map(
          (item) =>
              _readNullableInt(item['nailVariantId'] ?? item['NailVariantId']),
        )
        .whereType<int>()
        .where((id) => id > 0 && !_nailVariantsById.containsKey(id))
        .toSet();

    for (final id in ids) {
      try {
        _nailVariantsById[id] = await _nailVariantRepository.getNailVariantById(
          id,
        );
      } catch (e) {
        debugPrint('==== Loi tai nail variant $id: $e ====');
      }
    }

    final requestIds = items
        .whereType<Map>()
        .map(
          (item) =>
              (item['customerNailRequestId'] ?? item['CustomerNailRequestId'])
                  ?.toString()
                  .trim() ??
              '',
        )
        .where(
          (id) => id.isNotEmpty && !_customerNailRequestsById.containsKey(id),
        )
        .toSet();

    for (final id in requestIds) {
      try {
        _customerNailRequestsById[id] = await _studioApiService
            .getNailRequestDetail(id);
      } catch (e) {
        debugPrint('==== Loi tai customer nail request $id: $e ====');
      }
    }

    final shapeMethodIds = items
        .whereType<Map>()
        .map(
          (item) => _readNullableInt(
            item['shapeMethodConfigId'] ?? item['ShapeMethodConfigId'],
          ),
        )
        .whereType<int>()
        .where((id) => id > 0 && !_shapeMethodsById.containsKey(id))
        .toSet();

    for (final id in shapeMethodIds) {
      try {
        _shapeMethodsById[id] = await _nailVariantRepository
            .getShapeMethodConfigById(id);
      } catch (e) {
        debugPrint('==== Loi tai shape method config $id: $e ====');
      }
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

  double? _toDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  bool _hasPaidAmount(Map<String, dynamic> booking) {
    return booking['amountPaid'] != null;
  }

  bool _isRefunded(Map<String, dynamic> booking) {
    return booking['isRefunded'] == true ||
        booking['isRefunded']?.toString().toLowerCase() == 'true';
  }

  Future<void> _createPayment(String bookingId) async {
    if (_isCreatingPayment || bookingId.isEmpty) return;
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

  String _getBookingSalonName(Map<String, dynamic>? booking) {
    if (booking == null) return '';
    final direct = booking['salonName']?.toString();
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    final nestedMap = booking['salon'];
    if (nestedMap is Map) {
      final name = (nestedMap['salonName'] ?? nestedMap['name'])?.toString();
      if (name != null && name.trim().isNotEmpty) return name.trim();
    }
    return '';
  }

  String _getBookingSalonAddress(Map<String, dynamic>? booking) {
    if (booking == null) return '';
    final direct = booking['salonAddress']?.toString();
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();
    final nestedMap = booking['salon'];
    if (nestedMap is Map) {
      final addr = (nestedMap['salonAddress'] ?? nestedMap['address'])
          ?.toString();
      if (addr != null && addr.trim().isNotEmpty) return addr.trim();
    }
    return '';
  }

  double? _getBookingLatitude(Map<String, dynamic>? booking) {
    if (booking == null) return null;
    final direct = booking['latitude'];
    if (direct != null) return _toDouble(direct);
    final nestedMap = booking['salon'];
    if (nestedMap is Map) {
      final lat = nestedMap['latitude'];
      if (lat != null) return _toDouble(lat);
    }
    return null;
  }

  double? _getBookingLongitude(Map<String, dynamic>? booking) {
    if (booking == null) return null;
    final direct = booking['longitude'];
    if (direct != null) return _toDouble(direct);
    final nestedMap = booking['salon'];
    if (nestedMap is Map) {
      final lng = nestedMap['longitude'];
      if (lng != null) return _toDouble(lng);
    }
    return null;
  }

  String _getBookingArtistName(Map<String, dynamic>? booking) {
    if (booking == null) return '';
    final direct =
        booking['artistName']?.toString() ??
        booking['nailArtistName']?.toString();
    if (direct != null && direct.trim().isNotEmpty) return direct.trim();

    for (final key in const ['nailArtist', 'artist']) {
      final nestedMap = booking[key];
      if (nestedMap is Map) {
        final name = (nestedMap['fullName'] ?? nestedMap['name'])?.toString();
        if (name != null && name.trim().isNotEmpty) return name.trim();
        final first = nestedMap['firstName']?.toString() ?? '';
        final last = nestedMap['lastName']?.toString() ?? '';
        final combined = '$first $last'.trim();
        if (combined.isNotEmpty) return combined;
      }
    }
    return '';
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
        body: Center(child: Text(S.of(context).bookingNotFound)),
      );
    }

    final booking = _booking!;
    final bookingDate = DateTime.parse(booking['bookingDate']);
    final items = booking['bookingItems'] as List<dynamic>? ?? [];
    final rawStatus = booking['status']?.toString();
    final status = bookingStatusView(rawStatus, context);
    final discounts = _discounts;
    final isRated = bookingIsRated(booking);
    final rawQrString = booking['qrCode']?.toString();
    final Uint8List? qrImageBytes = Base64ImageConverter.decode(rawQrString);
    final canCancel =
        rawStatus == 'Pending' ||
        rawStatus == 'Approved' ||
        rawStatus == 'Assigned';
    final canReschedule = rawStatus == 'Approved';
    final canRate = rawStatus == 'Completed' && !isRated;
    final canPay = rawStatus == 'Pending' && !_hasPaidAmount(booking);
    final canRequestRefund =
        rawStatus == 'Cancelled' &&
        _hasPaidAmount(booking) &&
        !_isRefunded(booking);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios,
            color: AppColors.primaryDark,
            size: 20,
          ),
          onPressed: () => context.go('/my-bookings'),
          // context.pop(),
        ),
        title: Text(
          S.of(context).bookingDetailsTitle,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
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
                  border: Border.all(
                    color: status.textColor.withValues(alpha: 0.15),
                    width: 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(status.icon, color: status.textColor, size: 16),
                    const SizedBox(width: 6),
                    Text(
                      status.label,
                      style: TextStyle(
                        color: status.textColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              S.of(context).bookingGeneralInfo,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                  Material(
                    color: Colors
                        .transparent, // Đảm bảo hiệu ứng chạm hiển thị đúng
                    child: InkWell(
                      onTap: () {
                        final sName = _getBookingSalonName(_booking);
                        final salonName = sName.isNotEmpty
                            ? sName
                            : 'Nailify Salon';
                        final address = _getBookingSalonAddress(_booking);
                        final latitude = _getBookingLatitude(_booking);
                        final longitude = _getBookingLongitude(_booking);
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
                                  Text(
                                    S.of(context).bookingBranchLabel,
                                    style: const TextStyle(
                                      color: Colors.grey,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _getBookingSalonName(_booking).isNotEmpty
                                          ? _getBookingSalonName(_booking)
                                          : 'Nailify Salon',
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
                  _buildRow(
                    S.of(context).bookingStylistLabel,
                    _getBookingArtistName(booking).isNotEmpty
                        ? _getBookingArtistName(booking)
                        : S.of(context).anyArtist,
                  ),
                  _buildRow(
                    S.of(context).bookingDateLabel,
                    '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}',
                  ),
                  _buildRow(
                    S.of(context).bookingStartTimeLabel,
                    booking['startTime']?.toString().substring(0, 5),
                  ),
                  _buildRow(
                    S.of(context).bookingDurationLabel,
                    S
                        .of(context)
                        .bookingDurationValue(
                          booking['totalDuration']?.toString() ?? '0',
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              S.of(context).bookingServicesBooked,
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
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
                      Text(
                        S.of(context).bookingOriginalPriceLabel,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 14,
                        ),
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
                        Text(
                          S.of(context).bookingDiscountLabel,
                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            S.of(context).bookingTotalPaymentLabel,
                            style: const TextStyle(
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
                      const SizedBox(height: 8),
                      if (booking['amountPaid'] != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(S.of(context).bookingPaidAmount),
                            Text(
                              PriceFormatter.format(booking['amountPaid']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      if (booking['amountDue'] != null)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(S.of(context).bookingRemainingAmount),
                            Text(
                              PriceFormatter.format(booking['amountDue']),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Mã QR CODE
            if (isRated) ...[
              Text(
                S.of(context).bookingYourRating,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
              _buildRatingCard(),
              const SizedBox(height: 24),
            ],

            if (!isRated && rawQrString != null && rawQrString.isNotEmpty) ...[
              Text(
                S.of(context).bookingCheckInCode,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
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
                    Text(
                      S.of(context).bookingCheckInInstruction,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
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
            if (canPay) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isCreatingPayment
                      ? null
                      : () => _createPayment(widget.bookingId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: _isCreatingPayment
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.payments_rounded, color: Colors.white),
                  label: Text(
                    S.of(context).bookingPayBtn,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            if (_hasPaidAmount(booking)) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/booking-transactions',
                    extra: widget.bookingId,
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text(
                    'Xem giao dịch',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
            if (canReschedule) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (context) => RescheduleBookingDialog(
                        bookingId: widget.bookingId,
                        onConfirm: (newDate, newTime, reason) async {
                          try {
                            final success = await _apiService
                                .requestRescheduleBooking(
                                  widget.bookingId,
                                  newDate: newDate,
                                  newTime: newTime,
                                  reason: reason,
                                );
                            if (!context.mounted) return false;
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    S.of(context).bookingRescheduleSuccess,
                                  ),
                                  backgroundColor: Colors.green,
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                              // Chuyển về trang danh sách lịch đặt, tab Dời lịch (index 2)
                              context.go(
                                '/my-bookings',
                                extra: {'initialTab': 2},
                              );
                              return true;
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    S.of(context).bookingRescheduleFail,
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                              return false;
                            }
                          } catch (e) {
                            if (!context.mounted) return false;
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Lỗi: $e'),
                                backgroundColor: Colors.red,
                              ),
                            );
                            return false;
                          }
                        },
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(
                    Icons.edit_calendar_rounded,
                    color: Colors.white,
                  ),
                  label: Text(
                    S.of(context).bookingRescheduleBtnLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            if (canCancel) ...[
              SizedBox(height: canReschedule ? 12 : 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (dialogContext) => CancelBookingDialog(
                        bookingId: widget.bookingId,
                        onConfirm: (reason) async {
                          try {
                            final success = await _apiService.cancelBooking(
                              widget.bookingId,
                              reason: reason,
                            );
                            if (!context.mounted) return;
                            if (success) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    S.of(context).bookingCancelSuccess,
                                  ),
                                ),
                              );
                              if (_hasPaidAmount(booking)) {
                                context.go(
                                  '/refund-bank-info',
                                  extra: widget.bookingId,
                                );
                              } else {
                                await _fetchBookingDetail();
                              }
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    S.of(context).bookingCancelFail,
                                  ),
                                ),
                              );
                            }
                          } catch (e) {
                            if (!context.mounted) return;
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
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
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    S.of(context).bookingCancelBtnLabel,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ],
            if (canRequestRefund) ...[
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () =>
                      context.go('/refund-bank-info', extra: widget.bookingId),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.receipt_long, color: Colors.white),
                  label: const Text(
                    'Hoàn tiền',
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
                    'Đánh giá',
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
    final components = _bookingItemComponents(item);
    final variantDetails = _bookingItemVariantDetails(item);
    final detailLines = variantDetails.isNotEmpty
        ? variantDetails
        : _groupBookingComponents(components);
    final name = names.isEmpty
        ? S.of(context).bookingInfoService
        : names.join(' & ');

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                flex: 10,
                child: Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Expanded(
                flex: 5,
                child: Text(
                  S
                      .of(context)
                      .bookingQuantityLabel(
                        _readInt(item['quantity'], fallback: 1).toString(),
                      ),
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                flex: 9,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      PriceFormatter.format(
                        _bookingItemUnitPrice(item) *
                            _readInt(item['quantity'], fallback: 1) *
                            _getItemCount(item),
                      ),
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.right,
                    ),
                    // Show unit price and finger count as subtitle
                    if (_getItemCount(item) > 1) ...[
                      const SizedBox(height: 2),
                      Text(
                        '${PriceFormatter.format(_bookingItemUnitPrice(item))} × ${_getItemCount(item)} ${S.of(context).bookingFingersLabel}',
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 11,
                        ),
                        textAlign: TextAlign.right,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (detailLines.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(height: 1),
            const SizedBox(height: 8),
            const _PriceTableHeader(),
            const SizedBox(height: 2),
            ...detailLines.map(_buildBookingComponentLine),
          ],
        ],
      ),
    );
  }

  Widget _buildBookingComponentLine(Map<String, dynamic> component) {
    // Get the actual component data (nested inside 'component' key)
    final componentData = component['component'] as Map? ?? component;
    final price = componentData['price'] as num? ?? 0;

    // Get fingerIndex from the component (not from the nested 'component' object)
    final fingerIndex = _readNullableInt(
      component['fingerIndex'] ?? component['FingerIndex'],
    );
    final count =
        component['quantity'] as int? ??
        _getItemCountFromFingerIndex(fingerIndex);

    final name = component['name']?.toString() ?? _componentName(component);

    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              name,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 38,
            child: Text(
              'x$count',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              price > 0 ? PriceFormatter.format(price * count) : '-',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  int _getItemCountFromFingerIndex(int? fingerIndex) {
    if (fingerIndex == null) return 1;
    if (fingerIndex == -1) return 5;
    if (fingerIndex >= 0 && fingerIndex <= 4) return 1;
    return 1;
  }

  List<Map<String, dynamic>> _bookingItemVariantDetails(
    Map<String, dynamic> item,
  ) {
    final request = _customerNailRequestForItem(item);
    if (request != null) return _bookingItemCustomerNailDetails(item, request);

    final variantId = _readNullableInt(
      item['nailVariantId'] ?? item['NailVariantId'],
    );
    final variant = variantId == null ? null : _nailVariantsById[variantId];

    final details = <Map<String, dynamic>>[];
    if (variant?.nailSurface != null) {
      details.add({
        'name': variant!.nailSurface!.name,
        'price': variant.nailSurface!.price,
        'quantity': 1,
      });
    }

    final shapeMethodName = _shapeMethodName(item);
    if (shapeMethodName != null && shapeMethodName.trim().isNotEmpty) {
      details.add({
        'name': shapeMethodName,
        'price': _shapeMethodPrice(item),
        'quantity': 1,
      });
    }

    if (variant != null) {
      final componentRowsByKey = <String, Map<String, dynamic>>{};
      for (final component in variant.nailComponents) {
        final detail = component.component;
        final name = detail?.name ?? 'Thanh phan nail';
        final type = detail?.componentType.trim() ?? '';
        final label = type.isEmpty ? name : '$type: $name';
        final price = detail?.price ?? 0;
        final quantity = component.fingerIndex == -1 ? 5 : 1;
        final key =
            '${detail?.componentId ?? component.componentId}|$label|$price';
        final existing = componentRowsByKey[key];
        if (existing == null) {
          componentRowsByKey[key] = {
            'name': label,
            'price': price,
            'quantity': quantity,
          };
        } else {
          existing['quantity'] = (existing['quantity'] as int) + quantity;
        }
      }
      details.addAll(componentRowsByKey.values);
    }

    return details;
  }

  studio.CustomerNailModel? _customerNailRequestForItem(
    Map<String, dynamic> item,
  ) {
    final requestId =
        (item['customerNailRequestId'] ?? item['CustomerNailRequestId'])
            ?.toString()
            .trim();
    if (requestId == null || requestId.isEmpty) return null;
    return _customerNailRequestsById[requestId];
  }

  List<Map<String, dynamic>> _bookingItemCustomerNailDetails(
    Map<String, dynamic> item,
    studio.CustomerNailModel request,
  ) {
    final details = <Map<String, dynamic>>[];

    final surfaceName = request.nailSurface?['name']?.toString().trim();
    if (surfaceName != null && surfaceName.isNotEmpty) {
      details.add({
        'name': surfaceName,
        'price': request.surfacePrice,
        'quantity': 1,
      });
    }

    final shapeMethodName = _shapeMethodName(item);
    if (shapeMethodName != null && shapeMethodName.trim().isNotEmpty) {
      details.add({
        'name': shapeMethodName,
        'price': _shapeMethodPrice(item),
        'quantity': 1,
      });
    }

    details.addAll(
      _groupBookingComponents(_requestCustomerNailComponents(request)),
    );

    if (request.price > 0) {
      details.add({
        'name': 'Phí Custom',
        'price': request.price,
        'quantity': 1,
      });
    }

    return details;
  }

  List<Map<String, dynamic>> _requestCustomerNailComponents(
    studio.CustomerNailModel request,
  ) {
    return request.customerNailComponents
        .whereType<Map>()
        .map((component) => Map<String, dynamic>.from(component))
        .toList();
  }

  String? _shapeMethodName(Map<String, dynamic> item) {
    final id = _readNullableInt(
      item['shapeMethodConfigId'] ?? item['ShapeMethodConfigId'],
    );
    final cached = id == null ? null : _shapeMethodsById[id];
    if (cached != null && cached.name.trim().isNotEmpty) return cached.name;

    for (final key in const [
      'shapeMethodName',
      'ShapeMethodName',
      'shapeMethodConfigName',
      'ShapeMethodConfigName',
    ]) {
      final value = item[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    final shapeMethod = item['shapeMethodConfig'] ?? item['ShapeMethodConfig'];
    if (shapeMethod is Map) {
      final value = shapeMethod['name']?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    return null;
  }

  num _shapeMethodPrice(Map<String, dynamic> item) {
    final id = _readNullableInt(
      item['shapeMethodConfigId'] ?? item['ShapeMethodConfigId'],
    );
    final cached = id == null ? null : _shapeMethodsById[id];
    if (cached != null) return cached.price;

    final direct = item['shapeMethodPrice'] ?? item['ShapeMethodPrice'];
    if (direct is num) return direct;
    final parsedDirect = num.tryParse(direct?.toString() ?? '');
    if (parsedDirect != null) return parsedDirect;

    final shapeMethod = item['shapeMethodConfig'] ?? item['ShapeMethodConfig'];
    if (shapeMethod is Map) {
      final price = shapeMethod['price'] ?? shapeMethod['Price'];
      if (price is num) return price;
      final parsed = num.tryParse(price?.toString() ?? '');
      if (parsed != null) return parsed;
    }

    return 0;
  }

  List<Map<String, dynamic>> _bookingItemComponents(Map<String, dynamic> item) {
    final components = <Map<String, dynamic>>[];

    void addFrom(dynamic value) {
      if (value is List) {
        components.addAll(
          value.whereType<Map>().map(
            (component) => Map<String, dynamic>.from(component),
          ),
        );
      }
    }

    addFrom(item['nailComponents'] ?? item['NailComponents']);
    addFrom(item['customerNailComponents'] ?? item['CustomerNailComponents']);

    for (final key in const ['nailVariant', 'customerNail']) {
      final nested = item[key];
      if (nested is Map) {
        addFrom(nested['nailComponents'] ?? nested['NailComponents']);
        addFrom(nested['Components'] ?? nested['CustomerNailComponents']);
      }
    }

    return components;
  }

  List<Map<String, dynamic>> _groupBookingComponents(
    List<Map<String, dynamic>> components,
  ) {
    final rowsByKey = <String, Map<String, dynamic>>{};
    for (final component in components) {
      final componentData = component['component'] as Map? ?? component;
      final name =
          componentData['name']?.toString() ?? _componentName(component);
      final type = componentData['componentType']?.toString().trim() ?? '';
      final label = type.isEmpty ? name : '$type: $name';
      final price = componentData['price'] as num? ?? 0;
      final fingerIndex = _readNullableInt(
        component['fingerIndex'] ?? component['FingerIndex'],
      );
      final quantity = fingerIndex == -1 ? 5 : 1;
      final key =
          '${componentData['componentId'] ?? component['componentId'] ?? component['ComponentId']}|$label|$price';
      final existing = rowsByKey[key];
      if (existing == null) {
        rowsByKey[key] = {'name': label, 'price': price, 'quantity': quantity};
      } else {
        existing['quantity'] = (existing['quantity'] as int) + quantity;
      }
    }
    return rowsByKey.values.toList();
  }

  String _componentName(Map<String, dynamic> component) {
    for (final key in const [
      'component',
      'customerComponent',
      'nailComponent',
      'customerNailComponent',
    ]) {
      final nested = component[key];
      if (nested is Map) {
        final name = nested['name']?.toString().trim();
        if (name != null && name.isNotEmpty) return name;
      }
    }

    final name = (component['name'] ?? component['componentName'])
        ?.toString()
        .trim();
    if (name != null && name.isNotEmpty) return name;
    return 'Thanh phan nail';
  }

  int? _readNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  int _readInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  num _bookingItemUnitPrice(Map<String, dynamic> item) {
    final request = _customerNailRequestForItem(item);
    if (request != null) {
      // Start with customer nail base price
      num totalPrice = request.customerNailPrice;

      // Add shape method price
      final shapePrice = _shapeMethodPrice(item);
      if (shapePrice > 0) {
        totalPrice += shapePrice;
      }

      // Add custom fee (request.price is the custom fee)
      if (request.price > 0) {
        totalPrice += request.price;
      }

      return totalPrice;
    }

    final direct = item['price'] ?? item['unitPrice'] ?? item['basePrice'];
    if (direct is num) return direct;
    final parsedDirect = num.tryParse(direct?.toString() ?? '');
    if (parsedDirect != null) return parsedDirect;

    for (final key in const [
      'component',
      'customerComponent',
      'nailComponent',
      'customerNailComponent',
      'service',
      'nailVariant',
      'customerNail',
    ]) {
      final nested = item[key];
      if (nested is Map) {
        final price = nested['price'];
        if (price is num) return price;
        final parsed = num.tryParse(price?.toString() ?? '');
        if (parsed != null) return parsed;
      }
    }
    return 0;
  }

  int _getItemCount(Map<String, dynamic> item) {
    final fingerIndex = item['fingerIndex'];

    if (fingerIndex == -1) return 5;

    if (fingerIndex is int && fingerIndex >= 0 && fingerIndex <= 4) return 1;

    return 1;
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
                ? _formatDiscountDisplay(amountDisplay!)
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

  String _formatDiscountDisplay(String value) {
    final text = value.trim();
    if (text.isEmpty) return text;
    final lower = text.toLowerCase();
    if (lower.contains('đ') || lower.contains('vnd')) return text;
    return '$text VNĐ';
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
        child: Text(
          S.of(context).ratingLoadError,
          style: const TextStyle(color: Colors.grey),
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

          _buildRatingRow(S.of(context).ratingOverall, rating['overallScore']),
          _buildRatingRow(
            S.of(context).ratingServiceQuality,
            rating['serviceQuality'],
          ),
          _buildRatingRow(
            S.of(context).ratingPunctuality,
            rating['punctuality'],
          ),
          _buildRatingRow(
            S.of(context).ratingCleanliness,
            rating['cleanliness'],
          ),

          if (comment.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              S.of(context).bookingReviewTitle,
              style: const TextStyle(fontWeight: FontWeight.bold),
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

class _PriceTableHeader extends StatelessWidget {
  const _PriceTableHeader();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );
    return const Padding(
      padding: EdgeInsets.only(left: 8),
      child: Row(
        children: [
          Expanded(flex: 5, child: Text('Thành phần', style: style)),
          SizedBox(
            width: 38,
            child: Text('SL', style: style, textAlign: TextAlign.center),
          ),
          SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text('Giá', style: style, textAlign: TextAlign.right),
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
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.broken_image_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            S.of(context).bookingQrError,
            style: const TextStyle(color: Colors.grey, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
