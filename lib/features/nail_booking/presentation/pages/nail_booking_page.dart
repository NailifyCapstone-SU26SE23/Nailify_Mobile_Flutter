import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../generated/l10n.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/signalr_service.dart';
import '../../../../core/network/signalr_events.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/retry_helper.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../nails/data/models/nail_variant_model.dart';
import '../../../nails/data/repositories/nail_variant_repository.dart';
import '../../data/datasources/booking_api_service.dart';
import '../../data/datasources/payment_api_service.dart';
import '../../data/datasources/promotion_api_service.dart';
import '../../data/models/booking_mock_data.dart';
import '../../data/models/wallet_voucher_model.dart';
import '../widgets/booking_date_selection.dart';
import '../widgets/booking_service_selection.dart';
import '../widgets/booking_time_selection.dart';
import '../widgets/payment_detail_table.dart';
import '../widgets/branch_selection_list.dart';
import '../widgets/artist_selection_list.dart';
import '../widgets/sleek_booking_step_indicator.dart';
import '../widgets/booking_promotion_sheet.dart';

class NailBookingPage extends StatefulWidget {
  final Map<String, dynamic>? nailData;

  const NailBookingPage({super.key, this.nailData});

  @override
  State<NailBookingPage> createState() => _NailBookingPageState();
}

class _NailBookingPageState extends State<NailBookingPage> {
  late final PageController _pageController;
  final BookingApiService _apiService = BookingApiService();
  final PaymentApiService _paymentApiService = PaymentApiService();
  final PromotionApiService _promotionApiService = PromotionApiService();

  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _isLoadingSalons = true;
  bool _isLoadingArtists = false;
  bool _isLoadingTimes = false;
  bool _isLoadingPromotions = false;
  final bool _isPromotionExpanded = false;
  bool _isReviewingPrice = false;
  bool _sourceSelectionFallback = false;
  bool _useWalletBalance = false;
  bool _isLoadingWallet = false;
  double? _walletAvailableBalance;

  // ── Load-error fields (để hiển thị retry view khi API fail) ──────
  String? _salonsLoadError;
  String? _timesLoadError;

  String? _holdToken;
  Timer? _holdTimer;
  int _holdRemainingSeconds = 0;
  bool _isHolding = false;
  String? _priceReviewKey;
  String? _inFlightPriceReviewKey;
  Future<void>? _inFlightPriceReview;

  List<dynamic> _salons = [];
  List<dynamic> _services = [];
  List<dynamic> _artists = [];
  List<dynamic> _timeSlots = [];
  List<WalletVoucherModel> _promotions = [];
  Map<String, dynamic>? _priceReview;
  NailVariantModel? _nailVariantDetail;

  Map<String, dynamic>? _selectedBranch;
  List<String?> _selectedExtraServices = [];
  DateTime? _selectedDate;
  Map<String, dynamic>? _selectedStylist;
  String? _selectedTime;
  int? _selectedPromotionId;
  bool _noArtistSelected = false;

  List<Map<String, dynamic>> get _bookingSteps => [
    {
      'title': S.of(context).bookingStepSelectSalon,
      'icon': Icons.storefront_rounded,
    },
    {'title': S.of(context).bookingStepServices, 'icon': Icons.spa_rounded},
    {
      'title': S.of(context).bookingStepBook,
      'icon': Icons.calendar_month_rounded,
    },
    {
      'title': S.of(context).bookingStepArtist,
      'icon': Icons.person_pin_rounded,
    },
    {
      'title': S.of(context).bookingStepCompleted,
      'icon': Icons.check_circle_rounded,
    },
  ];

  StreamSubscription<SlotStatusChangedEvent>? _slotStatusChangedSub;

  @override
  void initState() {
    super.initState();
    _currentStep = _skipSalonArtistSelection ? 1 : 0;
    _pageController = PageController(initialPage: _currentStep);
    _fetchSalons();
    _fetchServices();
    _fetchPromotions();
    _fetchNailVariantDetail();
    _fetchWalletBalance();

    try {
      final signalR = getIt<SignalRService>();
      _slotStatusChangedSub = signalR.onSlotStatusChanged.listen(_onSlotStatusChanged);
    } catch (_) {}
  }

