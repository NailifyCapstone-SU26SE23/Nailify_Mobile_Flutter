import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../generated/l10n.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/auth_guard.dart';
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
  bool _isPromotionExpanded = false;
  bool _isReviewingPrice = false;
  String? _holdToken;
  Timer? _holdTimer;
  int _holdRemainingSeconds = 0;
  bool _isHolding = false;

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

  final List<Map<String, dynamic>> _bookingSteps = [
    {'title': 'Dịch vụ', 'icon': Icons.spa_rounded},
    {'title': 'Đặt lịch', 'icon': Icons.calendar_month_rounded},
    {'title': 'Hoàn tất', 'icon': Icons.check_circle_rounded},
  ];

  @override
  void initState() {
    super.initState();
    _selectedShapeMethod = _initialShapeMethod;
    _shapeMethodsFuture = _loadShapeMethods();
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

  int get _shapeMethodPrice => (_selectedShapeMethod?.price ?? 0).round();

  String get _shapeMethodName =>
      _selectedShapeMethod?.name ?? 'Phuong phap tao form';

  Map<String, int> get _groupedServicesMap {
    final map = <String, int>{};
    for (final id in _selectedExtraServices.whereType<String>()) {
      map[id] = (map[id] ?? 0) + 1;
    }
    return map;
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

  int? get _reviewSubtotal {
    final value = _priceReview?['price'];
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
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

    setState(() {
      _isLoadingTimes = true;
      _timeSlots = [];
      _selectedTime = null;
    });

    try {
      final times = await _apiService.getArtistAvailableSlots(
        artistId,
        _formatBookingDate(_selectedDate!),
      );
      if (!mounted) return;
      setState(() {
        _timeSlots = _apiService.filterSlotsByOperatingHours(
          slots: times,
          salon: widget.nail.salonData,
          date: _selectedDate,
        );
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
        context.go('/payment-qr', extra: paymentData);
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
    await _cancelCurrentHold();
    final hold = await _createHold();
    final token = hold?['holdToken']?.toString();
    if (token == null || token.isEmpty) {
      _showSnackBar('Không thể giữ khung giờ này. Vui lòng chọn giờ khác.');
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
      'salonId': widget.nail.salonId,
      'bookingDate': _formatBookingDate(_selectedDate!),
      'startTime': _normalizedSelectedTime,
      'nailArtistId': widget.nail.nailArtistId,
      'holdToken': holdToken,
      'bookingItems': _buildBookingItems(),
      'selectedPromotionIds': _selectedPromotionIds,
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
    _cancelCurrentHold();
    setState(() {
      _selectedExtraServices = services;
      _selectedTime = null;
      _timeSlots = [];
      _priceReview = null;
    });
    _reviewPrice();
    if (_selectedDate != null) _fetchTimeSlots();
  }

  Future<void> _handleBackAction() async {
    if (_currentStep == 2) {
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
    if (_currentStep == 0 && _selectedExtraServices.contains(null)) {
      _showSnackBar('Vui long chon hoac xoa dich vu dang bo trong.');
      return;
    }
    if (_currentStep == 1 && (_selectedDate == null || _selectedTime == null)) {
      _showSnackBar('Vui long chon ngay va khung gio.');
      return;
    }

    if (_currentStep < 2) {
      if (_currentStep == 1) {
        final held = await _createHoldForSummary();
        if (!held) return;
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
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
                _buildStepIndicator(),
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
                    subtitle: Text('${method.duration} phút'),
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
            onTimeChanged: (time) {
              _cancelCurrentHold();
              setState(() => _selectedTime = time);
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
          const Text(
            'Xác nhận thông tin',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildSummaryCard(),
          const SizedBox(height: 24),
          _buildPromotionSelector(),
          const SizedBox(height: 24),
          _buildPaymentDetails(),
        ],
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

  Widget _buildSummaryCard() {
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
            Icons.calendar_month_rounded,
            'Ngày hẹn',
            _selectedDate == null
                ? ''
                : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
          ),
          _buildSummaryRow(
            Icons.access_time_rounded,
            'Thời gian',
            _selectedTime == null ? '' : _selectedTime!.substring(0, 5),
          ),
          _buildSummaryRow(
            Icons.face_3_rounded,
            'Thợ thực hiện',
            widget.nail.stylistName,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetails() {
    final double customPrice =
        (widget.nail.customerNailPrice + widget.nail.surfacePrice).toDouble();
    final double customFee = widget.nail.price.toDouble();
    final double servicesTotal = _groupedServicesMap.entries.fold<double>(
      0.0,
      (sum, entry) => sum + (_servicePriceById(entry.key) * entry.value),
    );
    final double subtotal = customPrice + customFee + servicesTotal;
    final reviewPrice = _priceReview?['price'];
    final price = reviewPrice is num
        ? reviewPrice.round()
        : int.tryParse(reviewPrice?.toString() ?? '') ?? subtotal.round();
    final reviewTotal = _priceReview?['totalPrice'];
    final totalPrice = reviewTotal is num
        ? reviewTotal.round()
        : int.tryParse(reviewTotal?.toString() ?? '') ?? subtotal.round();
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
              const Expanded(
                child: Text(
                  'Chi tiết thanh toán',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          _buildCustomerNailPaymentItem(),
          if (widget.nail.price > 0) ...[
            const SizedBox(height: 8),
            _buildPaymentLine('Phí custom', widget.nail.price),
          ],
          ..._groupedServicesMap.entries.map((entry) {
            return _buildPaymentLine(
              '${entry.value}x ${_serviceNameById(entry.key)}',
              _servicePriceById(entry.key) * entry.value,
              muted: true,
            );
          }),
          const Divider(height: 16),
          _buildPaymentLine('Tạm tính', price, muted: true),
          ..._discountBreakdown.map(_buildDiscountRow),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng cộng',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                PriceFormatter.format(totalPrice),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          if (widget.nail.salonData != null) ...[
            const Divider(height: 16),
            _buildDepositDetails(totalPrice),
          ],
        ],
      ),
    );
  }

  Widget _buildCustomerNailPaymentItem() {
    final detailRows = <Map<String, dynamic>>[];
    if (widget.nail.surfaceName.isNotEmpty) {
      detailRows.add({
        'name': widget.nail.surfaceName,
        'price': widget.nail.surfacePrice,
        'quantity': 1,
      });
    }
    if (_shapeMethodPrice > 0) {
      detailRows.add({
        'name': _shapeMethodName,
        'price': _shapeMethodPrice,
        'quantity': 1,
      });
    }
    detailRows.addAll(_customerComponentRows());

    return Column(
      children: [
        _buildPaymentLine(
          'Thiết kế móng: ${widget.nail.name}',
          widget.nail.customerNailPrice + _shapeMethodPrice,
        ),
        if (detailRows.isNotEmpty) ...[
          const SizedBox(height: 4),
          const _PriceTableHeader(),
          const SizedBox(height: 2),
          ...detailRows.map(_buildDetailPriceLine),
        ],
      ],
    );
  }

  List<Map<String, dynamic>> _customerComponentRows() {
    final rowsByKey = <String, Map<String, dynamic>>{};
    final components = widget.nail.customerNailComponents.whereType<Map>().map(
      (component) => Map<String, dynamic>.from(component),
    );

    for (final component in components) {
      final label = _customerComponentLabel(component);
      final price = _customerComponentPrice(component);
      final quantity = _customerComponentFingerIndex(component) == -1 ? 5 : 1;
      final key = '${_customerComponentId(component)}|$label|$price';
      final existing = rowsByKey[key];
      if (existing == null) {
        rowsByKey[key] = {'name': label, 'price': price, 'quantity': quantity};
      } else {
        existing['quantity'] = (existing['quantity'] as int) + quantity;
      }
    }

    return rowsByKey.values.toList();
  }

  Widget _buildDetailPriceLine(Map<String, dynamic> row) {
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

  String _customerComponentLabel(Map<String, dynamic> component) {
    final nested = component['component'] ?? component['customerComponent'];
    String? type;
    if (nested is Map) {
      type = nested['componentType']?.toString().trim();
    }
    type ??= component['componentType']?.toString().trim();
    final name = _customerComponentName(component);
    return type == null || type.isEmpty ? name : '$type: $name';
  }

  Object? _customerComponentId(Map<String, dynamic> component) {
    final nested = component['component'] ?? component['customerComponent'];
    if (nested is Map) {
      return nested['componentId'] ??
          nested['customerComponentId'] ??
          component['componentId'] ??
          component['customerComponentId'];
    }
    return component['componentId'] ?? component['customerComponentId'];
  }

  int? _customerComponentFingerIndex(Map<String, dynamic> component) {
    final value = component['fingerIndex'] ?? component['FingerIndex'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _customerComponentName(Map<String, dynamic> component) {
    final nested = component['component'] ?? component['customerComponent'];
    if (nested is Map) {
      final name = nested['name']?.toString().trim();
      if (name != null && name.isNotEmpty) return name;
    }
    final name = component['name']?.toString().trim();
    return name == null || name.isEmpty ? 'Thành phần custom' : name;
  }

  num _customerComponentPrice(Map<String, dynamic> component) {
    final nested = component['component'] ?? component['customerComponent'];
    if (nested is Map) {
      final price = nested['price'] ?? nested['Price'];
      if (price is num) return price;
      final parsed = num.tryParse(price?.toString() ?? '');
      if (parsed != null) return parsed;
    }
    final price = component['price'] ?? component['Price'];
    if (price is num) return price;
    return num.tryParse(price?.toString() ?? '') ?? 0;
  }

  Widget _buildPaymentLine(
    String label,
    num price, {
    bool strong = false,
    bool muted = false,
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
                  fontSize: 14,
                  color: muted ? Colors.grey : AppColors.textPrimary,
                  fontWeight: strong ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
          Text(
            price > 0 ? PriceFormatter.format(price) : '',
            style: TextStyle(
              fontWeight: strong ? FontWeight.bold : FontWeight.w600,
              color: strong ? AppColors.primary : AppColors.textPrimary,
              fontSize: strong ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentLineWithText(
    String label,
    String valueText, {
    bool strong = false,
    bool muted = false,
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
                  fontSize: 14,
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
              color: strong ? AppColors.primary : AppColors.textPrimary,
              fontSize: strong ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDepositDetails(int totalPrice) {
    final depositInfo = PriceFormatter.getDepositInfo(
      widget.nail.salonData?['depositConfig'],
      totalPrice,
    );
    final depositConfigText = depositInfo['displayText'] as String;
    final depositAmount = depositInfo['amount'] as int;

    return Column(
      children: [
        _buildPaymentLineWithText('Tỷ lệ cọc:', depositConfigText, muted: true),
        const SizedBox(height: 8),
        _buildPaymentLine(
          'Tiền cọc cần thanh toán:',
          depositAmount,
          strong: true,
        ),
      ],
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
    final label = _selectedPromotions.isEmpty
        ? 'Chọn voucher từ ví của bạn'
        : 'Đã chọn ${_selectedPromotions.length} voucher';

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
          Row(
            children: [
              const Icon(Icons.local_offer_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(fontWeight: FontWeight.bold),
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
            if (_promotions.isEmpty)
              const Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Ví của bạn chưa có voucher khả dụng.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ..._promotions.map((voucher) {
              final selected = _selectedPromotions.any(
                (item) => item.promotionId == voucher.promotionId,
              );
              // Wrap Material để hiện ink ripple bình thường cho CheckboxListTile
              return Material(
                type: MaterialType.transparency,
                child: CheckboxListTile(
                  value: selected,
                  onChanged: (checked) {
                    setState(() {
                      if (checked == true) {
                        _selectedPromotions = [..._selectedPromotions, voucher];
                      } else {
                        _selectedPromotions = _selectedPromotions
                            .where(
                              (item) => item.promotionId != voucher.promotionId,
                            )
                            .toList();
                      }
                      _priceReview = null;
                    });
                    _reviewPrice();
                  },
                  title: Text(voucher.promotionName),
                  subtitle: Text(
                    '${voucher.displayDiscount} • Còn ${voucher.remainingCount} lượt'
                    '${voucher.description.isNotEmpty ? ' • ${voucher.description}' : ''}',
                  ),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  activeColor: AppColors.primary,
                  selectedTileColor: Colors.transparent,
                ),
              );
            }),
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
                      () {
                        final rawTitle = step['title'] as String;
                        if (rawTitle == 'Chọn tiệm') {
                          return S.of(context).selectSalon;
                        }
                        if (rawTitle == 'Dịch vụ') {
                          return S.of(context).servicesLabel;
                        }
                        if (rawTitle == 'Đặt lịch') {
                          return S.of(context).bookAppointment;
                        }
                        if (rawTitle == 'Hoàn tất') {
                          return S.of(context).completedLabel;
                        }
                        return rawTitle;
                      }(),
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
                child: const Text(
                  'Quay lại',
                  style: TextStyle(
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
                            _currentStep == 2 ? 'Thanh toán' : 'Tiếp tục',
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
          Expanded(flex: 5, child: Text('Thành phần', style: style)),
          SizedBox(
            width: 38,
            child: Text('SL', style: style, textAlign: TextAlign.center),
          ),
          SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text('Giá', style: style, textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}
