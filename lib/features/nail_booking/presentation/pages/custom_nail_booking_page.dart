import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../generated/l10n.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/signalr_service.dart';
import '../../../../core/network/signalr_events.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../my_studio/data/models/customer_nail_model.dart';
import '../../../nails/data/models/shape_method_config_model.dart';
import '../../../nails/data/repositories/nail_variant_repository.dart';
import '../../data/datasources/booking_api_service.dart';
import '../../data/datasources/payment_api_service.dart';
import '../../data/datasources/promotion_api_service.dart';
import '../../data/models/wallet_voucher_model.dart';
import '../widgets/booking_date_selection.dart';
import '../widgets/booking_service_selection.dart';
import '../widgets/booking_time_selection.dart';
import '../widgets/booking_promotion_sheet.dart';
import '../widgets/payment_detail_table.dart';
import '../widgets/sleek_booking_step_indicator.dart';

class CustomNailBookingPage extends StatefulWidget {
  final CustomerNailModel nail;
  final int? shapeMethodConfigId;
  final String? shapeMethodName;
  final num? shapeMethodPrice;
  final int? shapeMethodDuration;

  const CustomNailBookingPage({
    super.key,
    required this.nail,
    this.shapeMethodConfigId,
    this.shapeMethodName,
    this.shapeMethodPrice,
    this.shapeMethodDuration,
  });

  @override
  State<CustomNailBookingPage> createState() => _CustomNailBookingPageState();
}

class _CustomNailBookingPageState extends State<CustomNailBookingPage> {
  final PageController _pageController = PageController();
  final BookingApiService _apiService = BookingApiService();
  final PaymentApiService _paymentApiService = PaymentApiService();
  final PromotionApiService _promotionApiService = PromotionApiService();

  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _isLoadingServices = true;
  bool _isLoadingTimes = false;
  bool _isLoadingPromotions = false;
  bool _isReviewingPrice = false;
  bool _useWalletBalance = false;
  bool _isLoadingWallet = false;
  double? _walletAvailableBalance;
  String? _holdToken;
  Timer? _holdTimer;
  int _holdRemainingSeconds = 0;
  bool _isHolding = false;
  StreamSubscription? _slotStatusChangedSub;

  Future<List<ShapeMethodConfigModel>>? _shapeMethodsFuture;
  ShapeMethodConfigModel? _selectedShapeMethod;
  Map<String, dynamic>? _priceReview;
  String? _priceReviewKey;
  String? _inFlightPriceReviewKey;
  Future<void>? _inFlightPriceReview;
  List<dynamic> _services = [];
  List<dynamic> _timeSlots = [];
  List<WalletVoucherModel> _promotions = [];
  List<WalletVoucherModel> _selectedPromotions = [];
  List<String?> _selectedExtraServices = [];
  DateTime? _selectedDate;
  String? _selectedTime;