  void _onSlotStatusChanged(SlotStatusChangedEvent event) {
    if (!mounted || _selectedDate == null) return;
    
    final currentSalonId = _selectedBranch?['salonId']?.toString() ?? '';
    if (currentSalonId.isNotEmpty && event.salonId.toLowerCase() != currentSalonId.toLowerCase()) return;
    
    final String currentFormattedDate = _formatBookingDate(_selectedDate!); 
    if (!event.bookingDate.startsWith(currentFormattedDate.split('T')[0])) return;

    final currentArtistId = _noArtistSelected ? '' : (_selectedStylist?['nailArtistId']?.toString() ?? '');
    
    if (_noArtistSelected || event.artistId.isEmpty || event.artistId.toLowerCase() == currentArtistId.toLowerCase()) {
      if (event.action == 'Held' || event.action == 'Released' || event.action == 'Booked') {
        if (_noArtistSelected) {
          _loadSalonSlots();
        } else {
          _fetchTimeSlots();
        }
      }
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

  int get _nailVariantId {
    return int.tryParse(widget.nailData?['id']?.toString() ?? '0') ?? 0;
  }

  int get _nailVariantPrice {
    final price = widget.nailData?['price'];
    if (price is num) return price.round();
    return int.tryParse(price?.toString() ?? '') ?? 0;
  }

  String? get _shapeMethodName {
    final value = widget.nailData?['shapeMethodName']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  int? get _shapeMethodConfigId {
    final value = widget.nailData?['shapeMethodConfigId'];
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String get _sourceSalonId {
    return widget.nailData?['sourceSalonId']?.toString().trim() ?? '';
  }

  String get _sourceArtistId {
    return widget.nailData?['sourceArtistId']?.toString().trim() ?? '';
  }

  bool get _skipSalonArtistSelection =>
      !_sourceSelectionFallback &&
      _sourceSalonId.isNotEmpty &&
      _sourceArtistId.isNotEmpty;

  num get _shapeMethodPrice {
    final value =
        widget.nailData?['shapeMethodPrice'] ??
        widget.nailData?['shapePrice'] ??
        widget.nailData?['shapeMethodConfigPrice'] ??
        (widget.nailData?['selectedShapeMethod'] is Map
            ? widget.nailData!['selectedShapeMethod']['price']
            : null);
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  int get _shapeMethodDuration {
    final value =
        widget.nailData?['shapeMethodDuration'] ??
        widget.nailData?['shapeDuration'] ??
        (widget.nailData?['selectedShapeMethod'] is Map
            ? widget.nailData!['selectedShapeMethod']['duration']
            : null);
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  int get _selectedExtraServicesTotal {
    return _selectedExtraServices.whereType<String>().fold<int>(
      0,
      (total, serviceId) => total + _servicePriceById(serviceId),
    );
  }

  int get _selectedExtraServicesDurationTotal {
    return _selectedExtraServices.whereType<String>().fold<int>(
      0,
      (total, serviceId) => total + _serviceDurationById(serviceId),
    );
  }

  int get _estimatedTotalPrice {
    return _nailVariantPrice +
        _shapeMethodPrice.round() +
        _selectedExtraServicesTotal;
  }

  int get _estimatedTotalDuration {
    final baseDur =
        widget.nailData?['duration'] ?? widget.nailData?['estimatedTime'] ?? 60;
    final int nailDur = baseDur is num
        ? baseDur.round()
        : (int.tryParse(baseDur.toString()) ?? 60);
    return nailDur + _shapeMethodDuration + _selectedExtraServicesDurationTotal;
  }

  int? get _reviewSubtotal {
    final value = _priceReview?['price'];
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }

  String get _priceReviewRequestKey {
    final serviceIds = _selectedExtraServices.whereType<String>().toList()
      ..sort();
    final promotionIds = (_selectedPromotionIds ?? const <int>[]).toList()
      ..sort();
    return [
      _selectedBranch?['salonId']?.toString() ?? '',
      _selectedDate == null ? '' : _formatBookingDate(_selectedDate!),
      _selectedTime ?? '',
      _noArtistSelected
          ? ''
          : _selectedStylist?['nailArtistId']?.toString() ?? '',
      _nailVariantId.toString(),
      _shapeMethodConfigId?.toString() ?? '',
      serviceIds.join(','),
      promotionIds.join(','),
    ].join('|');
  }

  List<Map<String, dynamic>> get _availableServices {
    final source = _services.isEmpty
        ? BookingMockData.extraServices
        : _services;
    return source
        .whereType<Map>()
        .map((service) => Map<String, dynamic>.from(service))
        .toList();
  }

  List<int>? get _selectedPromotionIds {
    final id = _selectedPromotionId;
    return id == null ? null : [id];
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

  Future<void> _fetchSalons() async {
    setState(() => _salonsLoadError = null);
    try {
      final data = await RetryHelper.run(
        () => _apiService.getSalons(),
        shouldRetry: RetryHelper.defaultShouldRetry,
      );
      if (!mounted) return;
      final initialBranch = _findById(data, 'salonId', _sourceSalonId);
      setState(() {
        _salons = data;
        if (_skipSalonArtistSelection && initialBranch != null) {
          _selectedBranch = initialBranch;
        }
        _isLoadingSalons = false;
      });
      if (_skipSalonArtistSelection && initialBranch == null) {
        _fallbackToSelectionStep(0);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingSalons = false;
        _salonsLoadError = 'Không tải được danh sách salon: $e';
      });
      _showSnackBar(
        'Không tải được danh sách salon. Bấm "Thử lại" để tải lại.',
      );
    }
  }

  Future<void> _fetchServices() async {
    try {
      final data = await RetryHelper.run(
        () => _apiService.getServices(),
        shouldRetry: RetryHelper.defaultShouldRetry,
      );
      if (!mounted) return;
      setState(() => _services = data);
    } catch (_) {
      if (!mounted) return;
      setState(() => _services = BookingMockData.extraServices);
    }
  }

  Future<void> _fetchPromotions() async {
    setState(() => _isLoadingPromotions = true);
    try {
      final vouchers = await RetryHelper.run(
        () => _promotionApiService.getMyWalletVouchers(),
        shouldRetry: RetryHelper.defaultShouldRetry,
      );
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

  Future<void> _fetchNailVariantDetail() async {
    final id = _nailVariantId;
    if (id <= 0) return;
    try {
      final variant = await RetryHelper.run(
        () => getIt<NailVariantRepository>().getNailVariantById(id),
        shouldRetry: RetryHelper.defaultShouldRetry,
      );
      if (!mounted) return;
      setState(() => _nailVariantDetail = variant);
    } catch (e) {
      debugPrint('Failed to load nail variant detail: $e');
    }
  }

  Future<void> _fetchTimeSlots() async {
    if (_noArtistSelected) {
      _loadSalonSlots();
      return;
    }
    if (_selectedStylist == null || _selectedDate == null) return;

    final String? previousSelectedTime = _selectedTime;
    setState(() {
      _isLoadingTimes = true;
      _timesLoadError = null;
    });

    try {
      final bookingItems = _buildBookingItems();
      final data = await RetryHelper.run(
        () => _apiService.getArtistAvailableSlots(
          _selectedStylist!['nailArtistId'],
          _formatBookingDate(_selectedDate!),
          bookingItems: bookingItems,
        ),
        shouldRetry: RetryHelper.defaultShouldRetry,
      );
      if (!mounted) return;
      final filtered = _apiService.filterSlotsByOperatingHours(
        slots: data,
        salon: _selectedBranch,
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
      setState(() {
        _isLoadingTimes = false;
        _timesLoadError = 'Không tải được khung giờ: $e';
      });
      _showSnackBar('Không tải được khung giờ. Bấm "Thử lại" để tải lại.');
    }
  }

  Future<void> _loadSalonSlots() async {
    if (_selectedBranch == null || _selectedDate == null) return;
    final String? previousSelectedTime = _selectedTime;
    setState(() {
      _isLoadingTimes = true;
    });

    try {
      final bookingItems = _buildBookingItems();
      final data = await RetryHelper.run(
        () => _apiService.getSalonAvailableSlots(
          salonId: _selectedBranch!['salonId'],
          bookingDate: _formatBookingDate(_selectedDate!),
          bookingItems: bookingItems,
        ),
        shouldRetry: RetryHelper.defaultShouldRetry,
      );

      if (!mounted) return;
      final filtered = _apiService.filterSlotsByOperatingHours(
        slots: data,
        salon: _selectedBranch,
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
      setState(() {
        _isLoadingTimes = false;
        _timesLoadError = 'Không tải được khung giờ salon: $e';
      });
      _showSnackBar(
        'Không tải được khung giờ salon. Bấm "Thử lại" để tải lại.',
      );
    }
  }

  Future<void> _reviewPrice() async {
    if (_selectedBranch == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      return;
    }
    final requestKey = _priceReviewRequestKey;
    if (_priceReview != null && _priceReviewKey == requestKey) return;
    if (_inFlightPriceReviewKey == requestKey && _inFlightPriceReview != null) {
      return _inFlightPriceReview;
    }

    setState(() => _isReviewingPrice = true);
    final reviewFuture = () async {
      try {
        final review = await _apiService.reviewBookingPrice(
          salonId: _selectedBranch!['salonId'],
          bookingDate: _formatBookingDate(_selectedDate!),
          startTime: _normalizedSelectedTime,
          artistId: _noArtistSelected
              ? null
              : _selectedStylist?['nailArtistId'] as String?,
          nailVariantId: _nailVariantId,
          serviceIds: _selectedExtraServices.whereType<String>().toList(),
          selectedPromotionIds: _selectedPromotionIds,
          shapeMethodConfigId: _shapeMethodConfigId,
        );
        if (!mounted) return;
        if (_priceReviewRequestKey != requestKey) return;
        setState(() {
          _priceReview = review;
          _priceReviewKey = requestKey;
        });
      } catch (e) {
        debugPrint('reviewBookingPrice exception: $e');
      }
    }();

    _inFlightPriceReviewKey = requestKey;
    _inFlightPriceReview = reviewFuture;

    try {
      await reviewFuture;
    } catch (e) {
      if (mounted) _showSnackBar('Loi tinh gia: $e');
    } finally {
      if (_inFlightPriceReviewKey == requestKey) {
        _inFlightPriceReviewKey = null;
        _inFlightPriceReview = null;
        if (mounted) setState(() => _isReviewingPrice = false);
      }
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
        _showSnackBar(S.of(context).bookingPaymentError(e.toString()));
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    });
  }

  Future<bool> _createHoldForSummary() async {
    // Fix bug: trước đây khi user back từ step tổng quan về step chọn ngày/giờ
    // rồi chọn lại giờ, _handleTimeChanged đã tạo hold token mới → đến khi
    // bấm "Tiếp tục" sang step tổng quan, _createHoldForSummary lại gọi
    // _cancelCurrentHold() + _createHold() → backend log cho thấy 2 lần
    // DELETE hold-slot + 1 lần POST hold-slot (cancel hold cũ trước khi tạo
    // mới mặc dù hold cũ vẫn còn hiệu lực).
    //
    // Sau fix: nếu đã có hold token còn hiệu lực (_isHolding == true +
    // _holdToken != null + remaining > 0) thì GIỮ NGUYÊN, không tạo lại.
    // Chỉ tạo hold mới khi:
    //  - Chưa có token (_holdToken == null).
    //  - Hold đã hết hạn local (_isHolding == false).
    //  - User đổi giờ ở _handleTimeChanged (đã cancel thủ công ở đó).
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
      if (!_noArtistSelected && (token == null || token.isEmpty)) {
        _showHoldFailureMessage(
          'Không thể giữ khung giờ này. Vui lòng chọn giờ khác.',
        );
        return false;
      }
      if (mounted && token != null) {
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
      // → hiển thị message server để user biết lý do.
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
  /// `message` gốc từ server (ApiClient đã strip "Lỗi từ Server" và
  /// các prefix thừa). Fallback chỉ dùng khi exception rỗng/null.
  String _extractServerMessage(String rawMessage) {
    String msg = rawMessage.trim();
    if (msg.isEmpty ||
        msg.toLowerCase() == 'null' ||
        msg.toLowerCase() == 'exception') {
      return 'Không thể giữ khung giờ này. Vui lòng chọn giờ khác.';
    }
    return msg;
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

  Future<Map<String, dynamic>?> _createHold() async {
    if (_noArtistSelected) return null;

    final salonId = _selectedBranch?['salonId']?.toString() ?? '';
    final artistId = _selectedStylist?['nailArtistId']?.toString() ?? '';
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
        if (_currentStep > 2) {
          _pageController.animateToPage(
            2,
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
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: isUrgent ? Colors.red.shade600 : Colors.orange.shade700,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: (isUrgent ? Colors.red.shade600 : Colors.orange.shade700)
                .withValues(alpha: 0.25),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.timer_outlined, color: Colors.white, size: 18),
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
      'salonId': _selectedBranch!['salonId'],
      'bookingDate': _formatBookingDate(_selectedDate!),
      'startTime': _normalizedSelectedTime,
      'nailArtistId': _noArtistSelected
          ? null
          : _selectedStylist?['nailArtistId'] as String?,
      'holdToken': holdToken,
      'bookingItems': _buildBookingItems(),
      'selectedPromotionIds': _selectedPromotionIds,
      'useWalletBalance': _useWalletBalance,
    };
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

  List<Map<String, dynamic>> _buildBookingItems() {
    final List<Map<String, dynamic>> items = [];
    if (_nailVariantId > 0) {
      items.add({
        'nailVariantId': _nailVariantId,
        if (_shapeMethodConfigId != null)
          'shapeMethodConfigId': _shapeMethodConfigId,
        'quantity': 1,
      });
    }

    final serviceCounts = <String, int>{};
    for (final sId in _selectedExtraServices.whereType<String>()) {
      if (sId.isNotEmpty) {
        serviceCounts[sId] = (serviceCounts[sId] ?? 0) + 1;
      }
    }
    for (final entry in serviceCounts.entries) {
      items.add({'serviceId': entry.key, 'quantity': entry.value});
    }
    return items;
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
    final matches = _availableServices.where(
      (service) => _serviceId(service) == serviceId,
    );
    if (matches.isEmpty) return serviceId;
    final name = _serviceName(matches.first);
    return name.isEmpty ? serviceId : name;
  }

  int _servicePriceById(String? serviceId) {
    if (serviceId == null) return 0;
    final matches = _availableServices.where(
      (service) => _serviceId(service) == serviceId,
    );
    if (matches.isEmpty) return 0;
    final price = matches.first['price'] ?? matches.first['basePrice'];
    if (price is num) return price.round();
    return int.tryParse(price?.toString() ?? '') ?? 0;
  }

  int _serviceDurationById(String? serviceId) {
    if (serviceId == null) return 0;
    final matches = _availableServices.where(
      (service) => _serviceId(service) == serviceId,
    );
    if (matches.isEmpty) return 0;
    final dur = matches.first['duration'] ?? matches.first['estimatedTime'];
    if (dur is num) return dur.round();
    return int.tryParse(dur?.toString() ?? '') ?? 0;
  }

  Future<void> _fetchSuggestedArtists() async {
    if (_selectedBranch == null || _selectedDate == null) return;
    setState(() {
      _isLoadingArtists = true;
      _artists = [];
    });
    try {
      final salonId = _selectedBranch!['salonId'].toString();
      final dateStr = _formatBookingDate(_selectedDate!);
      final data = await RetryHelper.run(
        () => _apiService.getSuggestedArtists(
          salonId,
          dateStr,
          nailVariantId: _nailVariantId,
          serviceIds: _selectedExtraServices.whereType<String>().toList(),
          shapeMethodConfigId: _shapeMethodConfigId,
        ),
        shouldRetry: RetryHelper.defaultShouldRetry,
      );
      if (!mounted) return;
      final initialArtist = _findById(data, 'nailArtistId', _sourceArtistId);
      setState(() {
        _artists = data;
        if (_skipSalonArtistSelection && initialArtist != null) {
          _selectedStylist = initialArtist;
          _noArtistSelected = false;
        }
        _isLoadingArtists = false;
      });
      if (_skipSalonArtistSelection && initialArtist == null) {
        _fallbackToSelectionStep(1);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingArtists = false);
      _showSnackBar('Không thể tải danh sách thợ gợi ý: $e');
    }
  }

  void _handleBranchSelected(dynamic branch) {
    _cancelCurrentHold();
    final branchMap = Map<String, dynamic>.from(branch as Map);
    setState(() {
      _selectedBranch = branchMap;
      _selectedDate = null;
      _selectedStylist = null;
      _selectedTime = null;
      _noArtistSelected = false;
      _artists = [];
      _timeSlots = [];
      _priceReview = null;
    });
  }

  void _handleServiceChanged(List<String?> services) {
    setState(() {
      _selectedExtraServices = services;
      _priceReview = null;
    });
  }

  void _handleDateChanged(DateTime date) {
    _cancelCurrentHold();
    setState(() {
      _selectedDate = date;
      _selectedTime = null;
      _priceReview = null;
      _timeSlots = [];
    });
  }

  void _handleStylistSelected(Map<String, dynamic>? stylist) {
    _cancelCurrentHold();
    setState(() {
      _selectedStylist = stylist;
      _selectedTime = null;
      _noArtistSelected = stylist == null;
      _priceReview = null;
    });
    _fetchTimeSlots();
  }

  void _handleArtistModeChanged(bool isNoArtist) {
    _cancelCurrentHold();
    setState(() {
      _noArtistSelected = isNoArtist;
      _selectedStylist = null;
      _selectedTime = null;
      _priceReview = null;
      _timeSlots = [];
    });

    if (isNoArtist) {
      _loadSalonSlots();
    } else {
      _fetchSuggestedArtists();
    }
  }

  void _handlePromotionChanged(int? promotionId) {
    setState(() {
      _selectedPromotionId = promotionId;
      _priceReviewKey = null;
      _isReviewingPrice = true;
    });
    if (_currentStep == 4) {
      _reviewPrice();
    }
  }

  Future<void> _handleBackAction() async {
    if (_skipSalonArtistSelection && _currentStep <= 1) {
      context.pop();
    } else if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.pop();
    }
  }

  Map<String, dynamic>? _findById(
    List<dynamic> items,
    String key,
    String targetId,
  ) {
    if (targetId.isEmpty) return null;
    for (final item in items.whereType<Map>()) {
      final map = Map<String, dynamic>.from(item);
      final id = map[key]?.toString() ?? map['id']?.toString() ?? '';
      if (id == targetId) return map;
    }
    return null;
  }

  void _fallbackToSelectionStep(int step) {
    if (!mounted) return;
    setState(() {
      _sourceSelectionFallback = true;
      _currentStep = step;
    });
    if (_pageController.hasClients) {
      _pageController.jumpToPage(step);
    }
  }

  Future<void> _handleNextAction() async {
    if (_isSubmitting) return;

    if (_currentStep == 0 && _selectedBranch == null) {
      _showSnackBar(S.of(context).bookingValidateSalon);
      return;
    }
    if (_currentStep == 1) {
      if (_selectedExtraServices.contains(null)) {
        _showSnackBar(S.of(context).bookingValidateService);
        return;
      }
      final validServices = _selectedExtraServices.whereType<String>().toList();
      if (widget.nailData == null && validServices.isEmpty) {
        _showSnackBar(S.of(context).bookingValidateServiceMin);
        return;
      }
    }
    if (_currentStep == 2 && _selectedDate == null) {
      _showSnackBar('Vui lòng chọn 1 ngày đặt lịch!');
      return;
    }
    if (_currentStep == 3) {
      if (!_noArtistSelected && _selectedStylist == null) {
        _showSnackBar('Vui lòng chọn thợ nail hoặc chọn "Để Nailify sắp xếp"!');
        return;
      }
      if (_selectedTime == null) {
        _showSnackBar('Vui lòng chọn khung giờ rảnh!');
        return;
      }
    }

    if (_currentStep < 4) {
      if (_currentStep == 3) {
        setState(() => _isSubmitting = true);
        try {
          final held = await _createHoldForSummary();
          if (!held) {
            if (mounted) setState(() => _isSubmitting = false);
            return;
          }
          _reviewPrice();
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
      _executeBooking();
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
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
          S.of(context).bookAppointmentTitle,
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
      body: Column(
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
                if (idx == 3) {
                  if (_timeSlots.isEmpty) {
                    if (_noArtistSelected) {
                      _loadSalonSlots();
                    } else {
                      _fetchSuggestedArtists();
                      if (_selectedStylist != null) {
                        _fetchTimeSlots();
                      }
                    }
                  }
                } else if (idx == 4) {
                  if (_priceReviewKey != _priceReviewRequestKey) {
                    setState(() {
                      _priceReviewKey = null;
                      _isReviewingPrice = true;
                    });
                  }
                  _reviewPrice();
                }
              },
              children: [
                _buildSalonStep(),
                _buildServiceStep(),
                _buildDateStep(),
                _buildArtistAndTimeStep(),
                _buildSummaryStep(),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildSalonStep() {
    if (_salonsLoadError != null && !_isLoadingSalons) {
      return _buildRetryView(message: _salonsLoadError!, onRetry: _fetchSalons);
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: BranchSelectionList(
        salons: _salons,
        isLoading: _isLoadingSalons,
        selectedBranchId: _selectedBranch?['salonId'],
        onBranchSelected: _handleBranchSelected,
      ),
    );
  }

  Widget _buildRetryView({
    required String message,
    required Future<void> Function() onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_off_rounded, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Thử lại'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildServiceStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingServiceSelection(
            nailData: widget.nailData,
            services: _availableServices,
            selectedExtraServices: _selectedExtraServices,
            onChanged: _handleServiceChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildDateStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingDateSelection(
            selectedDate: _selectedDate,
            onDateChanged: _handleDateChanged,
          ),
        ],
      ),
    );
  }

  Widget _buildArtistAndTimeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── MODE SELECTOR TOGGLE (TỰ CHỌN THỢ / ĐỂ NAILIFY SẮP XẾP) ──
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => _handleArtistModeChanged(false),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !_noArtistSelected
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: !_noArtistSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          'Tự chọn thợ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: !_noArtistSelected
                                ? AppColors.primary
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => _handleArtistModeChanged(true),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: _noArtistSelected
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _noArtistSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          'Để Nailify sắp xếp',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _noArtistSelected
                                ? AppColors.primary
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // ── MODE 1: TỰ CHỌN THỢ ──
          if (!_noArtistSelected) ...[
            ArtistSelectionList(
              artists: _artists,
              isLoading: _isLoadingArtists,
              selectedStylistId: _selectedStylist?['nailArtistId'],
              noArtistSelected: false,
              hideAutoAssign: true,
              onStylistSelected: (stylist) {
                _handleStylistSelected(stylist);
              },
              onModeChanged: (_) {},
            ),
            const SizedBox(height: 24),
            if (_selectedStylist != null) ...[
              if (_timesLoadError != null && !_isLoadingTimes)
                _buildRetryView(
                  message: _timesLoadError!,
                  onRetry: _fetchTimeSlots,
                )
              else
                BookingTimeSelection(
                  timeSlots: _timeSlots,
                  isLoading: _isLoadingTimes,
                  selectedTime: _selectedTime,
                  canSelect: true,
                  selectedDate: _selectedDate,
                  salonId: _selectedBranch?['salonId'],
                  artistId: _selectedStylist?['nailArtistId'],
                  waitlistItems: _buildBookingItems(),
                  onTimeChanged: (time) {
                    _cancelCurrentHold();
                    setState(() {
                      _selectedTime = time;
                      _priceReview = null;
                    });
                  },
                ),
            ],
          ] else ...[
            // ── MODE 2: ĐỂ NAILIFY SẮP XẾP ──
            if (_timesLoadError != null && !_isLoadingTimes)
              _buildRetryView(
                message: _timesLoadError!,
                onRetry: _loadSalonSlots,
              )
            else
              BookingTimeSelection(
                timeSlots: _timeSlots,
                isLoading: _isLoadingTimes,
                selectedTime: _selectedTime,
                canSelect: true,
                selectedDate: _selectedDate,
                salonId: _selectedBranch?['salonId'],
                artistId: null,
                waitlistItems: _buildBookingItems(),
                onTimeChanged: (time) {
                  _cancelCurrentHold();
                  setState(() {
                    _selectedTime = time;
                    _priceReview = null;
                  });
                },
              ),
          ],
        ],
      ),
    );
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
        _selectedBranch?['name']?.toString() ?? 'Chi nhánh Nailify';
    final dateStr = _selectedDate == null
        ? ''
        : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}';
    final timeStr = _selectedTime == null ? '' : _selectedTime!.substring(0, 5);
    final dateTimeText = dateStr.isEmpty ? '--' : '$dateStr • $timeStr';

    final artistName = _noArtistSelected
        ? S.of(context).bookingAutoAssign
        : (_selectedStylist?['fullName']?.toString() ?? 'Thợ ngẫu nhiên');
    final artistAvatar = _selectedStylist?['avatarUrl']?.toString();

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
          // ── Dòng 1: Icon Salon + Tên chi nhánh + Nút Đổi lịch ──
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
                onTap: () => setState(() => _currentStep = 1),
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

          // ── Dòng 2: 2 cột ngang (Lịch hẹn & Thợ phụ trách) ──
          Row(
            children: [
              // Cột trái: Lịch hẹn
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
              // Cột phải: Thợ phụ trách
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFFFF0F5),
                      backgroundImage:
                          artistAvatar != null && artistAvatar.isNotEmpty
                          ? NetworkImage(artistAvatar)
                          : null,
                      child: artistAvatar == null || artistAvatar.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              size: 16,
                              color: Color(0xFFE02B6D),
                            )
                          : null,
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

  /// KHỐI 1: KHỐI ƯU ĐÃI & VÍ TIỀN (Thao tác trước khi chốt hóa đơn)
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

  Widget _buildVoucherRow() {
    final selectedPromotion = _promotions.where(
      (v) => v.promotionId == _selectedPromotionId,
    );
    final hasSelected = selectedPromotion.isNotEmpty;
    final count = _promotions.length;
    final selectedVoucher = hasSelected ? selectedPromotion.first : null;

    return GestureDetector(
      onTap: _isLoadingPromotions
          ? null
          : () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => BookingPromotionSheet(
                  selectedPromotions: selectedPromotion.toList(),
                  onConfirm: (list) {
                    if (list.isNotEmpty) {
                      _handlePromotionChanged(list.first.promotionId);
                    } else {
                      _handlePromotionChanged(null);
                    }
                  },
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
              onPressed: () => _handlePromotionChanged(null),
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
                  ? (val) => setState(() => _useWalletBalance = val)
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

  /// KHỐI 2: CHI TIẾT THANH TOÁN (Payment Details - Chỉ hiển thị hóa đơn)
  Widget _buildPaymentDetailsCard() {
    final reviewTotal = _priceReview?['totalPrice'];
    final bool isLoading = _isReviewingPrice && _priceReview == null;
    final int totalPrice = reviewTotal is num
        ? reviewTotal.round()
        : isLoading
        ? 0
        : int.tryParse(reviewTotal?.toString() ?? '') ?? _estimatedTotalPrice;
    final int subtotalPrice = _reviewSubtotal ?? _estimatedTotalPrice;

    // Calculate deposit info
    final depositInfo = PriceFormatter.getDepositInfo(
      _selectedBranch?['depositConfig'],
      totalPrice,
    );
    final initialDepositAmount = depositInfo['amount'] as int;

    // Calculate deductions for deposit
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
          // 1. Header: Icon hóa đơn màu hồng + "Chi tiết thanh toán"
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

          // 2. Danh sách dịch vụ đã chọn (Itemized List)
          PaymentDetailTable(items: _paymentTableItems),

          const SizedBox(height: 14),
          // 3. Đường nét đứt mờ (Dashed Divider)
          CustomPaint(
            size: const Size(double.infinity, 1),
            painter: _HorizontalDashedLinePainter(
              color: const Color(0xFFE5E7EB),
            ),
          ),
          const SizedBox(height: 14),

          // 4. Các mục tiền phụ & giảm trừ
          // - Tạm tính
          _buildInvoiceRow('Tạm tính', subtotalPrice, isNegative: false),

          // - Discount Breakdown (Ưu đãi thành viên, Voucher, v.v.)
          for (final discount in _discountBreakdown)
            _buildDiscountInvoiceRow(discount),

          const SizedBox(height: 6),
          // 5. Đường kẻ phân cách rõ ràng
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 14),

          // 6. Hàng Tổng cộng
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

          if (_selectedBranch != null && !isLoading) ...[
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

  Widget _buildInvoiceRow(
    String label,
    num amount, {
    required bool isNegative,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              color: isNegative ? Colors.grey.shade700 : Colors.grey.shade600,
              fontWeight: isNegative ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          Text(
            isNegative
                ? '-${PriceFormatter.format(amount)}'
                : PriceFormatter.format(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isNegative
                  ? const Color(0xFFE02B6D)
                  : AppColors.textPrimary,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountInvoiceRow(Map<String, dynamic> discount) {
    final name = discount['name']?.toString() ?? 'Ưu đãi';
    String? description = discount['description']?.toString();
    if (description == null || description.isEmpty) {
      if (name == 'Perfect Match') {
        description = 'Giảm 15% tất cả thiết kế móng dòng SkinTone';
      }
    }
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
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFFE02B6D),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDiscountSummaryRow(String label, num discountAmount) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
          ),
          Text(
            '-${PriceFormatter.format(discountAmount)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Color(0xFFE02B6D),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNailVariantPaymentItem() {
    final variant = _nailVariantDetail;
    final shapeMethodName = _shapeMethodName ?? S.of(context).shapeMethodLabel;
    final shouldShowShapeMethod =
        _shapeMethodName != null || _shapeMethodPrice > 0;
    final reviewedNailPrice = _reviewSubtotal == null
        ? null
        : (_reviewSubtotal! - _selectedExtraServicesTotal).clamp(0, 1 << 31);
    final displayPrice =
        reviewedNailPrice ?? _nailVariantPrice + _shapeMethodPrice.round();
    final detailRows = <Map<String, dynamic>>[];

    if (variant?.nailSurface != null) {
      detailRows.add({
        'name': variant!.nailSurface!.name,
        'price': variant.nailSurface!.price,
        'quantity': 1,
      });
    }
    if (shouldShowShapeMethod) {
      detailRows.add({
        'name': shapeMethodName,
        'price': _shapeMethodPrice,
        'quantity': 1,
      });
    }
    if (variant != null) {
      detailRows.addAll(_variantComponentRows(variant));
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPaymentRow(
            widget.nailData!['name']?.toString() ??
                S.of(context).bookingNailVariantDefault,
            displayPrice,
          ),
          if (detailRows.isNotEmpty) ...[
            const SizedBox(height: 4),
            const _PriceTableHeader(),
            const SizedBox(height: 2),
            ...detailRows.map(_buildVariantDetailLine),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _variantComponentRows(NailVariantModel variant) {
    final rowsByKey = <String, Map<String, dynamic>>{};
    for (final component in variant.nailComponents) {
      final detail = component.component;
      final name = detail?.name ?? S.of(context).bookingComponentDefault;
      final type = detail?.componentType.trim() ?? '';
      final label = type.isEmpty ? name : '$type: $name';
      final price = detail?.price ?? 0;
      final quantity = component.fingerIndex == -1 ? 5 : 1;
      final key =
          '${detail?.componentId ?? component.componentId}|$label|$price';
      final existing = rowsByKey[key];
      if (existing == null) {
        rowsByKey[key] = {'name': label, 'price': price, 'quantity': quantity};
      } else {
        existing['quantity'] = (existing['quantity'] as int) + quantity;
      }
    }
    return rowsByKey.values.toList();
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

  Widget _buildPaymentRow(
    String label,
    num price, {
    bool strong = false,
    bool muted = false,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: highlight ? 16 : 14,
                  color: muted ? Colors.grey.shade600 : AppColors.textPrimary,
                  fontWeight: strong ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
          Text(
            PriceFormatter.format(price),
            style: TextStyle(
              fontWeight: strong ? FontWeight.bold : FontWeight.w600,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
              fontSize: highlight ? 17 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentRowWithText(
    String label,
    String valueText, {
    bool strong = false,
    bool muted = false,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: highlight ? 16 : 14,
                  color: muted ? Colors.grey.shade600 : AppColors.textPrimary,
                  fontWeight: strong ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
          Text(
            valueText,
            style: TextStyle(
              fontWeight: strong ? FontWeight.bold : FontWeight.w600,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
              fontSize: highlight ? 17 : 14,
            ),
          ),
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
      _selectedBranch?['depositConfig'],
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
        _buildPaymentRowWithText(
          S.of(context).bookingDepositRatioLabel,
          depositConfigText,
          muted: true,
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
        _buildPaymentRow(
          S.of(context).bookingDepositAmountLabel,
          depositAmountToPay,
          strong: true,
          highlight: true,
        ),
        if (_useWalletBalance && walletDeduction > 0) ...[
          const SizedBox(height: 8),
          _buildPaymentRowWithText(
            'Còn lại trả tại Salon:',
            PriceFormatter.format(remainingAmountAtSalon),
            muted: true,
            strong: true,
          ),
        ],
      ],
    );
  }

  Widget _buildVariantDetailLine(Map<String, dynamic> row) {
    final label = row['name']?.toString() ?? '';
    final price = row['price'] as num? ?? 0;
    final quantity = row['quantity'] as int? ?? 1;
    return Padding(
      padding: const EdgeInsets.only(top: 6, left: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 5,
            child: Padding(
              padding: const EdgeInsets.only(right: 10),
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ),
          SizedBox(
            width: 38,
            child: Text(
              'x$quantity',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              price > 0 ? PriceFormatter.format(price * quantity) : '-',
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  List<PaymentTableItem> get _paymentTableItems {
    final items = <PaymentTableItem>[];
    if (widget.nailData != null) {
      final reviewedNailPrice = _reviewSubtotal == null
          ? null
          : (_reviewSubtotal! - _selectedExtraServicesTotal).clamp(0, 1 << 31);
      final displayPrice =
          reviewedNailPrice ?? _nailVariantPrice + _shapeMethodPrice.round();
      items.add(
        PaymentTableItem(
          name:
              widget.nailData!['name']?.toString() ??
              S.of(context).bookingNailVariantDefault,
          quantity: 1,
          unitPrice: displayPrice,
        ),
      );
    }
    final counts = <String, int>{};
    for (final serviceId in _selectedExtraServices.whereType<String>()) {
      counts[serviceId] = (counts[serviceId] ?? 0) + 1;
    }
    for (final entry in counts.entries) {
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

  Widget _buildDiscountRow(Map<String, dynamic> discount) {
    final name = discount['name']?.toString() ?? 'Giảm giá';
    final amount = discount['amount'];
    final amountDisplay = discount['amountDisplay']?.toString();
    final rawDisplay = (amountDisplay?.isNotEmpty == true)
        ? amountDisplay!
        : (amount != null ? PriceFormatter.format(amount) : '');
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Row(
              children: [
                const Icon(
                  Icons.card_giftcard_rounded,
                  size: 16,
                  color: Color(0xFFE02B6D),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    );
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

  Widget _buildWalletBalanceToggle() {
    final balance = _walletAvailableBalance;
    final hasBalance = balance != null && balance > 0;
    final isActive = _useWalletBalance && hasBalance;

    return GestureDetector(
      onTap: hasBalance && !_isLoadingWallet
          ? () => setState(() => _useWalletBalance = !_useWalletBalance)
          : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isActive ? const Color(0xFFFFADC8) : const Color(0xFFF3E8EE),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Ví tiền Nailify',
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
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: hasBalance
                            ? const Color(0xFFE02B6D)
                            : Colors.grey.shade500,
                      ),
                    ),
                  if (isActive) ...[
                    const SizedBox(height: 2),
                    const Text(
                      'Áp dụng trừ số dư vào tiền cọc',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFFE02B6D),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(
              height: 32,
              child: FittedBox(
                fit: BoxFit.contain,
                child: Switch(
                  value: _useWalletBalance,
                  onChanged: hasBalance && !_isLoadingWallet
                      ? (val) => setState(() => _useWalletBalance = val)
                      : null,
                  activeThumbColor: Colors.white,
                  activeTrackColor: const Color(0xFFE02B6D),
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: const Color(0xFFF0E6EA),
                  trackOutlineColor: WidgetStateProperty.all(
                    Colors.transparent,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPromotionSelector() {
    final selectedPromotion = _promotions.where(
      (v) => v.promotionId == _selectedPromotionId,
    );
    final hasSelected = selectedPromotion.isNotEmpty;
    final count = _promotions.length;
    final selectedVoucher = hasSelected ? selectedPromotion.first : null;

    return GestureDetector(
      onTap: _isLoadingPromotions
          ? null
          : () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => BookingPromotionSheet(
                  selectedPromotions: selectedPromotion.toList(),
                  onConfirm: (list) {
                    if (list.isNotEmpty) {
                      _handlePromotionChanged(list.first.promotionId);
                    } else {
                      _handlePromotionChanged(null);
                    }
                  },
                ),
              );
            },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasSelected
                ? const Color(0xFFFFADC8)
                : const Color(0xFFF3E8EE),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(9),
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
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    children: [
                      Text(
                        S.of(context).bookingWalletVoucher,
                        style: const TextStyle(
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
                        width: 70,
                        child: LinearProgressIndicator(
                          backgroundColor: Color(0xFFFCE4EC),
                          valueColor: AlwaysStoppedAnimation(Color(0xFFE02B6D)),
                        ),
                      ),
                    )
                  else if (hasSelected)
                    Text(
                      '${selectedVoucher!.promotionName} • ${selectedVoucher.displayDiscount}',
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
                      count > 0
                          ? 'Bạn có $count voucher có thể sử dụng'
                          : S.of(context).bookingSelectVoucher,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFD1DC)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    hasSelected ? 'Đổi mã' : 'Chọn',
                    style: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE02B6D),
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFE02B6D),
                    size: 16,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF5F8),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
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
            if (_currentStep == 2 && (totalP > 0 || totalD > 0)) ...[
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
                            : Text(
                                S.of(context).bookingContinueBtn,
                                style: const TextStyle(
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
                          height: 52,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(28),
                            gradient: LinearGradient(
                              colors: _isSubmitting
                                  ? [Colors.grey.shade400, Colors.grey.shade500]
                                  : [
                                      const Color(0xFFFF4081),
                                      const Color(0xFFE02B6D),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              if (!_isSubmitting)
                                BoxShadow(
                                  color: const Color(
                                    0xFFE02B6D,
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
                                borderRadius: BorderRadius.circular(28),
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
                                        _currentStep == 4
                                            ? Icons.lock_outline_rounded
                                            : Icons.arrow_forward_rounded,
                                        size: 18,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        _currentStep == 4
                                            ? S.of(context).bookingPayBtn
                                            : S.of(context).bookingContinueBtn,
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          letterSpacing: 0.2,
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
      padding: EdgeInsets.only(left: 12, top: 4),
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

class _DashedDividerPainter extends CustomPainter {
  final Color color;
  const _DashedDividerPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    const dashHeight = 4.0;
    const dashSpace = 3.0;
    double startY = 6.0;

    while (startY < size.height - 6.0) {
      canvas.drawLine(
        Offset(size.width / 2, startY),
        Offset(size.width / 2, startY + dashHeight),
        paint,
      );
      startY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _DashedDividerPainter oldDelegate) {
    return oldDelegate.color != color;
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
