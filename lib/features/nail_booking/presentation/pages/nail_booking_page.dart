import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../../../core/utils/price_formatter.dart';

import '../../data/datasources/booking_api_service.dart';
import '../../data/datasources/promotion_api_service.dart';
import '../../data/models/booking_mock_data.dart';
import '../../data/models/promotion_model.dart';
import '../widgets/branch_selection_list.dart';
import '../widgets/booking_service_selection.dart';
import '../widgets/booking_date_selection.dart';
import '../widgets/booking_stylist_selection.dart';
import '../widgets/booking_time_selection.dart';

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
  int _currentStep = 0; // 0: Salon, 1: Service, 2: DateTime & Staff, 3: Summary
  bool _isSubmitting = false;

  // API Lists
  List<dynamic> _salons = [];
  List<dynamic> _services = [];
  List<dynamic> _artists = [];
  List<dynamic> _timeSlots = [];
  List<PromotionModel> _promotions = [];

  bool _isLoadingSalons = true;
  bool _isLoadingArtists = false;
  bool _isLoadingTimes = false;
  bool _isLoadingPromotions = false;
  bool _isPromotionExpanded = false;
  bool _isReviewingPrice = false;
  Map<String, dynamic>? _priceReview;
  NailVariantModel? _nailVariantDetail;

  // User State
  Map<String, dynamic>? _selectedBranch;
  List<String?> _selectedExtraServices = [];
  DateTime? _selectedDate;
  Map<String, dynamic>? _selectedStylist;
  String? _selectedTime;
  int? _selectedPromotionId;
  bool _noArtistSelected = false; // Khách không chọn thợ, hệ thống tự phân công
  int get _nailVariantPrice {
    final price = widget.nailData?['price'];
    if (price is num) return price.round();
    return int.tryParse(price?.toString() ?? '') ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _fetchSalons();
    _fetchServices();
    _fetchPromotions();
    _fetchNailVariantDetail();
  }

  int get _nailVariantId {
    return int.tryParse(widget.nailData?['id']?.toString() ?? '0') ?? 0;
  }

  int? get _shapeMethodConfigId {
    final value = widget.nailData?['shapeMethodConfigId'];
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String? get _shapeMethodName {
    final value = widget.nailData?['shapeMethodName']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  num get _shapeMethodPrice {
    final value = widget.nailData?['shapeMethodPrice'];
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
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

  String _formatBookingDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return "$y-$m-${d}T00:00:00";
  }

  Future<void> _fetchSalons() async {
    try {
      final data = await _apiService.getSalons();
      setState(() {
        _salons = data;
        _isLoadingSalons = false;
      });
    } catch (e) {
      setState(() => _isLoadingSalons = false);
      _showSnackBar('Lỗi tải danh sách Salon: $e');
    }
  }

  Future<void> _fetchArtists() async {
    if (_selectedBranch == null || _selectedDate == null) return;
    setState(() {
      _isLoadingArtists = true;
      _artists = [];
      _selectedStylist = null;
      _selectedTime = null;
    });
    try {
      final dateStr = _formatBookingDate(_selectedDate!);
      final data = await _apiService.getSuggestedArtists(
        _selectedBranch!['salonId'],
        dateStr,
        _nailVariantId,
        _selectedExtraServices
            .whereType<String>()
            .toList(), // Lọc bỏ null trước khi gọi API
        _shapeMethodConfigId,
      );
      setState(() {
        _artists = data;
        _isLoadingArtists = false;
        if (_artists.isEmpty) {
          _noArtistSelected = true;
        }
      });
      if (_artists.isEmpty) {
        _fetchTimeSlots();
      }
    } catch (e) {
      setState(() => _isLoadingArtists = false);
      _showSnackBar('Lỗi tải danh sách thợ: $e');
    }
    final cubit = context.read<NailBookingCubit>();
    cubit.loadSalons();
    cubit.loadServices();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  Future<void> _fetchTimeSlots() async {
    if (_noArtistSelected) {
      // Không chọn thợ: generate slots từ lịch salon
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
      final dateStr = _formatBookingDate(_selectedDate!);
      final data = await _apiService.getArtistAvailableSlots(
        _selectedStylist!['nailArtistId'],
        dateStr,
      );
      setState(() {
        _timeSlots = data;
        _isLoadingTimes = false;
      });
    } catch (e) {
      setState(() => _isLoadingTimes = false);
      _showSnackBar('Lỗi tải khung giờ: $e');
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
    });
  }

  Future<void> _executeBooking() async {
    AuthGuard.check(context, () async {
      if (_isSubmitting) return;
      setState(() => _isSubmitting = true);
      try {
        final formattedTime = _selectedTime!.length == 5
            ? "$_selectedTime:00"
            : _selectedTime!;
        final artistId = _noArtistSelected
            ? null
            : _selectedStylist?['nailArtistId'] as String?;

        final booking = await _apiService.createBooking(
          _selectedBranch!['salonId'],
          _formatBookingDate(_selectedDate!),
          formattedTime,
          artistId,
          _nailVariantId,
          _selectedExtraServices.whereType<String>().toList(),
          shapeMethodConfigId: _shapeMethodConfigId,
          selectedPromotionIds: _selectedPromotionIds,
        );

        if (!mounted) return;

        final bookingDetails = {
          'bookingId': booking['bookingId']?.toString() ?? '',
          'serviceName': widget.nailData?['name'] ?? 'Làm móng',
          'date': _selectedDate,
          'time': formattedTime,
          'price': booking['price'] ?? _priceReview?['price'],
          'discount': booking['discount'] ?? _priceReview?['discount'],
          'totalPrice': booking['totalPrice'] ?? _priceReview?['totalPrice'],
          'discounts':
              booking['discounts'] ??
              booking['discountBreakdown'] ??
              _priceReview?['discounts'] ??
              _priceReview?['discountBreakdown'],
          'stylistName': _noArtistSelected
              ? 'Tự động phân công'
              : (_selectedStylist?['fullName'] ?? 'Bất kỳ'),
        };
        context.go('/booking-success', extra: bookingDetails);
      } catch (e) {
        _showSnackBar('Lỗi đặt lịch: $e');
      } finally {
        if (mounted) setState(() => _isSubmitting = false);
      }
    });
  }

  void _handleBackAction() {
    if (_currentStep > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.pop();
    }
  }

  Future<void> _fetchServices() async {
    try {
      final data = await _apiService.getServices();
      setState(() => _services = data);
    } catch (_) {
      setState(() => _services = BookingMockData.extraServices);
    }
  }

  Future<void> _fetchPromotions() async {
    setState(() => _isLoadingPromotions = true);
    try {
      final data = await _promotionApiService.getVouchers();
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
      _showSnackBar('Failed to load promotions: $e');
    }
  }

  List<int>? get _selectedPromotionIds {
    final id = _selectedPromotionId;
    return id == null ? null : [id];
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

  // Fix: Nhận String? để tránh lỗi Mismatch
  String _serviceNameById(String? serviceId) {
    if (serviceId == null) return '';
    final services = _availableServices.where(
      (service) => _serviceId(service) == serviceId,
    );
    return services.isEmpty
        ? serviceId
        : _serviceName(services.first).isEmpty
        ? serviceId
        : _serviceName(services.first);
  }

  // Fix: Chỉ tính tổng tiền của các dịch vụ đã chọn (bỏ qua null)
  int get _selectedExtraServicesTotal {
    return _selectedExtraServices.whereType<String>().fold<int>(
      0,
      (total, serviceId) => total + _servicePriceById(serviceId),
    );
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

  String _serviceId(Map<String, dynamic> service) =>
      service['serviceId']?.toString() ?? service['id']?.toString() ?? '';

  String _serviceName(Map<String, dynamic> service) =>
      service['serviceName']?.toString() ?? service['name']?.toString() ?? '';

  // Fix: Nhận String? để tránh lỗi Mismatch
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

  int get _nailVariantPrice {
    final price = widget.nailData?['price'];
    if (price is num) return price.round();
    return int.tryParse(price?.toString() ?? '') ?? 0;
  }

  int get _estimatedTotalPrice =>
      _nailVariantPrice + _shapeMethodPrice.round() + _selectedExtraServicesTotal;

  bool get _showLegacyNailDataRow => false;

  List<Map<String, dynamic>> get _discountBreakdown {
    final raw =
        _priceReview?['discountBreakdown'] ?? _priceReview?['discounts'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((discount) => Map<String, dynamic>.from(discount))
        .toList();
  }

  Future<void> _reviewPrice() async {
    if (_selectedBranch == null ||
        _selectedDate == null ||
        _selectedTime == null) {
      return;
    }
    setState(() => _isReviewingPrice = true);
    try {
      final formattedTime = _selectedTime!.length == 5
          ? "$_selectedTime:00"
          : _selectedTime!;
      final artistId = _noArtistSelected
          ? null
          : _selectedStylist?['nailArtistId'] as String?;
      final review = await _apiService.reviewBookingPrice(
        salonId: _selectedBranch!['salonId'],
        bookingDate: _formatBookingDate(_selectedDate!),
        startTime: formattedTime,
        artistId: artistId,
        nailVariantId: _nailVariantId,
        serviceIds: _selectedExtraServices.whereType<String>().toList(),
        shapeMethodConfigId: _shapeMethodConfigId,
        selectedPromotionIds: _selectedPromotionIds,
      );
      if (!mounted) return;
      setState(() => _priceReview = review);
    } catch (e) {
      if (mounted) _showSnackBar('Lỗi tính giá: $e');
    } finally {
      if (mounted) setState(() => _isReviewingPrice = false);
    }
  }
  void _handleNextAction(NailBookingState state) {
    final cubit = context.read<NailBookingCubit>();

    if (_currentStep == 0 && state.selectedBranch == null) {
      _showSnackBar('Vui lòng chọn một chi nhánh salon!');
      return;
  void _handleNextAction() {
    if (_currentStep == 0 && _selectedBranch == null) {
      _showSnackBar('Vui lòng chọn một chi nhánh salon!');
      return;
    }
    if (_currentStep == 1) {
      // Bắt lỗi nếu bấm "Thêm dịch vụ" nhưng thả trống Dropdown
      if (_selectedExtraServices.contains(null)) {
        _showSnackBar(
          'Có ô dịch vụ đang bị bỏ trống. Vui lòng chọn hoặc xóa nó đi!',
        );
        return;
      if (state.selectedExtraServices.contains(null)) {
        _showSnackBar(
            'Có ô dịch vụ đang bị bỏ trống. Vui lòng chọn hoặc xóa nó đi!');
        return;
      }
      final validServices = _selectedExtraServices.whereType<String>().toList();
      if (widget.nailData == null && validServices.isEmpty) {
        _showSnackBar('Vui lòng chọn ít nhất 1 dịch vụ để tiếp tục!'); return;
      }
    }
    if (_currentStep == 2 &&
        (_selectedDate == null ||
            (_selectedStylist == null && !_noArtistSelected) ||
            _selectedTime == null)) {
      _showSnackBar(
        'Vui lòng chọn đầy đủ ngày, thợ (hoặc để tự động) và khung giờ!',
      );
      return;
    if (_currentStep == 2) {
      if (state.selectedDate == null) {
        _showSnackBar('Vui lòng chọn ngày hẹn!');
        return;
      }
      if (state.selectedStylist == null && !state.noArtistSelected) {
        _showSnackBar('Vui lòng chọn thợ hoặc chọn "Không chọn thợ"!');
        return;
      }
      if (state.selectedTime == null) {
        _showSnackBar('Vui lòng chọn khung giờ!');
        return;
      }
    }

    if (_currentStep < 3) {
      if (_currentStep == 2) {
        _reviewPrice();
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _executeBooking();
    }
  }

  void _showSnackBar(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  Future<void> _executeBooking(
      NailBookingState state, NailBookingCubit cubit) async {
    AuthGuard.check(context, () async {
      final promos =
          state.selectedPromotions.whereType<PromotionModel>().toList();
      final serviceIds =
          state.selectedExtraServices.whereType<String>().toList();
      final formattedTime = state.selectedTime!.length == 5
          ? '${state.selectedTime}:00'
          : state.selectedTime!;

      try {
        final booking = await cubit.createNailVariantBooking(
          nailVariantId: _nailVariantId,
          serviceIds: serviceIds,
          selectedPromotionIds: promos.isEmpty
              ? null
              : promos.map((p) => p.promotionId).toList(),
        );

        if (!mounted) return;

        context.go('/booking-success', extra: {
          'bookingId': booking['bookingId']?.toString() ?? '',
          'serviceName': widget.nailData?['name'] ?? 'Làm móng',
          'date': state.selectedDate,
          'time': formattedTime,
          'stylistName': state.noArtistSelected
              ? 'Tự động phân công'
              : (state.selectedStylist?['fullName'] ?? 'Bất kỳ'),
        });
      } catch (_) {
        // Error đã được emit vào state.errorMessage và xử lý bởi BlocConsumer
      }
    });
  }


  void _showSnackBar(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: _handleBackAction,
        ),
        title: const Text(
          'Đặt Lịch Hẹn',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: _handleBackAction),
        title: const Text('Đặt Lịch Hẹn',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
                // BƯỚC 1: CHỌN SALON
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: BranchSelectionList(
                    salons: _salons,
                    isLoading: _isLoadingSalons,
                    selectedBranchId: _selectedBranch?['salonId'],
                    onBranchSelected: (branch) =>
                        setState(() => _selectedBranch = branch),
                  ),
                ),
      body: BlocConsumer<NailBookingCubit, NailBookingState>(
        listenWhen: (prev, curr) =>
            curr.errorMessage != null && prev.errorMessage != curr.errorMessage,
        listener: (context, state) {
          _showSnackBar(state.errorMessage!);
          context.read<NailBookingCubit>().clearError();
        },
        builder: (context, state) {
          final cubit = context.read<NailBookingCubit>();
          return Column(
            children: [
              _buildStepIndicator(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (idx) => setState(() => _currentStep = idx),
                  children: [
                    // ── BƯỚC 1: CHỌN SALON ──────────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: BranchSelectionList(
                        salons: state.salons,
                        isLoading: state.isLoadingSalons,
                        selectedBranchId: state.selectedBranch?['salonId'],
                        onBranchSelected: (dynamic branch) =>
                            cubit.selectBranch(
                                Map<String, dynamic>.from(branch as Map)),
                      ),
                    ),

                // BƯỚC 2: CHỌN DỊCH VỤ
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: BookingServiceSelection(
                    nailData: widget.nailData,
                    services: _services,
                    selectedExtraServices: _selectedExtraServices,
                    onChanged: _handleServiceChanged,
                  ),
                ),

                // BƯỚC 3: NGÀY -> THỢ -> GIỜ
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BookingDateSelection(
                        selectedDate: _selectedDate,
                        onDateChanged: (date) {
                          setState(() => _selectedDate = date);
                          _fetchArtists();
                        },
                      ),
                      const SizedBox(height: 24),

                      BookingStylistSelection(
                        artists: _artists,
                        isLoading: _isLoadingArtists,
                        selectedStylistId: _selectedStylist?['nailArtistId'],
                        noArtistSelected: _noArtistSelected,
                        onStylistSelected: (artist) {
                          setState(() {
                            if (artist != null) {
                              _noArtistSelected = false;
                              _selectedStylist = artist;
                              _selectedTime = null;
                            }
                          });
                          if (artist != null) _fetchTimeSlots();
                        },
                        onModeChanged: (isNoArtist) {
                          setState(() {
                            _noArtistSelected = isNoArtist;
                            if (isNoArtist) _selectedStylist = null;
                            _selectedTime = null;
                          });
                          _fetchTimeSlots();
                        },
                      ),
                      const SizedBox(height: 24),

                      BookingTimeSelection(
                        timeSlots: _timeSlots,
                        isLoading: _isLoadingTimes,
                        selectedTime: _selectedTime,
                        canSelect:
                            (_selectedStylist != null || _noArtistSelected) &&
                            _selectedDate != null,
                        selectedDate: _selectedDate,
                        onTimeChanged: (time) => setState(() {
                          _selectedTime = time;
                          _priceReview = null;
                        }),
                      ),
                    ],
                  ),
                ),
                          // 3. Chọn giờ (chỉ hiện sau khi chọn thợ/mode)
                          AnimatedSwitcher(
                            duration: const Duration(milliseconds: 250),
                            child: state.canSelectTime
                                  ? BookingTimeSelection(
                                    key: const ValueKey('time-visible'),
                                    timeSlots: state.timeSlots,
                                    isLoading: state.isLoadingTimes,
                                    selectedTime: state.selectedTime,
                                    canSelect: true,
                                    selectedDate: state.selectedDate,
                                    salonId: state.selectedBranch?['salonId']?.toString(),
                                    artistId: state.noArtistSelected ? null : state.selectedStylist?['nailArtistId']?.toString(),
                                    onTimeChanged: cubit.selectTime,
                                  )
                                : const SizedBox(key: ValueKey('time-hidden')),
                          ),
                        ],
                      ),
                    ),

                // BƯỚC 4: SUMMARY
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Xác nhận thông tin đặt lịch',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Column(
                          children: [
                            _buildSummaryRow(
                              Icons.storefront,
                              'Chi nhánh',
                              _selectedBranch?['name'] ?? '',
                            ),
                            _buildSummaryRow(
                              Icons.calendar_month,
                              'Ngày hẹn',
                              _selectedDate != null
                                  ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                  : '',
                            ),
                            _buildSummaryRow(
                              Icons.access_time,
                              'Thời gian',
                              _selectedTime != null
                                  ? _selectedTime!.substring(0, 5)
                                  : '',
                            ),
                            _buildSummaryRow(
                              Icons.face,
                              'Thợ thực hiện',
                              _noArtistSelected
                                  ? 'Tự động phân công'
                                  : (_selectedStylist?['fullName'] ?? ''),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      _buildPromotionSelector(),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AppColors.borderLight),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Chi tiết thanh toán',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 12),
                            if (_isReviewingPrice)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                            if (widget.nailData != null)
                              _buildNailVariantPaymentItem(),
                            if (_showLegacyNailDataRow &&
                                widget.nailData != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Biến thể Nail: ${widget.nailData!['name']}',
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                    Text(
                                      PriceFormatter.format(
                                        widget.nailData?['price'],
                                      ),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                            // Fix: Lọc bỏ null trước khi render list summary
                            ..._selectedExtraServices.whereType<String>().map((
                              serviceId,
                            ) {
                              final serviceName = _serviceNameById(serviceId);
                              final servicePrice = _servicePriceById(serviceId);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 12.0,
                                        ), // Cách giá tiền một khoảng nhỏ
                                        child: Text(
                                          'Dịch vụ thêm: $serviceName',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Colors.grey,
                                          ),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      PriceFormatter.format(servicePrice),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }),
                            if (_discountBreakdown.isNotEmpty) ...[
                              const Divider(height: 24),
                              ..._discountBreakdown.map(
                                (discount) => _buildDiscountRow(discount),
                              ),
                            ],
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Tổng thanh toán:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  PriceFormatter.format(
                                    _priceReview?['totalPrice'] ??
                                        _estimatedTotalPrice,
                                  ),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                    // ── BƯỚC 5: SUMMARY ─────────────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildSummaryStep(context, state, cubit),
                    ),
                  ],
                ),
              ),
              _buildFooter(state),
            ],
          );
        },
      ),
    );
  }

  // ── SUMMARY STEP ────────────────────────────────────────────────────────────
  Widget _buildSummaryStep(
      BuildContext context, NailBookingState state, NailBookingCubit cubit) {
    final promos =
        state.selectedPromotions.whereType<PromotionModel>().toList();
    final extraTotal =
        cubit.extraServicesTotal(state.selectedExtraServices);
    final subtotal = _nailVariantPrice + extraTotal;
    final discount = cubit.discountAmount(subtotal: subtotal, promotions: promos);
    final finalPrice = (subtotal - discount).clamp(0, double.maxFinite).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Xác nhận thông tin đặt lịch',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              _buildSummaryRow(Icons.storefront, 'Chi nhánh',
                  state.selectedBranch?['name'] ?? ''),
              // _buildSummaryRow(Icons.chair, 'Ghế',
              //     state.selectedSeatId != null
              //         ? 'Ghế ${state.selectedSeatId!.split('_').last}'
              //         : ''),
              _buildSummaryRow(
                  Icons.calendar_month,
                  'Ngày hẹn',
                  state.selectedDate != null
                      ? '${state.selectedDate!.day}/${state.selectedDate!.month}/${state.selectedDate!.year}'
                      : ''),
              _buildSummaryRow(
                  Icons.access_time,
                  'Thời gian',
                  state.selectedTime != null
                      ? state.selectedTime!.substring(0, 5)
                      : ''),
              _buildSummaryRow(
                  Icons.face,
                  'Thợ thực hiện',
                  state.noArtistSelected
                      ? 'Tự động phân công'
                      : (state.selectedStylist?['fullName'] ?? '')),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildPromotionSelector(context, state, cubit),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Chi tiết thanh toán',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              if (widget.nailData != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Biến thể Nail: ${widget.nailData!['name']}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        PriceFormatter.format(widget.nailData?['price']),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ...state.selectedExtraServices.whereType<String>().map((id) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: Text(
                            'Dịch vụ thêm: ${cubit.serviceNameById(id)}',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                          ),
                        ),
                      ),
                      Text(
                        PriceFormatter.format(cubit.servicePriceById(id)),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tạm tính:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    PriceFormatter.format(subtotal),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              if (discount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Giảm giá:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                      Text(
                        '-${PriceFormatter.format(discount)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 16),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng cộng:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    PriceFormatter.format(finalPrice),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 18),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPromotionSelector(
      BuildContext context, NailBookingState state, NailBookingCubit cubit) {
    final promos =
        state.selectedPromotions.whereType<PromotionModel>().toList();
    final hasPromos = promos.isNotEmpty;
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BookingPromotionSheet(
            selectedPromotions: promos,
            onConfirm: (list) => cubit.selectPromotions(list),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasPromos
              ? AppColors.primary.withOpacity(0.06)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasPromos
                ? AppColors.primary.withOpacity(0.5)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(Icons.local_offer_outlined,
                size: 18,
                color: hasPromos ? AppColors.primary : Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasPromos
                    ? 'Đã chọn ${promos.length} khuyến mãi'
                    : 'Chọn voucher / khuyến mãi',
                style: TextStyle(
                  color: hasPromos ? AppColors.primary : Colors.grey.shade600,
                  fontWeight:
                      hasPromos ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ],
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
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
        ],
      ),
    );
  }

  Widget _buildNailVariantPaymentItem() {
    final variant = _nailVariantDetail;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  widget.nailData!['name'],
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Text(
                PriceFormatter.format(
                  _nailVariantPrice + _shapeMethodPrice.round(),
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if (variant != null) ...[
            const SizedBox(height: 6),
            if (variant.nailSurface != null)
              _buildVariantDetailLine(
                'Bề mặt ${variant.nailSurface!.name}',
                variant.nailSurface!.price,
              ),
            if (variant.nailShape != null)
              _buildVariantDetailLine(
                _shapeMethodName ?? 'Phom móng',
                _shapeMethodPrice,
              ),
            ..._componentPaymentLines(variant).map(
              (line) => _buildVariantDetailLine(
                '${line.quantity}x ${line.name}',
                line.price * line.quantity,
              ),
            ),
          ],
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

  Widget _buildPromotionSelector() {
    final selectedPromotion = _promotions.where(
      (promotion) => promotion.promotionId == _selectedPromotionId,
    );
    final selectedLabel = selectedPromotion.isEmpty
        ? 'No promotion'
        : selectedPromotion.first.name;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Promotion',
                      style: TextStyle(
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
                  tooltip: _isPromotionExpanded
                      ? 'Collapse promotions'
                      : 'Expand promotions',
                ),
            ],
          ),
          if (_isPromotionExpanded) ...[
            const SizedBox(height: 8),
            RadioListTile<int>(
              value: 0,
              groupValue: _selectedPromotionId ?? 0,
              onChanged: (_) => _handlePromotionChanged(null),
              title: const Text('No promotion'),
              dense: true,
              contentPadding: EdgeInsets.zero,
            ),
            if (!_isLoadingPromotions && _promotions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'No available promotions.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
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
              ),
            ),
          ],
        ],
      ),
    );
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
              style: const TextStyle(fontSize: 14, color: Colors.green),
            ),
          ),
          Text(
            amountDisplay?.isNotEmpty == true
                ? amountDisplay!
                : PriceFormatter.format(-(discount['amount'] ?? 0)),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          bool isCompleted = index <= _currentStep;
          return Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: isCompleted
                    ? AppColors.primary
                    : Colors.grey.shade300,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              if (index < 3)
                Container(
                  width: 30,
                  height: 2,
                  color: index < _currentStep
                      ? AppColors.primary
                      : Colors.grey.shade300,
                ),
              CircleAvatar(
                radius: 12,
                backgroundColor:
                    isCompleted ? AppColors.primary : Colors.grey.shade300,
                child: Text('${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
              if (index < 3)
                Container(
                    width: 30,
                    height: 2,
                    color: index < _currentStep
                        ? AppColors.primary
                        : Colors.grey.shade300),
            ],
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
              offset: const Offset(0, -5))
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
                    horizontal: 24, vertical: 15),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Quay lại',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
            )
          else
            const SizedBox.shrink(),
          ElevatedButton(
            onPressed: state.isSubmitting
                ? null
                : () => _handleNextAction(state),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: state.isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    _currentStep == 3 ? 'Xác nhận Đặt lịch' : 'Tiếp tục',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
