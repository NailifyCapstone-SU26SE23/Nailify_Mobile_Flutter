import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../generated/l10n.dart';
import '../../../nails/data/models/nail_variant_model.dart';
import '../../../nails/data/models/shape_method_config_model.dart';
import '../../data/datasources/booking_api_service.dart';
import '../../data/datasources/payment_api_service.dart';
import '../../data/datasources/promotion_api_service.dart';
import '../../data/models/booking_mock_data.dart';
import '../../data/models/wallet_voucher_model.dart';
import '../widgets/artist_selection_list.dart';
import '../widgets/booking_date_selection.dart';
import '../widgets/booking_time_selection.dart';
import '../widgets/branch_selection_list.dart';
import '../widgets/service_choice_step.dart';

/// Trang đặt lịch mới từ HomeBanner.
///
/// Quy trình 5 bước:
///   0. Chọn salon → 1. Chọn thợ → 2. Chọn dịch vụ (nail + addon)
///   → 3. Ngày + giờ → 4. Hoàn tất (thanh toán)
class HomeBookingPage extends StatefulWidget {
  const HomeBookingPage({super.key});

  @override
  State<HomeBookingPage> createState() => _HomeBookingPageState();
}

class _HomeBookingPageState extends State<HomeBookingPage> {
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

  // ── Data ─────────────────────────────────────────
  List<dynamic> _salons = [];
  List<dynamic> _services = [];
  List<dynamic> _artists = [];
  List<dynamic> _timeSlots = [];
  List<WalletVoucherModel> _promotions = [];
  Map<String, dynamic>? _priceReview;

  // ── Selection ────────────────────────────────────
  Map<String, dynamic>? _selectedBranch;
  Map<String, dynamic>? _selectedStylist;
  bool _noArtistSelected = false;
  NailVariantModel? _selectedNailVariant;
  ShapeMethodConfigModel? _selectedShapeMethod;
  List<String?> _selectedExtraServices = [];
  DateTime? _selectedDate;
  String? _selectedTime;
  int? _selectedPromotionId;

  @override
  void initState() {
    super.initState();
    _fetchSalons();
    _fetchServices();
    _fetchPromotions();
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    _cancelCurrentHold();
    _pageController.dispose();
    super.dispose();
  }

  // ── Getters ──────────────────────────────────────
  int get _selectedNailVariantId => _selectedNailVariant?.nailVariantId ?? 0;
  double get _nailVariantPrice => _selectedNailVariant?.price ?? 0;
  num get _shapeMethodPrice => _selectedShapeMethod?.price ?? 0;
  int get _selectedExtraServicesTotal => _selectedExtraServices
      .whereType<String>()
      .fold<int>(0, (sum, id) => sum + _servicePriceById(id));

  int get _estimatedTotalPrice {
    return (_nailVariantPrice + _shapeMethodPrice).round() +
        _selectedExtraServicesTotal;
  }

  String get _normalizedSelectedTime {
    final time = _selectedTime ?? '';
    return time.length == 5 ? '$time:00' : time;
  }

  List<Map<String, dynamic>> get _availableServices {
    final source = _services.isEmpty
        ? BookingMockData.extraServices
        : _services;
    return source
        .whereType<Map>()
        .map((s) => Map<String, dynamic>.from(s))
        .toList();
  }

  // ── Fetch APIs ──────────────────────────────────
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
      _showSnackBar('Lỗi tải danh sách salon: $e');
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

  Future<void> _fetchArtists(String salonId) async {
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
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingArtists = false);
      _showSnackBar('Lỗi tải danh sách thợ: $e');
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
      _showSnackBar('Lỗi tải khung giờ: $e');
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
      final items = _buildBookingItems();
      final data = await _apiService.getSalonAvailableSlots(
        salonId: _selectedBranch!['salonId'],
        bookingDate: _formatBookingDate(_selectedDate!),
        bookingItems: items,
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

  // ── Hold slot ────────────────────────────────────
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

  // ── Booking items / payload ──────────────────────
  List<Map<String, dynamic>> _buildBookingItems() {
    return [
      if (_selectedNailVariantId > 0)
        {
          'nailVariantId': _selectedNailVariantId,
          if (_selectedShapeMethod != null)
            'shapeMethodConfigId': _selectedShapeMethod!.shapeMethodConfigId,
          'quantity': 1,
        },
      ..._selectedExtraServices.whereType<String>().map(
        (id) => {'serviceId': id, 'quantity': 1},
      ),
    ];
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
      'selectedPromotionIds': _selectedPromotionId == null
          ? null
          : [_selectedPromotionId!],
    };
  }

