import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../generated/l10n.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/retry_helper.dart';
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
  bool _isPromotionExpanded = false;
  bool _isReviewingPrice = false;
  bool _sourceSelectionFallback = false;

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
    {'title': 'Chọn thợ', 'icon': Icons.person_pin_rounded},
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
    _currentStep = _skipSalonArtistSelection ? 2 : 0;
    _pageController = PageController(initialPage: _currentStep);
    _fetchSalons();
    _fetchServices();
    _fetchPromotions();
    _fetchNailVariantDetail();
  }

  @override
  void dispose() {
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
    final value = widget.nailData?['shapeMethodPrice'];
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  int get _selectedExtraServicesTotal {
    return _selectedExtraServices.whereType<String>().fold<int>(
      0,
      (total, serviceId) => total + _servicePriceById(serviceId),
    );
  }

  int get _estimatedTotalPrice {
    return _nailVariantPrice +
        _shapeMethodPrice.round() +
        _selectedExtraServicesTotal;
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
      if (_skipSalonArtistSelection && initialBranch != null) {
        _fetchSalonArtists(_sourceSalonId);
      } else if (_skipSalonArtistSelection) {
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

    setState(() {
      _isLoadingTimes = true;
      _timeSlots = [];
      _selectedTime = null;
      _timesLoadError = null;
    });

    try {
      final data = await RetryHelper.run(
        () => _apiService.getArtistAvailableSlots(
          _selectedStylist!['nailArtistId'],
          _formatBookingDate(_selectedDate!),
        ),
        shouldRetry: RetryHelper.defaultShouldRetry,
      );
      if (!mounted) return;
      setState(() {
        _timeSlots = _apiService.filterSlotsByOperatingHours(
          slots: data,
          salon: _selectedBranch,
          date: _selectedDate,
        );
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
    setState(() {
      _isLoadingTimes = true;
      _timeSlots = [];
      _selectedTime = null;
    });

    try {
      // Build booking items
      final List<Map<String, dynamic>> bookingItems = [];
      final int variantId = _nailVariantId;
      if (variantId > 0) {
        bookingItems.add({
          'nailVariantId': variantId,
          if (_shapeMethodConfigId != null)
            'shapeMethodConfigId': _shapeMethodConfigId,
          'quantity': 1,
        });
      }
      for (final sId in _selectedExtraServices.whereType<String>()) {
        bookingItems.add({'serviceId': sId, 'quantity': 1});
      }

      final data = await RetryHelper.run(
        () => _apiService.getSalonAvailableSlots(
          salonId: _selectedBranch!['salonId'],
          bookingDate: _formatBookingDate(_selectedDate!),
          bookingItems: bookingItems,
        ),
        shouldRetry: RetryHelper.defaultShouldRetry,
      );

      if (!mounted) return;
      setState(() {
        _timeSlots = _apiService.filterSlotsByOperatingHours(
          slots: data,
          salon: _selectedBranch,
          date: _selectedDate,
        );
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
        context.go('/payment-qr', extra: paymentData);
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

    final hold = await _createHold();
    final token = hold?['holdToken']?.toString();
    if (!_noArtistSelected && (token == null || token.isEmpty)) {
      _showSnackBar('Không thể giữ khung giờ này. Vui lòng chọn giờ khác.');
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
                  ? 'Chỗ có thể bị hủy sau $minutes:$seconds'
                  : 'Slot đang được giữ cho bạn - còn $minutes:$seconds để hoàn tất',
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
    };
  }

  List<Map<String, dynamic>> _buildBookingItems() {
    return [
      if (_nailVariantId > 0)
        {
          'nailVariantId': _nailVariantId,
          if (_shapeMethodConfigId != null)
            'shapeMethodConfigId': _shapeMethodConfigId,
          'quantity': 1,
        },
      ..._selectedExtraServices.whereType<String>().map(
        (serviceId) => {'serviceId': serviceId, 'quantity': 1},
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

  Future<void> _fetchSalonArtists(String salonId) async {
    setState(() {
      _isLoadingArtists = true;
      _artists = [];
    });
    try {
      final data = await _apiService.getNailArtistsBySalon(salonId);
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
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingArtists = false);
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
    _fetchSalonArtists(branchMap['salonId']?.toString() ?? '');
  }

  void _handleServiceChanged(List<String?> services) {
    // Fix bug: trước đây `_handleServiceChanged` gọi `_cancelCurrentHold()` +
    // clear giờ + clear timeSlots khi user đính kèm dịch vụ (ngâm chân thảo
    // mộc, cắt da tay...). Điều này khiến user đã tạo hold token cho slot
    // mà quay lại step dịch vụ thì mất luôn slot đó.
    //
    // Sau fix: dịch vụ đi kèm là addon SONG SONG với dịch vụ chính, KHÔNG
    // ảnh hưởng đến duration slot đã chọn. Hold token vẫn hợp lệ và nên
    // được giữ nguyên.
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
    if (_noArtistSelected || _selectedStylist == null) {
      _loadSalonSlots();
    } else {
      _fetchTimeSlots();
    }
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
    // Fix bug: trước đây khi user back từ step 3 (tổng quan) về step < 3,
    // hệ thống gọi `_cancelCurrentHold()` → xóa hold token + gọi API
    // `cancelHoldSlot` lên backend. Điều này không đúng vì:
    //  - User chỉ muốn xem lại các bước trước, KHÔNG có ý định hủy booking.
    //  - Khi bấm "Tiếp tục" trở lại step 3, hệ thống phải tạo hold mới
    //    → tốn 1 lượt API hold-slot + có thể không còn slot đó nữa.
    //
    // Sau fix: KHÔNG cancel hold khi back giữa các step. Hold token chỉ bị
    // huỷ khi:
    //  - User đổi salon/ngày/thợ/mode/giờ (line 695, 720, 735, 746).
    //  - Hold timer hết hạn.
    //  - User thoát khỏi trang booking (line 109 dispose()).
    if (_skipSalonArtistSelection && _currentStep <= 2) {
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
    if (_currentStep == 1 && _selectedStylist == null && !_noArtistSelected) {
      _showSnackBar('Vui lòng chọn thợ hoặc chọn "Tự động phân công"!');
      return;
    }
    if (_currentStep == 2) {
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
    if (_currentStep == 3 && (_selectedDate == null || _selectedTime == null)) {
      _showSnackBar(S.of(context).bookingValidateDateTime);
      return;
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
          _buildStepIndicator(),
          _buildHoldCountdownBanner(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (idx) {
                setState(() => _currentStep = idx);
                if (idx == 4) {
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
                _buildArtistStep(),
                _buildServiceStep(),
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

  Widget _buildSalonStep() {
    if (_salonsLoadError != null && !_isLoadingSalons) {
      return _buildRetryView(
        message: _salonsLoadError!,
        onRetry: _fetchSalons,
      );
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
            const Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: Colors.grey,
            ),
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

  Widget _buildArtistStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ArtistSelectionList(
        artists: _artists,
        isLoading: _isLoadingArtists,
        selectedStylistId: _selectedStylist?['nailArtistId'],
        noArtistSelected: _noArtistSelected,
        onStylistSelected: _handleStylistSelected,
        onModeChanged: _handleArtistModeChanged,
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

  Widget _buildScheduleStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingDateSelection(
            selectedDate: _selectedDate,
            onDateChanged: _handleDateChanged,
          ),
          const SizedBox(height: 28),
          if (_timesLoadError != null &&
              !_isLoadingTimes &&
              _selectedDate != null)
            _buildRetryView(
              message: _timesLoadError!,
              onRetry: _fetchTimeSlots,
            )
          else
            BookingTimeSelection(
              timeSlots: _timeSlots,
              isLoading: _isLoadingTimes,
              selectedTime: _selectedTime,
              canSelect: _selectedDate != null,
              selectedDate: _selectedDate,
              salonId: _selectedBranch?['salonId'],
              artistId: _selectedStylist?['nailArtistId'],
              onTimeChanged: (time) {
                _cancelCurrentHold();
                setState(() {
                  _selectedTime = time;
                  _priceReview = null;
                });
              },
            ),
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
          const SizedBox(height: 24),
          _buildPromotionSelector(),
          const SizedBox(height: 24),
          _buildPaymentDetails(),
        ],
      ),
    );
  }

  Widget _buildBookingSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF2ECE6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            Icons.storefront_rounded,
            S.of(context).bookingSummaryBranch,
            _selectedBranch?['name']?.toString() ?? '',
          ),
          _buildSummaryRow(
            Icons.calendar_month_rounded,
            S.of(context).bookingSummaryDate,
            _selectedDate == null
                ? ''
                : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
          ),
          _buildSummaryRow(
            Icons.access_time_rounded,
            S.of(context).bookingSummaryTime,
            _selectedTime == null ? '' : _selectedTime!.substring(0, 5),
          ),
          _buildSummaryRow(
            Icons.person_pin_rounded,
            S.of(context).bookingSummaryArtist,
            _noArtistSelected
                ? S.of(context).bookingAutoAssign
                : (_selectedStylist?['fullName']?.toString() ?? ''),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetails() {
    final reviewTotal = _priceReview?['totalPrice'];
    final bool isLoading = _isReviewingPrice && _priceReview == null;
    final int totalPrice = reviewTotal is num
        ? reviewTotal.round()
        : isLoading
        ? 0
        : int.tryParse(reviewTotal?.toString() ?? '') ?? _estimatedTotalPrice;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF2ECE6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                  color: Color(0xFFFFF5F8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: AppColors.primary,
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
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),
          PaymentDetailTable(items: _paymentTableItems),
          if (_discountBreakdown.isNotEmpty) ...[
            const Divider(height: 16, color: Color(0xFFFFF0F5)),
            ..._discountBreakdown.map(_buildDiscountRow),
          ],
          const Divider(height: 16, color: Color(0xFFFFF0F5)),
          isLoading
              ? _buildLoadingPriceRow(S.of(context).bookingTotal)
              : _buildPaymentRow(
                  S.of(context).bookingTotal,
                  totalPrice,
                  strong: true,
                  highlight: true,
                ),
          if (_selectedBranch != null && !isLoading) ...[
            const Divider(height: 16, color: Color(0xFFFFF0F5)),
            _buildDepositDetails(totalPrice),
          ],
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

  Widget _buildDepositDetails(int totalPrice) {
    final depositInfo = PriceFormatter.getDepositInfo(
      _selectedBranch?['depositConfig'],
      totalPrice,
    );
    final depositConfigText = depositInfo['displayText'] as String;
    final depositAmount = depositInfo['amount'] as int;

    return Column(
      children: [
        _buildPaymentRowWithText('Tỷ lệ cọc:', depositConfigText, muted: true),
        const SizedBox(height: 8),
        _buildPaymentRow(
          'Tiền cọc cần thanh toán:',
          depositAmount,
          strong: true,
          highlight: true,
        ),
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
          name: widget.nailData!['name']?.toString() ??
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
            child: Text(
              name,
              style: const TextStyle(fontSize: 14, color: Colors.green),
            ),
          ),
          Text(
            _formatDiscountDisplay(rawDisplay),
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
    var text = value.trim();
    if (text.isEmpty) return text;
    text = text.replaceAll(RegExp(r'^-+'), '');
    text = '-$text';
    final lower = text.toLowerCase();
    if (lower.contains('đ') || lower.contains('vnd')) return text;
    return '$text VNĐ';
  }

  Widget _buildPromotionSelector() {
    final selectedPromotion = _promotions.where(
      (voucher) => voucher.promotionId == _selectedPromotionId,
    );
    final selectedLabel = selectedPromotion.isEmpty
        ? 'Chọn voucher từ ví của bạn'
        : '${selectedPromotion.first.promotionName} (${selectedPromotion.first.displayDiscount})';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF2ECE6)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                  color: Color(0xFFFFF5F8),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.local_offer_rounded,
                  size: 18,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voucher trong ví',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.5,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedLabel,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_isLoadingPromotions)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.primary,
                  ),
                )
              else
                IconButton(
                  onPressed: () => setState(
                    () => _isPromotionExpanded = !_isPromotionExpanded,
                  ),
                  icon: Icon(
                    _isPromotionExpanded
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          if (_isPromotionExpanded) ...[
            const SizedBox(height: 8),
            if (!_isLoadingPromotions && _promotions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  'Ví của bạn chưa có voucher khả dụng.',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            Material(
              type: MaterialType.transparency,
              child: RadioListTile<int>(
                value: 0,
                groupValue: _selectedPromotionId ?? 0,
                onChanged: (_) => _handlePromotionChanged(null),
                title: const Text('Không áp dụng'),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
                selectedTileColor: Colors.transparent,
              ),
            ),
            ..._promotions.map(
              (voucher) => Material(
                type: MaterialType.transparency,
                child: RadioListTile<int>(
                  value: voucher.promotionId,
                  groupValue: _selectedPromotionId ?? 0,
                  onChanged: (id) => _handlePromotionChanged(id),
                  title: Text(
                    voucher.promotionName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${voucher.displayDiscount} • Còn ${voucher.remainingCount} lượt'
                    '${voucher.description.isNotEmpty ? ' • ${voucher.description}' : ''}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                  selectedTileColor: Colors.transparent,
                ),
              ),
            ),
          ],
        ],
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

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(_bookingSteps.length, (index) {
          final step = _bookingSteps[index];
          final isCompleted = index < _currentStep;
          final isActive = index == _currentStep;

          return Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left connector line
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      height: 1.5,
                      color: index == 0
                          ? Colors.transparent
                          : (isCompleted || isActive
                                ? AppColors.primary
                                : Colors.grey.shade300),
                    ),
                  ),
                ),
                // Step Circle
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      width: 30,
                      height: 30,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive
                            ? Colors.white
                            : (isCompleted
                                  ? AppColors.primary
                                  : Colors.grey.shade50),
                        border: Border.all(
                          color: (isActive || isCompleted)
                              ? AppColors.primary
                              : Colors.grey.shade300,
                          width: isActive ? 2 : 1.2,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withValues(alpha: 0.35),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Icon(
                          step['icon'] as IconData,
                          size: 14,
                          color: isCompleted
                              ? Colors.white
                              : (isActive
                                    ? AppColors.primary
                                    : Colors.grey.shade400),
                        ),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      step['title'] as String,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: (isActive || isCompleted)
                            ? FontWeight.bold
                            : FontWeight.normal,
                        color: (isActive || isCompleted)
                            ? AppColors.primaryDark
                            : Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
                // Right connector line
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(top: 14),
                    child: Container(
                      height: 1.5,
                      color: index == _bookingSteps.length - 1
                          ? Colors.transparent
                          : (isCompleted
                                ? AppColors.primary
                                : Colors.grey.shade300),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            if (_currentStep > 0)
              OutlinedButton(
                onPressed: _isSubmitting ? null : _handleBackAction,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  side: const BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                ),
                child: Text(
                  S.of(context).bookingBackBtn,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              )
            else
              const SizedBox.shrink(),
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Container(
                  height: 48,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: _isSubmitting
                          ? [Colors.grey.shade400, Colors.grey.shade500]
                          : [AppColors.primary, const Color(0xFFFF80AB)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      if (!_isSubmitting)
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
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
                        borderRadius: BorderRadius.circular(24),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 32),
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
                        : Text(
                            _currentStep == 4
                                ? S.of(context).bookingPayBtn
                                : S.of(context).bookingContinueBtn,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
              ),
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
