import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../generated/l10n.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../../../core/utils/price_formatter.dart';
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
import '../widgets/branch_selection_list.dart';
import '../widgets/artist_selection_list.dart';

class NailBookingPage extends StatefulWidget {
  final Map<String, dynamic>? nailData;

  const NailBookingPage({super.key, this.nailData});

  @override
  State<NailBookingPage> createState() => _NailBookingPageState();
}

class _NailBookingPageState extends State<NailBookingPage> {
  final PageController _pageController = PageController();
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
    {
      'title': 'Chọn thợ',
      'icon': Icons.person_pin_rounded,
    },
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
    try {
      final data = await _apiService.getSalons();
      if (!mounted) return;
      setState(() {
        _salons = data;
        _isLoadingSalons = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingSalons = false);
      _showSnackBar('Loi tai danh sach salon: $e');
    }
  }

  Future<void> _fetchServices() async {
    try {
      final data = await _apiService.getServices();
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

  Future<void> _fetchNailVariantDetail() async {
    final id = _nailVariantId;
    if (id <= 0) return;
    try {
      final variant = await getIt<NailVariantRepository>().getNailVariantById(
        id,
      );
      if (!mounted) return;
      setState(() => _nailVariantDetail = variant);
    } catch (e) {
      debugPrint('Failed to load nail variant detail: $e');
    }
  }

  Future<void> _fetchArtists() async {
    if (_selectedBranch == null || _selectedDate == null) return;
    setState(() {
      _isLoadingArtists = true;
      _artists = [];
      _selectedStylist = null;
      _selectedTime = null;
      _noArtistSelected = false;
    });

    try {
      final data = await _apiService.getSuggestedArtists(
        _selectedBranch!['salonId'],
        _formatBookingDate(_selectedDate!),
        _nailVariantId,
        _selectedExtraServices.whereType<String>().toList(),
        _shapeMethodConfigId,
      );
      if (!mounted) return;
      setState(() {
        _artists = data;
        _isLoadingArtists = false;
        _noArtistSelected = _artists.isEmpty;
      });
      if (_artists.isEmpty) {
        _loadSalonSlots();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingArtists = false);
      _showSnackBar('Loi tai danh sach tho: $e');
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
    });

    try {
      final data = await _apiService.getArtistAvailableSlots(
        _selectedStylist!['nailArtistId'],
        _formatBookingDate(_selectedDate!),
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
      setState(() => _isLoadingTimes = false);
      _showSnackBar('Loi tai khung gio: $e');
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

      final data = await _apiService.getSalonAvailableSlots(
        salonId: _selectedBranch!['salonId'],
        bookingDate: _formatBookingDate(_selectedDate!),
        bookingItems: bookingItems,
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
      setState(() => _isLoadingTimes = false);
      _showSnackBar('Lỗi tải khung giờ salon: $e');
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
    await _cancelCurrentHold();
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isUrgent ? Colors.red.shade600 : Colors.orange.shade700,
      child: Row(
        children: [
          const Icon(Icons.lock_clock, color: Colors.white, size: 18),
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
      setState(() {
        _artists = data;
        _isLoadingArtists = false;
      });
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
    _cancelCurrentHold();
    // Fix bug: trước đây `_handleServiceChanged` xóa luôn `_selectedStylist`
    // khi user đính kèm dịch vụ (ngâm chân thảo mộc, cắt da tay...). Sau đó
    // sang step 3 chọn ngày → `_handleDateChanged` thấy `_selectedStylist
    // == null` → nhảy vào `_loadSalonSlots()` → gọi SAI API
    // `POST /api/Bookings/salon-available-slots` thay vì
    // `GET /api/Bookings/artist-available-slots?NailArtistId=...`.
    //
    // Sau fix: KHÔNG xóa thợ. Chỉ clear time + priceReview + slots; thợ vẫn
    // được giữ nguyên. Khi user sang step 3 chọn ngày, `_handleDateChanged`
    // sẽ thấy `_selectedStylist != null` → gọi `_fetchTimeSlots()` đúng API.
    setState(() {
      _selectedExtraServices = services;
      _selectedTime = null;
      _priceReview = null;
      _timeSlots = [];
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
    // Fix bug "nhảy giá":
    // - Trước fix: setState clear `_priceReview = null` khiến UI lập tức fallback
    //   `_estimatedTotalPrice` (= 740k = nail variant + shape + extras) trong
    //   lúc chờ API tính giá mới → hiển thị nhầm giá 740k rồi mới trả 368k.
    // - Sau fix: KHÔNG clear `_priceReview` ngay. Giữ giá cũ hiển thị + bật
    //   spinner `_isReviewingPrice = true` cho tới khi API trả về `_priceReview`
    //   mới (có/không voucher). Reset `_priceReviewKey = null` để `_reviewPrice()`
    //   hiểu là cần gọi API mới thay vì trả về cache cũ.
    setState(() {
      _selectedPromotionId = promotionId;
      _priceReviewKey = null;
      // _priceReview CỐ Ý KHÔNG clear → giữ giá cũ trong lúc loading
      _isReviewingPrice = true;
    });
    if (_currentStep == 4) {
      _reviewPrice();
    }
  }

  Future<void> _handleBackAction() async {
    if (_currentStep == 3) {
      await _cancelCurrentHold();
      if (!mounted) return;
    }
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
    if (_currentStep == 0 && _selectedBranch == null) {
      _showSnackBar(S.of(context).bookingValidateSalon);
      return;
    }
    if (_currentStep == 1 &&
        _selectedStylist == null &&
        !_noArtistSelected) {
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
        final held = await _createHoldForSummary();
        if (!held) return;
        _reviewPrice();
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
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
              // Fix bug "nhảy giá" lần 2:
              // - Trước fix: nếu _priceReviewKey != requestKey thì clear
              //   _priceReview = null → UI fallback 740k trong lúc API load.
              // - Sau fix: KHÔNG clear _priceReview. Nếu requestKey khác key
              //   hiện tại (voucher/extras đã đổi) thì reset _priceReviewKey
              //   để _reviewPrice() biết cần fetch mới, nhưng giữ _priceReview
              //   cũ hiển thị + bật spinner cho tới khi API trả.
              onPageChanged: (idx) {
                setState(() => _currentStep = idx);
                if (idx == 4) {
                  if (_priceReviewKey != _priceReviewRequestKey) {
                    setState(() {
                      _priceReviewKey = null;
                      _isReviewingPrice = true;
                      // _priceReview cố ý KHÔNG clear
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
        border: Border.all(color: Colors.grey.shade100),
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
            Icons.face_3_rounded,
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

    // Fix bug "nhảy giá":
    // - Nếu có _priceReview → dùng trực tiếp (giá cũ vẫn OK, không fallback 740k)
    // - Nếu KHÔNG có _priceReview VÀ đang loading → hiển thị loading indicator
    //   thay vì fallback `_estimatedTotalPrice` (= 740k) gây nhầm lẫn.
    // - Nếu KHÔNG có _priceReview VÀ không loading → fallback (chưa chọn time)
    //   chỉ xảy ra khi step 4 chưa có dữ liệu để review.
    final bool _isLoading = _isReviewingPrice && _priceReview == null;
    final int totalPrice = reviewTotal is num
        ? reviewTotal.round()
        : _isLoading
            ? 0 // placeholder — sẽ hiển thị loading indicator
            : int.tryParse(reviewTotal?.toString() ?? '') ??
                _estimatedTotalPrice;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              Expanded(
                child: Text(
                  S.of(context).bookingPaymentDetails,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              if (_isReviewingPrice)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.nailData != null) _buildNailVariantPaymentItem(),
          ..._selectedExtraServices.whereType<String>().map((serviceId) {
            return _buildPaymentRow(
              S.of(context).bookingExtraService(_serviceNameById(serviceId)),
              _servicePriceById(serviceId),
              muted: true,
            );
          }),
          const Divider(height: 16),
          ..._discountBreakdown.map(_buildDiscountRow),
          const Divider(height: 16),
          // Fix bug "nhảy giá": hiển thị placeholder loading thay vì giá 0
          // khi đang chờ API tính giá voucher mới.
          _isLoading
              ? _buildLoadingPriceRow(S.of(context).bookingTotal)
              : _buildPaymentRow(
                  S.of(context).bookingTotal,
                  totalPrice,
                  strong: true,
                  highlight: true,
                ),
          if (_selectedBranch != null && !_isLoading) ...[
            const Divider(height: 16),
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

  // Fix bug "nhảy giá": placeholder row hiển thị spinner + chữ "Đang tính giá..."
  // khi user chọn voucher và API đang load. Thay vì hiển thị giá 0 hoặc
  // fallback 740k gây nhầm lẫn.
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
                  color: muted ? Colors.grey : AppColors.textPrimary,
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
              fontSize: highlight ? 18 : 14,
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
                  color: muted ? Colors.grey : AppColors.textPrimary,
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
              fontSize: highlight ? 18 : 14,
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

  Widget _buildDiscountRow(Map<String, dynamic> discount) {
    final name = discount['name']?.toString() ?? 'Giam gia';
    final amount = discount['amount'] ?? 0;
    final amountDisplay = discount['amountDisplay']?.toString();
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
            amountDisplay?.isNotEmpty == true
                ? _formatDiscountDisplay(amountDisplay!)
                : '-${PriceFormatter.format(amount)}',
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
    final text = value.trim();
    if (text.isEmpty) return text;
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
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              const Icon(Icons.local_offer_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Voucher trong ví',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
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
                  child: CircularProgressIndicator(strokeWidth: 2),
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
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
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
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
                    padding: const EdgeInsets.only(top: 17),
                    child: Container(
                      height: 2,
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
                      width: 36,
                      height: 36,
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
                          width: isActive ? 2.5 : 1.5,
                        ),
                        boxShadow: isActive
                            ? [
                                BoxShadow(
                                  color: AppColors.primary.withOpacity(0.25),
                                  blurRadius: 8,
                                  spreadRadius: 1,
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Icon(
                          step['icon'] as IconData,
                          size: 16,
                          color: isCompleted
                              ? Colors.white
                              : (isActive
                                    ? AppColors.primary
                                    : Colors.grey.shade400),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      step['title'] as String,
                      // Already localized from getter
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
                    padding: const EdgeInsets.only(top: 17),
                    child: Container(
                      height: 2,
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
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
                    borderRadius: BorderRadius.circular(25),
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
                          color: AppColors.primary.withOpacity(0.3),
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
