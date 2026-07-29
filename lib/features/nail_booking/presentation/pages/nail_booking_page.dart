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
import '../../data/datasources/promotion_api_service.dart';
import '../../data/models/booking_mock_data.dart';
import '../../data/models/promotion_model.dart';
import '../widgets/booking_date_selection.dart';
import '../widgets/booking_service_selection.dart';
import '../widgets/booking_stylist_selection.dart';
import '../widgets/booking_time_selection.dart';
import '../widgets/branch_selection_list.dart';

class NailBookingPage extends StatefulWidget {
  final Map<String, dynamic>? nailData;

  const NailBookingPage({super.key, this.nailData});

  @override
  State<NailBookingPage> createState() => _NailBookingPageState();
}

class _NailBookingPageState extends State<NailBookingPage> {
  final PageController _pageController = PageController();
  final BookingApiService _apiService = BookingApiService();
  final PromotionApiService _promotionApiService = PromotionApiService();

  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _isLoadingSalons = true;
  bool _isLoadingArtists = false;
  bool _isLoadingTimes = false;
  bool _isLoadingPromotions = false;
  bool _isPromotionExpanded = false;
  bool _isReviewingPrice = false;

  List<dynamic> _salons = [];
  List<dynamic> _services = [];
  List<dynamic> _artists = [];
  List<dynamic> _timeSlots = [];
  List<PromotionModel> _promotions = [];
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
    {'title': S.of(context).bookingStepSelectSalon, 'icon': Icons.storefront_rounded},
    {'title': S.of(context).bookingStepServices, 'icon': Icons.spa_rounded},
    {'title': S.of(context).bookingStepBook, 'icon': Icons.calendar_month_rounded},
    {'title': S.of(context).bookingStepCompleted, 'icon': Icons.check_circle_rounded},
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
      final data = await _promotionApiService.getTodayPromotions(
        pageNumber: 1,
        pageSize: 20,
      );
      if (!mounted) return;
      setState(() {
        _promotions = data
            .where((promotion) => promotion.isSelectable)
            .toList();
        _isLoadingPromotions = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingPromotions = false);
      _showSnackBar('Loi tai khuyen mai: $e');
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
        _timeSlots = data;
        _isLoadingTimes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingTimes = false);
      _showSnackBar('Loi tai khung gio: $e');
    }
  }

  void _loadSalonSlots() {
    if (_selectedBranch == null || _selectedDate == null) return;
    setState(() {
      _timeSlots = _apiService.getSalonOperatingSlots(
        _selectedBranch!,
        _selectedDate!,
      );
      _selectedTime = null;
      _isLoadingTimes = false;
    });
  }

  Future<void> _reviewPrice() async {
    if (_selectedBranch == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      return;
    }

    setState(() => _isReviewingPrice = true);
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
      setState(() => _priceReview = review);
    } catch (e) {
      if (mounted) _showSnackBar('Loi tinh gia: $e');
    } finally {
      if (mounted) setState(() => _isReviewingPrice = false);
    }
  }

  Future<void> _executeBooking() async {
    AuthGuard.check(context, () async {
      if (_isSubmitting) return;
      setState(() => _isSubmitting = true);

      try {
        final booking = await _apiService.createBooking(
          _selectedBranch!['salonId'],
          _formatBookingDate(_selectedDate!),
          _normalizedSelectedTime,
          _noArtistSelected
              ? null
              : _selectedStylist?['nailArtistId'] as String?,
          _nailVariantId,
          _selectedExtraServices.whereType<String>().toList(),
          selectedPromotionIds: _selectedPromotionIds,
          shapeMethodConfigId: _shapeMethodConfigId,
        );

        if (!mounted) return;
        context.go(
          '/booking-success',
          extra: {
            'bookingId': booking['bookingId']?.toString() ?? '',
            'serviceName': widget.nailData?['name'] ?? 'Lam mong',
            'date': _selectedDate,
            'time': _normalizedSelectedTime,
            'price': booking['price'] ?? _priceReview?['price'],
            'discount': booking['discount'] ?? _priceReview?['discount'],
            'totalPrice': booking['totalPrice'] ?? _priceReview?['totalPrice'],
            'discounts':
                booking['discounts'] ??
                booking['discountBreakdown'] ??
                _priceReview?['discounts'] ??
                _priceReview?['discountBreakdown'],
            'stylistName': _noArtistSelected
                ? 'Tu dong phan cong'
                : (_selectedStylist?['fullName'] ?? 'Bat ky'),
          },
        );
      } catch (e) {
        _showSnackBar('Loi dat lich: $e');
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    });
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

  void _handleBranchSelected(dynamic branch) {
    setState(() {
      _selectedBranch = Map<String, dynamic>.from(branch as Map);
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
      _selectedStylist = null;
      _selectedTime = null;
      _priceReview = null;
      _artists = [];
      _timeSlots = [];
    });

    if (_selectedBranch != null && _selectedDate != null) {
      _fetchArtists();
    }
  }

  void _handleDateChanged(DateTime date) {
    setState(() {
      _selectedDate = date;
      _selectedStylist = null;
      _selectedTime = null;
      _noArtistSelected = false;
      _priceReview = null;
      _artists = [];
      _timeSlots = [];
    });
    _fetchArtists();
  }

  void _handleStylistSelected(Map<String, dynamic>? stylist) {
    setState(() {
      _selectedStylist = stylist;
      _selectedTime = null;
      _noArtistSelected = stylist == null;
      _priceReview = null;
    });
    _fetchTimeSlots();
  }

  void _handleArtistModeChanged(bool isNoArtist) {
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
      _priceReview = null;
    });
    if (_currentStep == 3) {
      _reviewPrice();
    }
  }

  void _handleBackAction() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.pop();
    }
  }

  void _handleNextAction() {
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
    if (_currentStep == 2 &&
        (_selectedDate == null ||
            (_selectedStylist == null && !_noArtistSelected) ||
            _selectedTime == null)) {
      _showSnackBar(S.of(context).bookingValidateDateTime);
      return;
    }

    if (_currentStep < 3) {
      if (_currentStep == 2) {
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.primaryDark),
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
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (idx) => setState(() => _currentStep = idx),
              children: [
                _buildSalonStep(),
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
          BookingStylistSelection(
            artists: _artists,
            isLoading: _isLoadingArtists,
            selectedStylistId: _selectedStylist?['nailArtistId'],
            noArtistSelected: _noArtistSelected,
            isDateSelected: _selectedDate != null,
            onStylistSelected: _handleStylistSelected,
            onModeChanged: _handleArtistModeChanged,
          ),
          const SizedBox(height: 28),
          BookingTimeSelection(
            timeSlots: _timeSlots,
            isLoading: _isLoadingTimes,
            selectedTime: _selectedTime,
            canSelect:
                _selectedDate != null &&
                (_selectedStylist != null || _noArtistSelected),
            selectedDate: _selectedDate,
            salonId: _selectedBranch?['salonId'],
            artistId: _selectedStylist?['nailArtistId'],
            onTimeChanged: (time) => setState(() {
              _selectedTime = time;
              _priceReview = null;
            }),
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
    final totalPrice = reviewTotal is num
        ? reviewTotal.round()
        : int.tryParse(reviewTotal?.toString() ?? '') ?? _estimatedTotalPrice;

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
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
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
          _buildPaymentRow(
            S.of(context).bookingTotal,
            totalPrice,
            strong: true,
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildNailVariantPaymentItem() {
    final variant = _nailVariantDetail;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPaymentRow(
            widget.nailData!['name']?.toString() ?? S.of(context).bookingNailVariantDefault,
            _nailVariantPrice + _shapeMethodPrice.round(),
          ),
          if (variant != null) ...[
            const SizedBox(height: 4),

            if (variant.nailShape != null)
              _buildVariantDetailLine(_shapeMethodName!, _shapeMethodPrice),
            ...variant.nailComponents.map((component) {
              final detail = component.component;
                return _buildVariantDetailLine(
                detail?.name ?? S.of(context).bookingComponentDefault,
                detail?.price ?? 0,
              );
            }),
          ],
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

  Widget _buildVariantDetailLine(String label, num price) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ),
          Text(
            PriceFormatter.format(price),
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
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
                ? amountDisplay!
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

  Widget _buildPromotionSelector() {
    final selectedPromotion = _promotions.where(
      (promotion) => promotion.promotionId == _selectedPromotionId,
    );
    final selectedLabel = selectedPromotion.isEmpty
        ? S.of(context).bookingNoPromotion
        : selectedPromotion.first.name;

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
                      S.of(context).bookingPromotion,
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
            RadioListTile<int>(
              value: 0,
              groupValue: _selectedPromotionId ?? 0,
              onChanged: (_) => _handlePromotionChanged(null),
              title: Text(S.of(context).bookingNoApply),
              dense: true,
              contentPadding: EdgeInsets.zero,
              activeColor: AppColors.primary,
            ),
            if (!_isLoadingPromotions && _promotions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  S.of(context).bookingNoPromotionAvailable,
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ..._promotions.map(
              (promotion) => RadioListTile<int>(
                value: promotion.promotionId,
                groupValue: _selectedPromotionId ?? 0,
                onChanged: _handlePromotionChanged,
                title: Text(
                  promotion.name,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: Text(
                  promotion.description.isNotEmpty
                      ? '${promotion.discountLabel} - ${promotion.description}'
                      : promotion.discountLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
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
                          : (isCompleted || isActive ? AppColors.primary : Colors.grey.shade300),
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
                            : (isCompleted ? AppColors.primary : Colors.grey.shade50),
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
                                )
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Icon(
                          step['icon'] as IconData,
                          size: 16,
                          color: isCompleted
                              ? Colors.white
                              : (isActive ? AppColors.primary : Colors.grey.shade400),
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
                          : (isCompleted ? AppColors.primary : Colors.grey.shade300),
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
                          _currentStep == 3
                              ? S.of(context).bookingConfirmBtn
                              : S.of(context).bookingContinueBtn,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