  String _formatBookingDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-${d}T00:00:00';
  }

  String _serviceId(Map<String, dynamic> service) =>
      service['serviceId']?.toString() ?? service['id']?.toString() ?? '';

  String _serviceName(Map<String, dynamic> service) =>
      service['serviceName']?.toString() ?? service['name']?.toString() ?? '';

  String _serviceNameById(String? id) {
    if (id == null) return '';
    final matches = _availableServices.where((s) => _serviceId(s) == id);
    if (matches.isEmpty) return id;
    final name = _serviceName(matches.first);
    return name.isEmpty ? id : name;
  }

  int _servicePriceById(String? id) {
    if (id == null) return 0;
    final matches = _availableServices.where((s) => _serviceId(s) == id);
    if (matches.isEmpty) return 0;
    final price = matches.first['price'] ?? matches.first['basePrice'];
    if (price is num) return price.round();
    return int.tryParse(price?.toString() ?? '') ?? 0;
  }

  // ── Selection handlers ───────────────────────────
  void _handleBranchSelected(dynamic branch) {
    _cancelCurrentHold();
    final map = Map<String, dynamic>.from(branch as Map);
    setState(() {
      _selectedBranch = map;
      _selectedDate = null;
      _selectedStylist = null;
      _selectedTime = null;
      _noArtistSelected = false;
      _selectedNailVariant = null;
      _selectedShapeMethod = null;
      _selectedExtraServices = [];
      _artists = [];
      _timeSlots = [];
      _priceReview = null;
    });
    _fetchArtists(map['salonId']?.toString() ?? '');
  }

  void _handleStylistSelected(Map<String, dynamic>? stylist) {
    _cancelCurrentHold();
    setState(() {
      _selectedStylist = stylist;
      _selectedTime = null;
      _noArtistSelected = stylist == null;
      // Reset nail variant nếu đổi thợ
      _selectedNailVariant = null;
      _selectedShapeMethod = null;
      _priceReview = null;
    });
  }

  void _handleArtistModeChanged(bool isNoArtist) {
    _cancelCurrentHold();
    setState(() {
      _noArtistSelected = isNoArtist;
      _selectedStylist = null;
      _selectedTime = null;
      _selectedNailVariant = null;
      _selectedShapeMethod = null;
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

  void _handleExtraServicesChanged(List<String?> services) {
    setState(() {
      _selectedExtraServices = services;
      _priceReview = null;
    });
  }

  void _handleNailVariantChanged(NailVariantModel? variant) {
    setState(() {
      _selectedNailVariant = variant;
      if (variant == null) _selectedShapeMethod = null;
      _priceReview = null;
    });
  }

  void _handleShapeMethodChanged(ShapeMethodConfigModel? method) {
    setState(() {
      _selectedShapeMethod = method;
      _priceReview = null;
    });
  }

  void _handlePromotionChanged(int? id) {
    // Fix bug "nhảy giá": KHÔNG clear _priceReview — giữ giá cũ hiển
    // thị trong khi API tính giá mới với voucher.
    setState(() {
      _selectedPromotionId = id;
      _priceReviewKey = null;
      _isReviewingPrice = true;
      // _priceReview CỐ Ý KHÔNG clear
    });
    if (_currentStep == 4) _reviewPrice();
  }

  // ── Price review ────────────────────────────────
  String get _priceReviewRequestKey {
    final serviceIds = _selectedExtraServices.whereType<String>().toList()
      ..sort();
    return [
      _selectedBranch?['salonId']?.toString() ?? '',
      _selectedDate == null ? '' : _formatBookingDate(_selectedDate!),
      _selectedTime ?? '',
      _noArtistSelected
          ? ''
          : _selectedStylist?['nailArtistId']?.toString() ?? '',
      _selectedNailVariantId.toString(),
      _selectedShapeMethod?.shapeMethodConfigId.toString() ?? '',
      serviceIds.join(','),
      (_selectedPromotionId?.toString() ?? ''),
    ].join('|');
  }

  Future<void> _reviewPrice() async {
    if (_selectedBranch == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      return;
    }
    final key = _priceReviewRequestKey;
    if (_priceReview != null && _priceReviewKey == key) return;
    if (_inFlightPriceReviewKey == key && _inFlightPriceReview != null) {
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
          nailVariantId: _selectedNailVariantId,
          serviceIds: _selectedExtraServices.whereType<String>().toList(),
          selectedPromotionIds: _selectedPromotionId == null
              ? null
              : [_selectedPromotionId!],
          shapeMethodConfigId: _selectedShapeMethod?.shapeMethodConfigId,
        );
        if (!mounted) return;
        if (_priceReviewRequestKey != key) return;
        setState(() {
          _priceReview = review;
          _priceReviewKey = key;
        });
      } catch (_) {
        // Bỏ qua lỗi, summary vẫn hiển thị giá ước tính
      }
    }();
    _inFlightPriceReviewKey = key;
    _inFlightPriceReview = reviewFuture;
    try {
      await reviewFuture;
    } finally {
      if (_inFlightPriceReviewKey == key) {
        _inFlightPriceReviewKey = null;
        _inFlightPriceReview = null;
        if (mounted) setState(() => _isReviewingPrice = false);
      }
    }
  }

  // ── Execute booking ─────────────────────────────
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

  // ── Navigation ──────────────────────────────────
  Future<void> _handleBack() async {
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

  Future<void> _handleNext() async {
    // Fix bug: trước đây button "Tiếp tục" chỉ disable khi `_isSubmitting`
    // (chỉ true ở `_executeBooking`). Khi user bấm "Tiếp tục" ở step "chọn
    // ngày/giờ" → step "tổng quan", hệ thống gọi `_createHoldForSummary`
    // (API hold-slot mất 1–3 giây) mà KHÔNG có loading. User dễ bấm nhầm
    // nhiều lần → gọi API hold-slot trùng lặp.
    //
    // Sau fix: set `_isSubmitting = true` ngay từ đầu khi cần xử lý async
    // (hold-slot hoặc submit booking). Button sẽ disable + spinner ngay.
    if (_isSubmitting) return; // chống bấm đúp khi đang xử lý

    if (_currentStep == 0 && _selectedBranch == null) {
      _showSnackBar(S.of(context).bookingValidateSalon);
      return;
    }
    if (_currentStep == 1 && _selectedStylist == null && !_noArtistSelected) {
      _showSnackBar('Vui lòng chọn thợ hoặc chọn "Tự động phân công"!');
      return;
    }
    if (_currentStep == 2) {
      // Cần chọn ít nhất 1 nail variant hoặc 1 dịch vụ
      final hasNail = _selectedNailVariant != null;
      final hasServices = _selectedExtraServices.whereType<String>().isNotEmpty;
      if (!hasNail && !hasServices) {
        _showSnackBar('Vui lòng chọn ít nhất một mẫu nail hoặc dịch vụ!');
        return;
      }
    }
    if (_currentStep == 3 && (_selectedDate == null || _selectedTime == null)) {
      _showSnackBar(S.of(context).bookingValidateDateTime);
      return;
    }

    if (_currentStep < 4) {
      // Bước sang step kế tiếp. Nếu từ step "chọn ngày/giờ" (index 3) →
      // step "tổng quan" (index 4) thì cần tạo hold-slot → bật loading.
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
      // Step cuối (index 4): thanh toán → _executeBooking tự set _isSubmitting.
      _executeBooking();
    }
  }

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Build ───────────────────────────────────────
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
          onPressed: _handleBack,
        ),
        title: Text(
          'Đặt lịch nhanh',
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
              // Fix bug "nhảy giá": KHÔNG clear _priceReview khi vào step 4.
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
      child: ServiceChoiceStep(
        selectedArtistId: _noArtistSelected
            ? null
            : _selectedStylist?['nailArtistId'],
        services: _availableServices,
        selectedExtraServices: _selectedExtraServices,
        onExtraServicesChanged: _handleExtraServicesChanged,
        selectedNailVariant: _selectedNailVariant,
        onNailVariantChanged: _handleNailVariantChanged,
        selectedShapeMethod: _selectedShapeMethod,
        onShapeMethodChanged: _handleShapeMethodChanged,
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
          _buildSummaryCard(),
          const SizedBox(height: 24),
          _buildPromotionSelector(),
          const SizedBox(height: 24),
          _buildPaymentDetails(),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
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
    // Fix bug "nhảy giá": KHÔNG fallback _estimatedTotalPrice khi đang loading
    // voucher. Hiển thị placeholder row thay vì giá 0.
    final bool isLoading = _isReviewingPrice && _priceReview == null;
    final int totalPrice = reviewTotal is num
        ? reviewTotal.round()
        : isLoading
        ? 0
        : int.tryParse(reviewTotal?.toString() ?? '') ?? _estimatedTotalPrice;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
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
          if (_selectedNailVariant != null) _buildNailVariantRow(),
          ..._selectedExtraServices.whereType<String>().map(
            (id) => _buildPaymentRow(
              S.of(context).bookingExtraService(_serviceNameById(id)),
              _servicePriceById(id),
              muted: true,
            ),
          ),
          const Divider(height: 16),
          // Fix bug "nhảy giá": hiển thị placeholder thay vì giá 0.
          isLoading
              ? _buildLoadingPriceRow(S.of(context).bookingTotal)
              : _buildPaymentRow(
                  S.of(context).bookingTotal,
                  totalPrice,
                  strong: true,
                  highlight: true,
                ),
          if (_selectedBranch != null && !isLoading) ...[
            const Divider(height: 16),
            _buildDepositDetails(totalPrice),
          ],
        ],
      ),
    );
  }

  Widget _buildNailVariantRow() {
    final name = _selectedNailVariant?.name ?? 'Mẫu nail';
    final price = (_nailVariantPrice + _shapeMethodPrice).round();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ),
          Text(
            PriceFormatter.format(price),
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
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
    final configText = depositInfo['displayText'] as String;
    final amount = depositInfo['amount'] as int;
    return Column(
      children: [
        _buildPaymentRowText('Tỷ lệ cọc:', configText, muted: true),
        const SizedBox(height: 8),
        _buildPaymentRow(
          'Tiền cọc cần thanh toán:',
          amount,
          strong: true,
          highlight: true,
        ),
      ],
    );
  }

  // Fix bug "nhảy giá": placeholder row khi đang tính giá voucher mới.
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

  Widget _buildPaymentRowText(
    String label,
    String value, {
    bool muted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: muted ? Colors.grey : AppColors.textPrimary,
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionSelector() {
    final selected = _promotions.where(
      (p) => p.promotionId == _selectedPromotionId,
    );
    final selectedLabel = selected.isEmpty
        ? 'Chọn voucher từ ví của bạn'
        : '${selected.first.promotionName} (${selected.first.displayDiscount})';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
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
            // Lựa chọn "Không áp dụng" — phải bọc Material để hiện ink ripple.
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
              (v) => Material(
                type: MaterialType.transparency,
                child: RadioListTile<int>(
                  value: v.promotionId,
                  groupValue: _selectedPromotionId ?? 0,
                  onChanged: (id) => _handlePromotionChanged(id),
                  title: Text(
                    v.promotionName,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${v.displayDiscount} • Còn ${v.remainingCount} lượt'
                    '${v.description.isNotEmpty ? ' • ${v.description}' : ''}',
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

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
                                  color: AppColors.primary.withValues(
                                    alpha: 0.25,
                                  ),
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
            color: Colors.black.withValues(alpha: 0.05),
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
                onPressed: _isSubmitting ? null : _handleBack,
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
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                    ],
                  ),
                  child: ElevatedButton(
                    onPressed: _isSubmitting ? null : _handleNext,
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
