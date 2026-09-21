import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/retry_helper.dart';
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
import '../widgets/payment_detail_table.dart';
import '../widgets/service_choice_step.dart';
import '../widgets/sleek_booking_step_indicator.dart';
import '../widgets/booking_promotion_sheet.dart';

/// Trang đặt lịch mới từ HomeBanner.
///
/// Quy trình 5 bước:
///   0. Chọn salon → 1. Chọn thợ → 2. Chọn dịch vụ (nail + addon)
///   → 3. Ngày + giờ → 4. Hoàn tất (thanh toán)
class HomeBookingPage extends StatefulWidget {
  final Map<String, dynamic>? initialData;

  const HomeBookingPage({super.key, this.initialData});

  @override
  State<HomeBookingPage> createState() => _HomeBookingPageState();
}

class _HomeBookingPageState extends State<HomeBookingPage> {
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
  bool _isReviewingPrice = false;

  String? _holdToken;
  Timer? _holdTimer;
  int _holdRemainingSeconds = 0;
  bool _isHolding = false;
  String? _priceReviewKey;
  String? _inFlightPriceReviewKey;
  Future<void>? _inFlightPriceReview;

  // ── Load-error fields (dùng để hiển thị retry view khi API fail) ─
  bool _useWalletBalance = false;
  bool _isLoadingWallet = false;
  double? _walletAvailableBalance;