  List<Map<String, dynamic>> get _bookingSteps => [
    {'title': S.of(context).bookingStepServices, 'icon': Icons.spa_rounded},
    {
      'title': S.of(context).bookingStepBook,
      'icon': Icons.calendar_month_rounded,
    },
    {
      'title': S.of(context).bookingStepCompleted,
      'icon': Icons.check_circle_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    _selectedShapeMethod = _initialShapeMethod;
    _shapeMethodsFuture = _loadShapeMethods();
    _fetchServices();
    _fetchPromotions();
    _fetchWalletBalance();

    final signalR = getIt<SignalRService>();
    _slotStatusChangedSub = signalR.onSlotStatusChanged.listen(_onSlotStatusChanged);
  }

  void _onSlotStatusChanged(SlotStatusChangedEvent event) {
    if (!mounted) return;
    
    final currentSalonId = widget.nail.salonId;
    if (event.salonId.toLowerCase() != currentSalonId.toLowerCase()) return;
    
    if (_selectedDate != null) {
      final String currentFormattedDate = _formatBookingDate(_selectedDate!); 
      if (!event.bookingDate.startsWith(currentFormattedDate.split('T')[0])) return;
    }

    final currentArtistId = widget.nail.nailArtistId ?? '';
    
    if (currentArtistId.isEmpty || event.artistId.toLowerCase() == currentArtistId.toLowerCase() || event.artistId == '') {
       if (event.action == 'Held' || event.action == 'Released' || event.action == 'Booked') {
         if (_currentStep == 1) {
           _fetchTimeSlots();
         }
       }
    }
  }

  Future<void> _fetchWalletBalance() async {
    setState(() => _isLoadingWallet = true);
    try {
      final response = await _apiService.getCustomerWalletSummary();
      if (!mounted) return;
      setState(() {
        _walletAvailableBalance = (response?['availableBalance'] as num?)
            ?.toDouble();
        _isLoadingWallet = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingWallet = false);
    }
  }

  @override
  void dispose() {
    _slotStatusChangedSub?.cancel();
    _holdTimer?.cancel();
    _cancelCurrentHold();
    _pageController.dispose();
    super.dispose();
  }

  ShapeMethodConfigModel? get _initialShapeMethod {
    final id = widget.shapeMethodConfigId;
    if (id == null) return null;
    return ShapeMethodConfigModel(
      shapeMethodConfigId: id,
      nailShapeId: widget.nail.nailShapeId ?? 0,
      nailShapeName: widget.nail.shapeName,
      name: widget.shapeMethodName ?? 'Phuong phap tao form',
      price: (widget.shapeMethodPrice ?? 0).toDouble(),
      duration: widget.shapeMethodDuration ?? 0,
      status: 'Active',
    );
  }

  int? get _selectedShapeMethodConfigId =>
      _selectedShapeMethod?.shapeMethodConfigId;

  Map<String, int> get _groupedServicesMap {
    final map = <String, int>{};
    for (final id in _selectedExtraServices.whereType<String>()) {
      map[id] = (map[id] ?? 0) + 1;
    }
    return map;
  }

  int get _estimatedTotalPrice {
    final basePrice = widget.nail.customerNailPrice.round();
    final shapePrice = (_selectedShapeMethod?.price ?? 0).round();
    int extraPrice = 0;
    for (final id in _selectedExtraServices.whereType<String>()) {
      final matches = _services.where(
        (s) => (s['serviceId']?.toString() ?? s['id']?.toString()) == id,
      );
      if (matches.isNotEmpty) {
        final p = matches.first['price'] ?? matches.first['basePrice'];
        if (p is num) extraPrice += p.round();
      }
    }
    return basePrice  + shapePrice + extraPrice;
  }

  int get _estimatedTotalDuration {
    final customDur = widget.nail.estimatedDuration ?? 0;
    final shapeDur = _selectedShapeMethod?.duration ?? 0;
    int extraDur = 0;
    for (final id in _selectedExtraServices.whereType<String>()) {
      final matches = _services.where(
        (s) => (s['serviceId']?.toString() ?? s['id']?.toString()) == id,
      );
      if (matches.isNotEmpty) {
        final d = matches.first['duration'] ?? matches.first['estimatedTime'];
        if (d is num) extraDur += d.round();
      }
    }
    return customDur + shapeDur + extraDur;
  }

  List<int>? get _selectedPromotionIds {
    if (_selectedPromotions.isEmpty) return null;
    return _selectedPromotions
        .map((promotion) => promotion.promotionId)
        .toList();
  }

  List<Map<String, dynamic>> get _discountBreakdown {
    final raw =
        _priceReview?['discountBreakdown'] ?? _priceReview?['discounts'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((discount) => Map<String, dynamic>.from(discount))
        .toList();
  }

  String get _priceReviewRequestKey {
    final serviceEntries = _groupedServicesMap.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final promotionIds = (_selectedPromotionIds ?? const <int>[]).toList()
      ..sort();
    return [
      widget.nail.customerNailRequestId,
      _selectedShapeMethodConfigId?.toString() ?? '',
      serviceEntries.map((entry) => '${entry.key}:${entry.value}').join(','),
      promotionIds.join(','),
    ].join('|');
  }

  Future<List<ShapeMethodConfigModel>> _loadShapeMethods() async {
    final shapeId = widget.nail.nailShapeId;
    if (shapeId == null || shapeId <= 0) {
      _reviewPrice();
      return const [];
    }
    final methods = await getIt<NailVariantRepository>()
        .getShapeMethodConfigsByNailShape(shapeId);
    final activeMethods = methods
        .where((method) => method.status.toLowerCase() != 'inactive')
        .toList();

    if (mounted &&
        activeMethods.isNotEmpty &&
        (_selectedShapeMethod == null ||
            !activeMethods.any(
              (method) =>
                  method.shapeMethodConfigId == _selectedShapeMethodConfigId,
            ))) {
      setState(() => _selectedShapeMethod = activeMethods.first);
    }

    if (mounted) _reviewPrice();

    return activeMethods;
  }

  Future<void> _fetchServices() async {
    try {
      final services = await _apiService.getServices();
      if (!mounted) return;
      setState(() {
        _services = services;
        _isLoadingServices = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingServices = false);
      _showSnackBar('Loi tai dich vu: $e');
    }
  }

  Future<void> _fetchPromotions() async {
    setState(() => _isLoadingPromotions = true);
    try {
      final vouchers = await _promotionApiService.getMyWalletVouchers();
      if (!mounted) return;
      setState(() {
        _promotions = vouchers
            .where(
              (voucher) =>
                  voucher.isValidForUse &&
                  voucher.hasUsagesLeft &&
                  !voucher.isExpired,
            )
            .toList();
        _isLoadingPromotions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPromotions = false);
      _showSnackBar('Lỗi tải voucher trong ví: $e');
    }
  }

  Future<void> _reviewPrice() async {
    final customerNailRequestId = widget.nail.customerNailRequestId;
    if (customerNailRequestId.isEmpty) return;
    final requestKey = _priceReviewRequestKey;
    if (_priceReview != null && _priceReviewKey == requestKey) return;
    if (_inFlightPriceReviewKey == requestKey && _inFlightPriceReview != null) {
      return _inFlightPriceReview;
    }

    setState(() => _isReviewingPrice = true);
    final reviewFuture = () async {
      final review = await _apiService.reviewCustomNailBookingPrice(
        customerNailRequestId: customerNailRequestId,
        groupedExtraServices: _groupedServicesMap,
        shapeMethodConfigId: _selectedShapeMethodConfigId,
        selectedPromotionIds: _selectedPromotionIds,
      );
      if (!mounted) return;
      if (_priceReviewRequestKey != requestKey) return;
      setState(() {
        _priceReview = review;
        _priceReviewKey = requestKey;
      });
    }();

    _inFlightPriceReviewKey = requestKey;
    _inFlightPriceReview = reviewFuture;

    try {
      await reviewFuture;
    } catch (e) {
      debugPrint('Failed to review custom nail booking price: $e');
    } finally {
      if (_inFlightPriceReviewKey == requestKey) {
        _inFlightPriceReviewKey = null;
        _inFlightPriceReview = null;
        if (mounted) setState(() => _isReviewingPrice = false);
      }
    }
  }

  Future<void> _fetchTimeSlots() async {
    if (_selectedDate == null) return;

    final artistId = widget.nail.nailArtistId ?? '';
    if (artistId.isEmpty) {
      _showSnackBar('Khong tim thay tho da duyet.');
      return;
    }

    final String? previousSelectedTime = _selectedTime;
    setState(() {
      _isLoadingTimes = true;
    });

    try {
      final times = await _apiService.getArtistAvailableSlots(
        artistId,
        _formatBookingDate(_selectedDate!),
        bookingItems: _buildBookingItems(),
      );
      if (!mounted) return;
      final filtered = _apiService.filterSlotsByOperatingHours(
        slots: times,
        salon: widget.nail.salonData,
        date: _selectedDate,
      );
      setState(() {
        _timeSlots = filtered;
        if (previousSelectedTime != null &&
            filtered.any(
              (s) =>
                  s['startTime'] == previousSelectedTime ||
                  s['time'] == previousSelectedTime,
            )) {
          _selectedTime = previousSelectedTime;
        } else {
          _selectedTime = null;
        }
        _isLoadingTimes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingTimes = false);
      _showSnackBar('Loi tai gio ranh: $e');
    }
  }

  Future<void> _executeBooking() async {
    AuthGuard.check(context, () async {
      if (_isSubmitting) return;
      setState(() => _isSubmitting = true);

      try {
        final paymentData = await _paymentApiService.createPaymentForRequest(
          _buildBookingRequestPayload(holdToken: _holdToken),
        );

        if (!mounted) return;
        _holdTimer?.cancel();
        _holdToken = null;
        _isHolding = false;
        _holdRemainingSeconds = 0;

        final status = paymentData['status']?.toString().toUpperCase() ?? '';
        final qrCode = paymentData['qrCode']?.toString() ?? '';
        final paymentUrl = paymentData['paymentUrl']?.toString() ?? '';

        if (status == 'PAID' ||
            status == 'SUCCESS' ||
            (qrCode.isEmpty && paymentUrl.isEmpty)) {
          context.go('/payment-success', extra: paymentData);
        } else {
          context.go('/payment-qr', extra: paymentData);
        }
      } catch (e) {
        if (mounted) {
          _showSnackBar(e.toString().replaceAll('Exception: ', 'Loi: '));
        }
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    });
  }

  Future<bool> _createHoldForSummary() async {
    // Fix bug: trước đây khi user back từ step tổng quan (3) về step chọn
    // ngày/giờ (2) rồi chọn lại giờ, _handleTimeChanged đã tạo hold token
    // mới → đến khi bấm "Tiếp tục" sang step tổng quan, _createHoldForSummary
    // lại gọi _cancelCurrentHold() + _createHold() → backend log cho thấy
    // 2 lần DELETE hold-slot + 1 lần POST hold-slot (cancel hold cũ trước
    // khi tạo mới mặc dù hold cũ vẫn còn hiệu lực).
    //
    // Sau fix: nếu đã có hold token còn hiệu lực (_isHolding == true +
    // _holdToken != null + remaining > 0) thì GIỮ NGUYÊN, không tạo lại.
    // Chỉ tạo hold mới khi:
    //  - Chưa có token (_holdToken == null).
    //  - Hold đã hết hạn local (_isHolding == false).
    //  - User đổi ngày / shape method / giờ (đã cancel thủ công ở đó).
    if (_isHolding && _holdToken != null && _holdRemainingSeconds > 0) {
      // Đảm bảo timer vẫn chạy (có thể bị dispose khi rebuild widget).
      if (_holdTimer == null || !_holdTimer!.isActive) {
        _startHoldTimer(_holdToken!);
      }
      return true;
    }

    try {
      final hold = await _createHold();
      final token = hold?['holdToken']?.toString();
      if (token == null || token.isEmpty) {
        _showHoldFailureMessage(
          'Không thể giữ khung giờ này. Vui lòng chọn giờ khác.',
        );
        return false;
      }
      if (mounted) {
        final remaining = (hold?['remainingSeconds'] as num?)?.toInt() ?? 300;
        setState(() {
          _holdToken = token;
          _holdRemainingSeconds = remaining;
          _isHolding = true;
        });
        _startHoldTimer(token);
      }
      return true;
    } catch (e) {
      // API trả về 400 (ví dụ: "Thợ đã đầy lịch trong khoảng thời gian này...")
      // → hiển thị message server để user biết lý do thay vì message chung chung.
      debugPrint('holdSlot failed: $e');
      _showHoldFailureMessage('Rất tiếc, khung giờ này vừa có người đặt. Vui lòng chọn giờ khác.');
      return false;
    }
  }

  /// Hiển thị lỗi hold-slot từ server.
  /// - Chỉ snackbar, KHÔNG reload slot, KHÔNG reset state (giữ nguyên
  ///   lựa chọn giờ của user để họ chỉ cần đổi sang giờ khác).
  void _showHoldFailureMessage(String rawMessage) {
    if (!mounted) return;
    final String msg = _extractServerMessage(rawMessage);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.event_busy_rounded, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(msg, style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  /// Extract message từ exception. AppException.toString() trả về
  /// `message` gốc từ server. Fallback chỉ dùng khi exception rỗng/null.
  String _extractServerMessage(String rawMessage) {
    String msg = rawMessage.trim();
    if (msg.isEmpty ||
        msg.toLowerCase() == 'null' ||
        msg.toLowerCase() == 'exception') {
      return 'Không thể giữ khung giờ này. Vui lòng chọn giờ khác.';
    }
    return msg;
  }

  Future<Map<String, dynamic>?> _createHold() async {
    final salonId = widget.nail.salonId;
    final artistId = widget.nail.nailArtistId ?? '';
    if (salonId.isEmpty || artistId.isEmpty || _selectedDate == null) {
      return null;
    }

    return _apiService.holdSlot(
      salonId: salonId,
      nailArtistId: artistId,
      bookingDate: _formatBookingDate(_selectedDate!),
      startTime: _normalizedSelectedTime,
      bookingItems: _buildBookingItems(),
    );
  }

  Future<void> _cancelCurrentHold() async {
    final token = _holdToken;
    _holdTimer?.cancel();
    _holdToken = null;
    _isHolding = false;
    _holdRemainingSeconds = 0;
    if (token == null || token.isEmpty) return;
    await _apiService.cancelHoldSlot(token);
  }

  void _startHoldTimer(String token) {
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted || _holdToken != token) {
        timer.cancel();
        return;
      }
      if (_holdRemainingSeconds <= 1) {
        timer.cancel();
        setState(() {
          _holdToken = null;
          _isHolding = false;
          _holdRemainingSeconds = 0;
          _selectedTime = null;
          _priceReview = null;
        });
        _showSnackBar('Thời gian giữ chỗ đã hết. Vui lòng chọn lại khung giờ.');
        if (_currentStep > 1) {
          _pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
      } else {
        setState(() => _holdRemainingSeconds--);
      }
    });
  }

  Widget _buildHoldCountdownBanner() {
    if (!_isHolding) return const SizedBox.shrink();
    final minutes = (_holdRemainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_holdRemainingSeconds % 60).toString().padLeft(2, '0');
    final isUrgent = _holdRemainingSeconds <= 60;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isUrgent ? Colors.red.shade600 : Colors.orange.shade700,
      child: Row(
        children: [
          const Icon(Icons.lock_clock, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isUrgent
                  ? S.of(context).reservationMayExpireIn(minutes, seconds)
                  : S.of(context).slotHeldRemaining(minutes, seconds),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _buildBookingRequestPayload({String? holdToken}) {
    return {
      'salonId': widget.nail.salonId,
      'bookingDate': _formatBookingDate(_selectedDate!),
      'startTime': _normalizedSelectedTime,
      'nailArtistId': widget.nail.nailArtistId,
      'holdToken': holdToken,
      'bookingItems': _buildBookingItems(),
      'selectedPromotionIds': _selectedPromotionIds,
      'useWalletBalance': _useWalletBalance,
    };
  }

  List<Map<String, dynamic>> _buildBookingItems() {
    return [
      {
        'customerNailRequestId': widget.nail.customerNailRequestId,
        if (_selectedShapeMethodConfigId != null)
          'shapeMethodConfigId': _selectedShapeMethodConfigId,
        'quantity': 1,
      },
      ..._groupedServicesMap.entries.map(
        (entry) => {'serviceId': entry.key, 'quantity': entry.value},
      ),
    ];
  }

  String get _normalizedSelectedTime {
    final time = _selectedTime ?? '';
    return time.length == 5 ? '$time:00' : time;
  }

  String _formatBookingDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-${d}T00:00:00';
  }

  String _serviceId(Map<String, dynamic> service) {
    return service['serviceId']?.toString() ?? service['id']?.toString() ?? '';
  }

  String _serviceName(Map<String, dynamic> service) {
    return service['serviceName']?.toString() ??
        service['name']?.toString() ??
        '';
  }

  String _serviceNameById(String? serviceId) {
    if (serviceId == null) return '';
    final matches = _services.whereType<Map>().where((service) {
      return _serviceId(Map<String, dynamic>.from(service)) == serviceId;
    });
    if (matches.isEmpty) return serviceId;
    final name = _serviceName(Map<String, dynamic>.from(matches.first));
    return name.isEmpty ? serviceId : name;
  }

  int _servicePriceById(String? serviceId) {
    if (serviceId == null) return 0;
    final matches = _services.whereType<Map>().where((service) {
      return _serviceId(Map<String, dynamic>.from(service)) == serviceId;
    });
    if (matches.isEmpty) return 0;
    final service = Map<String, dynamic>.from(matches.first);
    final price = service['price'] ?? service['basePrice'];
    if (price is num) return price.round();
    return int.tryParse(price?.toString() ?? '') ?? 0;
  }

  void _handleServiceChanged(List<String?> services) {
    // Fix bug: trước đây `_handleServiceChanged` gọi `_cancelCurrentHold()` +
    // clear giờ + clear timeSlots khi user đính kèm dịch vụ (ngâm chân thảo
    // mộc, cắt da tay...) ở step 1. Điều này khiến user đã tạo hold token
    // cho slot ở step 2 rồi mà back về step 1 thêm dịch vụ thì mất luôn slot.
    //
    // Sau fix: dịch vụ đi kèm là addon SONG SONG với dịch vụ chính, KHÔNG
    // ảnh hưởng đến duration slot đã chọn. Hold token vẫn hợp lệ và nên
    // được giữ nguyên. Khi user forward trở lại step 2, nếu chưa chọn giờ
    // hoặc đổi ngày thì _fetchTimeSlots() sẽ tự load lại.
    setState(() {
      _selectedExtraServices = services;
      _priceReview = null;
    });
    _reviewPrice();
  }

  Future<void> _handleBackAction() async {
    // Fix bug: trước đây khi user back từ step 3 (tổng quan) về step 2
    // (chọn ngày/giờ), hệ thống gọi `_cancelCurrentHold()` → xóa hold token
    // và gọi API `cancelHoldSlot` lên backend. Điều này không đúng vì:
    //  - User chỉ muốn xem lại ngày/giờ đã chọn, KHÔNG có ý định hủy booking.
    //  - Khi bấm "Tiếp tục" trở lại step 3, hệ thống phải tạo hold mới
    //    → tốn 1 lượt API hold-slot + có thể không còn slot đó nữa.
    //
    // Sau fix: KHÔNG cancel hold khi back giữa các step. Hold token chỉ bị
    // huỷ khi:
    //  - User đổi service/shape-method/date/time (line 508, 701, 742, 757).
    //  - Hold timer hết hạn (line 383).
    //  - User thoát khỏi trang custom nail booking (line 89 dispose()).
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.pop();
    }
  }

  Future<void> _handleNextAction() async {
    // Fix bug: trước đây button "Tiếp tục" chỉ disable khi `_isSubmitting`
    // (chỉ true ở `_executeBooking`). Khi user bấm "Tiếp tục" ở step 2 (chọn
    // ngày/giờ) → step 3 (tổng quan), hệ thống gọi `_createHoldForSummary`
    // (API hold-slot mất 1–3 giây) mà KHÔNG có loading. User dễ bấm nhầm
    // nhiều lần → gọi API hold-slot trùng lặp.
    //
    // Sau fix: set `_isSubmitting = true` ngay từ đầu khi cần xử lý async
    // (hold-slot hoặc submit booking). Button sẽ disable + spinner ngay.
    if (_isSubmitting) return; // chống bấm đúp khi đang xử lý

    if (_currentStep == 0 && _selectedExtraServices.contains(null)) {
      _showSnackBar('Vui long chon hoac xoa dich vu dang bo trong.');
      return;
    }
    if (_currentStep == 1) {
      if (_selectedDate == null) {
        _showSnackBar('Vui lòng chọn ngày đặt lịch!');
        return;
      }
      if (_selectedTime == null) {
        _showSnackBar('Vui lòng chọn khung giờ rảnh!');
        return;
      }
    }

    if (_currentStep < 2) {
      // Bước sang step kế tiếp. Nếu từ step 2 (index 1) → step 3 (index 2)
      // thì cần tạo hold-slot (gọi API có thể mất 1-3s) → bật loading.
      if (_currentStep == 1) {
        setState(() => _isSubmitting = true);
        try {
          final held = await _createHoldForSummary();
          if (!held) {
            if (mounted) setState(() => _isSubmitting = false);
            return;
          }
          _pageController.nextPage(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        } finally {
          if (mounted) setState(() => _isSubmitting = false);
        }
      } else {
        _pageController.nextPage(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      }
    } else {
      // Step 3 (index 2): thanh toán → _executeBooking tự set _isSubmitting.
      _executeBooking();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final customNailMappedData = {
      'name': widget.nail.name,
      'price': widget.nail.customerNailPrice,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.primaryDark,
          ),
          onPressed: _handleBackAction,
        ),
        title: Text(
          S.of(context).bookCustomNailTitle,
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
      body: _isLoadingServices
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                SleekBookingStepIndicator(
                  currentStep: _currentStep,
                  steps: _bookingSteps,
                ),
                _buildHoldCountdownBanner(),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (idx) {
                      setState(() => _currentStep = idx);
                      if (idx == 2 && _priceReview == null) {
                        _reviewPrice();
                      }
                    },
                    children: [
                      _buildServiceStep(customNailMappedData),
                      _buildScheduleStep(),
                      _buildSummaryStep(),
                    ],
                  ),
                ),
                _buildFooter(),
              ],
            ),
    );
  }

  Widget _buildServiceStep(Map<String, dynamic> customNailMappedData) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingServiceSelection(
            nailData: customNailMappedData,
            services: _services,
            selectedExtraServices: _selectedExtraServices,
            onChanged: _handleServiceChanged,
          ),
          const SizedBox(height: 24),
          _buildShapeMethodSelector(),
        ],
      ),
    );
  }

  Widget _buildShapeMethodSelector() {
    final future = _shapeMethodsFuture;
    if (future == null) return const SizedBox.shrink();

    return FutureBuilder<List<ShapeMethodConfigModel>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 40,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final methods = snapshot.data ?? const <ShapeMethodConfigModel>[];
        if (methods.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Phương pháp tạo form',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 12),
            ...methods.map((method) {
              final selected =
                  _selectedShapeMethodConfigId == method.shapeMethodConfigId;
              // Wrap Material để RadioListTile hiện ink ripple bình thường
              return Material(
                type: MaterialType.transparency,
                child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withOpacity(0.06)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: selected
                          ? AppColors.primary
                          : AppColors.borderLight,
                    ),
                  ),
                  child: RadioListTile<int>(
                    value: method.shapeMethodConfigId,
                    groupValue: _selectedShapeMethodConfigId,
                    onChanged: (_) {
                      _cancelCurrentHold();
                      setState(() {
                        _selectedShapeMethod = method;
                        _priceReview = null;
                      });
                      _reviewPrice();
                    },
                    title: Text(
                      method.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      DurationFormatter.format(
                        method.duration,
                        context: context,
                      ),
                    ),
                    secondary: Text(
                      PriceFormatter.format(method.price),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    activeColor: AppColors.primary,
                    selectedTileColor: Colors.transparent,
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  Widget _buildScheduleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAssignedArtistCard(),
          BookingDateSelection(
            selectedDate: _selectedDate,
            onDateChanged: (date) {
              _cancelCurrentHold();
              setState(() => _selectedDate = date);
              _fetchTimeSlots();
            },
          ),
          const SizedBox(height: 24),
          BookingTimeSelection(
            timeSlots: _timeSlots,
            isLoading: _isLoadingTimes,
            selectedTime: _selectedTime,
            canSelect: _selectedDate != null,
            selectedDate: _selectedDate,
            salonId: widget.nail.salonId,
            artistId: widget.nail.nailArtistId,
            waitlistItems: _buildBookingItems(),
            onTimeChanged: (time) {
              _cancelCurrentHold();
              setState(() => _selectedTime = time);
            },
          ),
        ],
      ),
    );
  }

  int? get _reviewSubtotal {
    final value = _priceReview?['price'];
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  Widget _buildSummaryStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBookingSummaryCard(),
          const SizedBox(height: 16),
          _buildPromotionsAndWalletCard(),
          const SizedBox(height: 16),
          _buildPaymentDetailsCard(),
        ],
      ),
    );
  }

  Widget _buildBookingSummaryCard() {
    final branchName =
        widget.nail.salonData?['name']?.toString() ??
        widget.nail.salonData?['salonName']?.toString() ??
        'Chi nhánh Salon';
    final dateStr = _selectedDate == null
        ? ''
        : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}';
    final timeStr = _selectedTime == null ? '' : _selectedTime!.substring(0, 5);
    final dateTimeText = dateStr.isEmpty ? '--' : '$dateStr • $timeStr';
    final artistName = widget.nail.stylistName.isNotEmpty
        ? widget.nail.stylistName
        : 'Thợ phụ trách';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 18,
                  color: Color(0xFFE02B6D),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  branchName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () {
                  _pageController.animateToPage(
                    1,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Đổi lịch',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE02B6D),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Color(0xFFE02B6D),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF5F5F5)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.access_time_filled_rounded,
                        size: 16,
                        color: Color(0xFFE02B6D),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lịch hẹn',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateTimeText,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFF0F0F0)),
              const SizedBox(width: 12),
              Expanded(
                child: Row(
                  children: [
                    const CircleAvatar(
                      radius: 14,
                      backgroundColor: Color(0xFFFFF0F5),
                      child: Icon(
                        Icons.person_rounded,
                        size: 16,
                        color: Color(0xFFE02B6D),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thợ phụ trách',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            artistName,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionsAndWalletCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildVoucherRow(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF5F5F5)),
          ),
          _buildWalletToggleRow(),
        ],
      ),
    );
  }

  void _handlePromotionsChanged(List<WalletVoucherModel> list) {
    setState(() {
      _selectedPromotions = list;
      _priceReview = null;
    });
    _reviewPrice();
  }

  Widget _buildVoucherRow() {
    final hasSelected = _selectedPromotions.isNotEmpty;
    final count = _promotions.length;
    final selectedVoucher = hasSelected ? _selectedPromotions.first : null;

    return GestureDetector(
      onTap: _isLoadingPromotions
          ? null
          : () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => BookingPromotionSheet(
                  selectedPromotions: _selectedPromotions,
                  onConfirm: _handlePromotionsChanged,
                ),
              );
            },
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF0F5),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.confirmation_number_rounded,
              size: 20,
              color: Color(0xFFE02B6D),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Voucher giảm giá',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (count > 0 && !hasSelected) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFD1DC)),
                        ),
                        child: Text(
                          '$count có sẵn',
                          style: const TextStyle(
                            color: Color(0xFFE02B6D),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                if (_isLoadingPromotions)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: const SizedBox(
                      height: 4,
                      width: 60,
                      child: LinearProgressIndicator(
                        backgroundColor: Color(0xFFFCE4EC),
                        valueColor: AlwaysStoppedAnimation(Color(0xFFE02B6D)),
                      ),
                    ),
                  )
                else if (hasSelected)
                  Text(
                    '${selectedVoucher!.promotionName} (-${selectedVoucher.displayDiscount})',
                    style: const TextStyle(
                      color: Color(0xFFE02B6D),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    count > 0 ? 'Chọn voucher' : 'Chưa chọn voucher',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          if (hasSelected)
            IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Color(0xFFE02B6D),
                size: 20,
              ),
              onPressed: () => _handlePromotionsChanged([]),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFD1DC)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Text(
                    'Chọn',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE02B6D),
                    ),
                  ),
                  SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFE02B6D),
                    size: 16,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildWalletToggleRow() {
    final balance = _walletAvailableBalance;
    final hasBalance = balance != null && balance > 0;

    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: const BoxDecoration(
            color: Color(0xFFFFF0F5),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.account_balance_wallet_rounded,
            size: 20,
            color: Color(0xFFE02B6D),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Dùng số dư Ví Nailify',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 3),
              if (_isLoadingWallet)
                ClipRRect(
                  borderRadius: BorderRadius.circular(3),
                  child: const SizedBox(
                    height: 4,
                    width: 60,
                    child: LinearProgressIndicator(
                      backgroundColor: Color(0xFFFCE4EC),
                      valueColor: AlwaysStoppedAnimation(Color(0xFFE02B6D)),
                    ),
                  ),
                )
              else
                Text(
                  hasBalance
                      ? 'Số dư: ${PriceFormatter.format(balance.round())}'
                      : 'Số dư trống',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: hasBalance
                        ? Colors.grey.shade700
                        : Colors.grey.shade400,
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 30,
          child: FittedBox(
            fit: BoxFit.contain,
            child: Switch(
              value: _useWalletBalance,
              onChanged: hasBalance && !_isLoadingWallet
                  ? (val) {
                      setState(() {
                        _useWalletBalance = val;
                        _priceReview = null;
                      });
                      _reviewPrice();
                    }
                  : null,
              activeThumbColor: Colors.white,
              activeTrackColor: const Color(0xFFE02B6D),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFF0E6EA),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentDetailsCard() {
    final reviewTotal = _priceReview?['totalPrice'];
    final bool isLoading = _isReviewingPrice && _priceReview == null;
    final int totalPrice = reviewTotal is num
        ? reviewTotal.round()
        : isLoading
        ? 0
        : int.tryParse(reviewTotal?.toString() ?? '') ?? _estimatedTotalPrice;
    final int subtotalPrice = _reviewSubtotal ?? _estimatedTotalPrice;

    final depositInfo = PriceFormatter.getDepositInfo(
      widget.nail.salonData?['depositConfig'],
      totalPrice,
    );
    final initialDepositAmount = depositInfo['amount'] as int;

    final walletDeduction =
        (_useWalletBalance &&
            _walletAvailableBalance != null &&
            _walletAvailableBalance! > 0)
        ? (_priceReview?['walletDiscount'] is num
              ? (_priceReview!['walletDiscount'] as num).round()
              : (_walletAvailableBalance! < initialDepositAmount
                    ? _walletAvailableBalance!.round()
                    : initialDepositAmount))
        : 0;

    final int finalTotalPrice = totalPrice;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: Color(0xFFE02B6D),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  S.of(context).bookingPaymentDetails,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Georgia',
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              if (_isReviewingPrice)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFE02B6D),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          PaymentDetailTable(items: _paymentTableItems),
          const SizedBox(height: 14),

          CustomPaint(
            size: const Size(double.infinity, 1),
            painter: _HorizontalDashedLinePainter(
              color: const Color(0xFFE5E7EB),
            ),
          ),
          const SizedBox(height: 14),

          _buildInvoiceRow('Tạm tính', subtotalPrice, isNegative: false),

          for (final discount in _discountBreakdown)
            _buildDiscountInvoiceRow(discount),

          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 14),

          isLoading
              ? _buildLoadingPriceRow('Tổng thanh toán')
              : Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Tổng thanh toán',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        PriceFormatter.format(finalTotalPrice),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE02B6D),
                          fontSize: 20,
                        ),
                      ),
                    ],
                  ),
                ),

          if (widget.nail.salonData != null && !isLoading) ...[
            const SizedBox(height: 4),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 14),
            _buildDepositDetails(
              totalPrice,
              initialDepositAmount,
              walletDeduction,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDepositDetails(
    int totalPrice,
    int initialDepositAmount,
    int walletDeduction,
  ) {
    final depositInfo = PriceFormatter.getDepositInfo(
      widget.nail.salonData?['depositConfig'],
      totalPrice,
    );
    final depositConfigText = depositInfo['displayText'] as String;
    final depositAmountToPay = (initialDepositAmount - walletDeduction).clamp(
      0,
      initialDepositAmount,
    );
    final remainingAmountAtSalon = (totalPrice - walletDeduction).clamp(
      0,
      totalPrice,
    );

    return Column(
      children: [
        _buildInvoiceRowWithText(
          S.of(context).bookingDepositRatioLabel,
          depositConfigText,
          isMuted: true,
        ),
        if (_useWalletBalance && walletDeduction > 0) ...[
          const SizedBox(height: 8),
          _buildInvoiceRow(
            'Khấu trừ Ví Nailify (cọc)',
            walletDeduction,
            isNegative: true,
          ),
        ],
        const SizedBox(height: 8),
        _buildInvoiceRow(
          S.of(context).bookingDepositAmountLabel,
          depositAmountToPay,
          isNegative: false,
          isBold: true,
          isPrimaryColor: true,
        ),
        if (_useWalletBalance && walletDeduction > 0) ...[
          const SizedBox(height: 8),
          _buildInvoiceRowWithText(
            'Còn lại trả tại Salon:',
            PriceFormatter.format(remainingAmountAtSalon),
            isMuted: true,
            isBold: true,
          ),
        ],
      ],
    );
  }

  Widget _buildInvoiceRow(
    String label,
    num amount, {
    required bool isNegative,
    bool isBold = false,
    bool isPrimaryColor = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14.5 : 13.5,
              color: isNegative
                  ? Colors.grey.shade700
                  : (isBold ? AppColors.textPrimary : Colors.grey.shade600),
              fontWeight: isBold
                  ? FontWeight.bold
                  : (isNegative ? FontWeight.w500 : FontWeight.normal),
            ),
          ),
          Text(
            isNegative
                ? '-${PriceFormatter.format(amount)}'
                : PriceFormatter.format(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: (isNegative || isPrimaryColor)
                  ? const Color(0xFFE02B6D)
                  : AppColors.textPrimary,
              fontSize: isBold ? 17 : 13.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceRowWithText(
    String label,
    String valueText, {
    bool isMuted = false,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isBold ? 14 : 13.5,
              color: isMuted ? Colors.grey.shade600 : AppColors.textPrimary,
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            valueText,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w600,
              color: isBold ? AppColors.textPrimary : Colors.grey.shade700,
              fontSize: isBold ? 14 : 13.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountInvoiceRow(Map<String, dynamic> discount) {
    final name = discount['name']?.toString() ?? 'Ưu đãi';
    final description = discount['description']?.toString();
    final isAutoApplied = discount['isAutoApplied'] == true;
    final amount = discount['amount'];
    final amountDisplay = discount['amountDisplay']?.toString();
    final rawDisplay = (amountDisplay?.isNotEmpty == true)
        ? amountDisplay!
        : (amount != null ? PriceFormatter.format(amount) : '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAutoApplied) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE02B6D).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFE02B6D).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'Tự động áp dụng',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE02B6D),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                _formatDiscountDisplay(rawDisplay),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Color(0xFFE02B6D),
                ),
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              description,
              style: TextStyle(
                fontSize: 11.5,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildLoadingPriceRow(String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Đang tính giá...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<PaymentTableItem> get _paymentTableItems {
    final items = <PaymentTableItem>[];
    final shape = _selectedShapeMethod;
    final shapeExtra = (shape != null && shape.price > 0) ? shape.price : 0;

    if (widget.nail.customerNailPrice > 0) {
      items.add(
        PaymentTableItem(
          name: 'Giá mẫu',
          quantity: 1,
          unitPrice: widget.nail.customerNailPrice + shapeExtra,
        ),
      );
    }

    if (widget.nail.price > 0) {
      items.add(
        PaymentTableItem(
          name: 'Phí custom',
          quantity: 1,
          unitPrice: widget.nail.price,
        ),
      );
    }

    for (final entry in _groupedServicesMap.entries) {
      final unit = _servicePriceById(entry.key);
      items.add(
        PaymentTableItem(
          name: _serviceNameById(entry.key),
          quantity: entry.value,
          unitPrice: unit,
        ),
      );
    }
    return items;
  }

  String _formatDiscountDisplay(String value) {
    var text = value.trim();
    if (text.isEmpty) return text;
    text = text.replaceAll(RegExp(r'^-+'), '');
    text = '-$text';
    final lower = text.toLowerCase();
    if (lower.contains('đ') || lower.contains('vnd')) return text;
    return '$text VNĐ';
  }

  Widget _buildFooter() {
    final bool isFirstStep = _currentStep == 0;
    final int totalP = _estimatedTotalPrice;
    final int totalD = _estimatedTotalDuration;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((_currentStep == 0 || _currentStep == 1) &&
                (totalP > 0 || totalD > 0)) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    S.of(context).bookingEstimatedTotal,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        PriceFormatter.format(totalP),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      if (totalD > 0) ...[
                        Text(
                          ' • ',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DurationFormatter.format(totalD, context: context),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            isFirstStep
                ? SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: LinearGradient(
                          colors: _isSubmitting
                              ? [Colors.grey.shade400, Colors.grey.shade500]
                              : [
                                  const Color(0xFFFF4081),
                                  const Color(0xFFD81B60),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          if (!_isSubmitting)
                            BoxShadow(
                              color: const Color(
                                0xFFD81B60,
                              ).withValues(alpha: 0.38),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _handleNextAction,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Tiếp tục',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      TextButton.icon(
                        onPressed: _isSubmitting ? null : _handleBackAction,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        label: Text(
                          S.of(context).bookingBackBtn,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            gradient: LinearGradient(
                              colors: _isSubmitting
                                  ? [Colors.grey.shade400, Colors.grey.shade500]
                                  : [
                                      const Color(0xFFFF4081),
                                      const Color(0xFFD81B60),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              if (!_isSubmitting)
                                BoxShadow(
                                  color: const Color(
                                    0xFFD81B60,
                                  ).withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _handleNextAction,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        _currentStep == 2
                                            ? Icons.lock_rounded
                                            : Icons.arrow_forward_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _currentStep == 2
                                            ? S.of(context).bookingPayBtn
                                            : S.of(context).bookingContinueBtn,
                                        style: const TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  Widget _buildAssignedArtistCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF5F8),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFD1E3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.face_retouching_natural, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Thợ đã duyệt',
                  style: TextStyle(
                    color: Color(0xFFC44569),
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  widget.nail.stylistName,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HorizontalDashedLinePainter extends CustomPainter {
  final Color color;
  const _HorizontalDashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    const dashWidth = 4.0;
    const dashSpace = 3.0;
    double startX = 0.0;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, 0), Offset(startX + dashWidth, 0), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalDashedLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