  // ── Load-error fields (dùng để hiển thị retry view khi API fail) ─
  String? _salonsLoadError;
  String? _artistsLoadError;
  String? _timesLoadError;

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
    _parseInitialData();
    _pageController = PageController(initialPage: _currentStep);
    _fetchSalons();
    _fetchServices();
    _fetchPromotions();
    _fetchWalletBalance();
  }

  void _parseInitialData() {
    final init = widget.initialData;
    if (init == null) return;

    if (init['salon'] is Map) {
      _selectedBranch = Map<String, dynamic>.from(init['salon'] as Map);
    } else if (init['salonId'] != null) {
      _selectedBranch = {
        'salonId': init['salonId'].toString(),
        'name': init['salonName']?.toString() ?? 'Salon',
      };
    }

    if (init['artist'] is Map) {
      _selectedStylist = Map<String, dynamic>.from(init['artist'] as Map);
      _noArtistSelected = false;
    } else if (init['artistId'] != null) {
      _selectedStylist = {
        'nailArtistId': init['artistId'].toString(),
        'fullName': init['artistName']?.toString() ?? 'Thợ nail',
        'salonId': init['salonId']?.toString() ?? '',
      };
      _noArtistSelected = false;
    }

    if (_selectedBranch != null && _selectedStylist != null) {
      _currentStep = 2;
    } else if (_selectedBranch != null) {
      _currentStep = 1;
    }
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

  int? get _reviewSubtotal {
    final value = _priceReview?['price'];
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
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
    setState(() => _salonsLoadError = null);
    try {
      final data = await RetryHelper.run(
        () => _apiService.getSalons(),
        shouldRetry: RetryHelper.defaultShouldRetry,
      );
      if (!mounted) return;
      setState(() {
        _salons = data;
        _isLoadingSalons = false;
        _salonsLoadError = null;
      });
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

  Future<void> _fetchWalletBalance() async {
    setState(() => _isLoadingWallet = true);
    try {
      final response = await _apiService.getCustomerWalletSummary();
      if (!mounted) return;
      setState(() {
        _walletAvailableBalance =
            (response?['balance'] as num?)?.toDouble() ?? 0.0;
        _isLoadingWallet = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingWallet = false);
    }
  }

  Future<void> _fetchArtistsForSalon() async {
    if (_selectedBranch == null) return;
    final salonId = _selectedBranch!['salonId']?.toString() ?? '';
    if (salonId.isEmpty) return;

    setState(() {
      _isLoadingArtists = true;
      _artists = [];
      _artistsLoadError = null;
    });

    try {
      final data = await RetryHelper.run(
        () => _apiService.getNailArtistsBySalon(salonId),
        shouldRetry: RetryHelper.defaultShouldRetry,
      );
      if (!mounted) return;
      setState(() {
        _artists = data;
        _isLoadingArtists = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoadingArtists = false;
        _artistsLoadError = 'Không tải được danh sách thợ: $e';
      });
      _showSnackBar('Không tải được danh sách thợ. Bấm "Thử lại" để tải lại.');
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
      final rawSlots = await RetryHelper.run(
        () => _apiService.getArtistAvailableSlots(
          _selectedStylist!['nailArtistId'],
          _formatBookingDate(_selectedDate!),
          bookingItems: bookingItems,
        ),
        shouldRetry: RetryHelper.defaultShouldRetry,
      );
      if (!mounted) return;
      final filtered = _apiService.filterSlotsByOperatingHours(
        slots: rawSlots,
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
      _timesLoadError = null;
    });
    try {
      final items = _buildBookingItems();
      final rawSlots = await RetryHelper.run(
        () => _apiService.getSalonAvailableSlots(
          salonId: _selectedBranch!['salonId'],
          bookingDate: _formatBookingDate(_selectedDate!),
          bookingItems: items,
        ),
        shouldRetry: RetryHelper.defaultShouldRetry,
      );
      if (!mounted) return;
      final filtered = _apiService.filterSlotsByOperatingHours(
        slots: rawSlots,
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
    if (_isHolding && _holdToken != null && _holdRemainingSeconds > 0) {
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
      debugPrint('holdSlot failed: $e');
      _showHoldFailureMessage(e.toString());
      return false;
    }
  }

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

  String _extractServerMessage(String rawMessage) {
    String msg = rawMessage.trim();
    if (msg.isEmpty ||
        msg.toLowerCase() == 'null' ||
        msg.toLowerCase() == 'exception') {
      return 'Không thể giữ khung giờ này. Vui lòng chọn giờ khác.';
    }
    return msg;
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
        if (_currentStep > 3) {
          _pageController.animateToPage(
            3,
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
    final List<Map<String, dynamic>> items = [];
    if (_selectedNailVariantId > 0) {
      items.add({
        'nailVariantId': _selectedNailVariantId,
        if (_selectedShapeMethod != null)
          'shapeMethodConfigId': _selectedShapeMethod!.shapeMethodConfigId,
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
      items.add({
        'serviceId': entry.key,
        'quantity': entry.value,
      });
    }
    return items;
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
      'useWalletBalance': _useWalletBalance,
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
    _fetchArtistsForSalon();
  }

  void _handleStylistSelected(Map<String, dynamic>? stylist) {
    _cancelCurrentHold();
    setState(() {
      _selectedStylist = stylist;
      _selectedTime = null;
      _noArtistSelected = stylist == null;
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
    setState(() {
      _selectedPromotionId = id;
      _priceReviewKey = null;
      _isReviewingPrice = true;
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
      _useWalletBalance.toString(),
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

        final status = paymentData['status']?.toString().toUpperCase() ?? '';
        final qrCode = paymentData['qrCode']?.toString() ?? '';
        final paymentUrl = paymentData['paymentUrl']?.toString() ?? '';

        if (status == 'PAID' || status == 'SUCCESS' || (qrCode.isEmpty && paymentUrl.isEmpty)) {
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

  // ── Navigation ──────────────────────────────────
  Future<void> _handleBack() async {
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
    if (_isSubmitting) return;

    // Step 0: Chọn tiệm
    if (_currentStep == 0 && _selectedBranch == null) {
      _showSnackBar(S.of(context).bookingValidateSalon);
      return;
    }

    // Step 1: Chọn thợ quen
    if (_currentStep == 1) {
      if (!_noArtistSelected && _selectedStylist == null) {
        _showSnackBar('Vui lòng chọn thợ nail hoặc chọn "Để Nailify sắp xếp"!');
        return;
      }
    }

    // Step 2: Chọn dịch vụ
    if (_currentStep == 2) {
      final hasNail = _selectedNailVariant != null;
      final hasServices = _selectedExtraServices.whereType<String>().isNotEmpty;
      if (!hasNail && !hasServices) {
        _showSnackBar('Vui lòng chọn ít nhất một mẫu nail hoặc dịch vụ!');
        return;
      }
    }

    // Step 3: Chọn ngày & khung giờ
    if (_currentStep == 3) {
      if (_selectedDate == null) {
        _showSnackBar('Vui lòng chọn ngày đặt lịch!');
        return;
      }
      if (_selectedTime == null) {
        _showSnackBar('Vui lòng chọn khung giờ!');
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

  // ── Build ───────────────────────────────────────
  List<Map<String, dynamic>> get _bookingSteps => [
    {
      'title': S.of(context).bookingStepSelectSalon,
      'icon': Icons.storefront_rounded,
    },
    {
      'title': S.of(context).bookingStepArtist,
      'icon': Icons.person_pin_rounded,
    },
    {
      'title': S.of(context).bookingStepServices,
      'icon': Icons.spa_rounded,
    },
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
                if (idx == 1) {
                  if (_artists.isEmpty && _selectedBranch != null) {
                    _fetchArtistsForSalon();
                  }
                } else if (idx == 3) {
                  if (_selectedDate != null && _timeSlots.isEmpty) {
                    if (_noArtistSelected) {
                      _loadSalonSlots();
                    } else if (_selectedStylist != null) {
                      _fetchTimeSlots();
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
                _buildArtistStep(),
                _buildServiceStep(),
                _buildDateAndTimeStep(),
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

  Widget _buildArtistStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
                        color: !_noArtistSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: !_noArtistSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          'Tự chọn thợ quen',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: !_noArtistSelected ? AppColors.primary : Colors.grey.shade700,
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
                        color: _noArtistSelected ? Colors.white : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: _noArtistSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                )
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          'Để Nailify sắp xếp',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: _noArtistSelected ? AppColors.primary : Colors.grey.shade700,
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
          if (!_noArtistSelected) ...[
            if (_artistsLoadError != null && !_isLoadingArtists)
              _buildRetryView(
                message: _artistsLoadError!,
                onRetry: _fetchArtistsForSalon,
              )
            else
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
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primary.withValues(alpha: 0.2)),
              ),
              child: const Column(
                children: [
                  Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 36),
                  SizedBox(height: 12),
                  Text(
                    'Nailify sẽ tự động sắp xếp thợ phù hợp nhất cho bạn tại tiệm đã chọn.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildServiceStep() {
    return ServiceChoiceStep(
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
    );
  }

  Widget _buildDateAndTimeStep() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingDateSelection(
            selectedDate: _selectedDate,
            onDateChanged: _handleDateChanged,
          ),
          const SizedBox(height: 24),
          if (_selectedDate != null) ...[
            if (_timesLoadError != null && !_isLoadingTimes)
              _buildRetryView(
                message: _timesLoadError!,
                onRetry: _noArtistSelected ? _loadSalonSlots : _fetchTimeSlots,
              )
            else
              BookingTimeSelection(
                timeSlots: _timeSlots,
                isLoading: _isLoadingTimes,
                selectedTime: _selectedTime,
                canSelect: true,
                selectedDate: _selectedDate,
                salonId: _selectedBranch?['salonId'],
                artistId: _noArtistSelected
                    ? null
                    : _selectedStylist?['nailArtistId'],
                onTimeChanged: (time) {
                  _cancelCurrentHold();
                  setState(() {
                    _selectedTime = time;
                    _priceReview = null;
                  });
                },
              ),
          ] else ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Vui lòng chọn ngày để xem khung giờ trống',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
                ),
              ),
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
    final timeStr =
        _selectedTime == null ? '' : _selectedTime!.substring(0, 5);
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
                    3,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
    final selectedPromotion =
        _promotions.where((v) => v.promotionId == _selectedPromotionId);
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
                            horizontal: 6, vertical: 1.5),
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
                      ? 'Số dư: ${PriceFormatter.format(balance!.round())}'
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
              activeColor: Colors.white,
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
            : int.tryParse(reviewTotal?.toString() ?? '') ??
                _estimatedTotalPrice;
    final int subtotalPrice = _reviewSubtotal ?? _estimatedTotalPrice;

    final depositInfo = PriceFormatter.getDepositInfo(
      _selectedBranch?['depositConfig'],
      totalPrice,
    );
    final initialDepositAmount = depositInfo['amount'] as int;

    final walletDeduction = (_useWalletBalance &&
            _walletAvailableBalance != null &&
            _walletAvailableBalance! > 0)
        ? (_walletAvailableBalance! < initialDepositAmount
            ? _walletAvailableBalance!.round()
            : initialDepositAmount)
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
            painter: const _HorizontalDashedLinePainter(color: Color(0xFFE5E7EB)),
          ),
          const SizedBox(height: 14),
          _buildInvoiceRow('Tạm tính', subtotalPrice, isNegative: false),
          for (final discount in _discountBreakdown)
            _buildDiscountInvoiceRow(discount),
          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 14),
          isLoading
              ? _buildLoadingPriceRow(S.of(context).bookingTotal)
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
            _buildDepositDetails(totalPrice, initialDepositAmount, walletDeduction),
          ],
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(String label, num amount, {required bool isNegative}) {
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
              color: isNegative ? const Color(0xFFE02B6D) : AppColors.textPrimary,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountInvoiceRow(Map<String, dynamic> discount) {
    final name = discount['name']?.toString() ?? 'Ưu đãi';
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
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
    final depositAmountToPay =
        (initialDepositAmount - walletDeduction).clamp(0, initialDepositAmount);

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              S.of(context).bookingDepositRatioLabel,
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
            ),
            Text(
              depositConfigText,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
            ),
          ],
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
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              S.of(context).bookingDepositAmountLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              PriceFormatter.format(depositAmountToPay),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFE02B6D),
                fontSize: 16,
              ),
            ),
          ],
        ),
      ],
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
    final variantPrice = (_nailVariantPrice + _shapeMethodPrice).round();
    if (_selectedNailVariant != null && variantPrice > 0) {
      items.add(
        PaymentTableItem(
          name: _selectedNailVariant?.name ?? 'Mẫu nail',
          quantity: 1,
          unitPrice: variantPrice,
        ),
      );
    }
    final counts = <String, int>{};
    for (final id in _selectedExtraServices.whereType<String>()) {
      counts[id] = (counts[id] ?? 0) + 1;
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

  List<Map<String, dynamic>> get _discountBreakdown {
    final raw =
        _priceReview?['discountBreakdown'] ?? _priceReview?['discounts'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => Map<String, dynamic>.from(m))
        .toList();
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

  Widget _buildFooter() {
    final bool isFirstStep = _currentStep == 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
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
        child: isFirstStep
            ? SizedBox(
                width: double.infinity,
                height: 52,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                    gradient: LinearGradient(
                      colors: _isSubmitting
                          ? [Colors.grey.shade400, Colors.grey.shade500]
                          : [const Color(0xFFFF4081), const Color(0xFFD81B60)],
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
                    onPressed: _isSubmitting ? null : _handleNext,
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
                    onPressed: _isSubmitting ? null : _handleBack,
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
                        onPressed: _isSubmitting ? null : _handleNext,
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
                            : (_currentStep == 4
                                ? Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      const Icon(Icons.lock_rounded, size: 18),
                                      const SizedBox(width: 6),
                                      Text(
                                        S.of(context).bookingPayBtn,
                                        style: const TextStyle(
                                          fontSize: 15.5,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ],
                                  )
                                : Text(
                                    S.of(context).bookingContinueBtn,
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )),
                      ),
                    ),
                  ),
                ],
              ),
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
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant _HorizontalDashedLinePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}
