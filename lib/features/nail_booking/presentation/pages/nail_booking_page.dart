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

  Map<String, dynamic>? _selectedBranch;
  List<String?> _selectedExtraServices = [];
  DateTime? _selectedDate;
  Map<String, dynamic>? _selectedStylist;
  String? _selectedTime;
  int? _selectedPromotionId;
  bool _noArtistSelected = false;

  @override
  void initState() {
    super.initState();
    _fetchSalons();
    _fetchServices();
    _fetchPromotions();
  }

  int get _nailVariantId {
    return int.tryParse(widget.nailData?['id']?.toString() ?? '0') ?? 0;
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
      setState(() { _salons = data; _isLoadingSalons = false; });
    } catch (e) {
      setState(() => _isLoadingSalons = false);
      _showSnackBar('Lỗi tải danh sách Salon: $e');
    }
  }

  Future<void> _fetchArtists() async {
    if (_selectedBranch == null || _selectedDate == null) return;
    setState(() { _isLoadingArtists = true; _artists = []; _selectedStylist = null; _selectedTime = null; });
    try {
      final dateStr = _formatBookingDate(_selectedDate!);
      final data = await _apiService.getSuggestedArtists(
        _selectedBranch!['salonId'],
        dateStr,
        _nailVariantId,
        _selectedExtraServices.whereType<String>().toList(),
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
  }

  Future<void> _fetchTimeSlots() async {
    if (_noArtistSelected) {
      _loadSalonSlots();
      return;
    }
    if (_selectedStylist == null || _selectedDate == null) return;
    setState(() { _isLoadingTimes = true; _timeSlots = []; _selectedTime = null; });
    try {
      final dateStr = _formatBookingDate(_selectedDate!);
      final data = await _apiService.getArtistAvailableSlots(_selectedStylist!['nailArtistId'], dateStr);
      setState(() { _timeSlots = data; _isLoadingTimes = false; });
    } catch (e) {
      setState(() => _isLoadingTimes = false);
      _showSnackBar('Lỗi tải khung giờ: $e');
    }
  }

  void _loadSalonSlots() {
    if (_selectedBranch == null || _selectedDate == null) return;
    setState(() {
      _timeSlots = _apiService.getSalonOperatingSlots(_selectedBranch!, _selectedDate!);
      _selectedTime = null;
    });
  }

  Future<void> _executeBooking() async {
    AuthGuard.check(context, () async {
      if (_isSubmitting) return;
      setState(() => _isSubmitting = true);
      try {
        final formattedTime = _selectedTime!.length == 5 ? "$_selectedTime:00" : _selectedTime!;
        final artistId = _noArtistSelected ? null : _selectedStylist?['nailArtistId'] as String?;

        final booking = await _apiService.createBooking(
          _selectedBranch!['salonId'],
          _formatBookingDate(_selectedDate!),
          formattedTime,
          artistId,
          _nailVariantId,
          _selectedExtraServices.whereType<String>().toList(),
          selectedPromotionIds: _selectedPromotionIds,
        );

        if (!mounted) return;

        final bookingDetails = {
          'bookingId': booking['bookingId']?.toString() ?? '',
          'serviceName': widget.nailData?['name'] ?? 'Làm móng',
          'date': _selectedDate,
          'time': formattedTime,
          'stylistName': _noArtistSelected ? 'Tự động phân công' : (_selectedStylist?['fullName'] ?? 'Bất kỳ'),
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
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
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
        _promotions = data.where((promotion) => promotion.isSelectable).toList();
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

  int get _selectedExtraServicesTotal {
    return _selectedExtraServices.whereType<String>().fold<int>(
      0,
          (total, serviceId) =>
      total + _servicePriceById(serviceId),
    );
  }

  List<Map<String, dynamic>> get _availableServices {
    final source = _services.isEmpty ? BookingMockData.extraServices : _services;
    return source
        .whereType<Map>()
        .map((service) => Map<String, dynamic>.from(service))
        .toList();
  }

  String _serviceId(Map<String, dynamic> service) =>
      service['serviceId']?.toString() ?? service['id']?.toString() ?? '';

  String _serviceName(Map<String, dynamic> service) =>
      service['serviceName']?.toString() ?? service['name']?.toString() ?? '';

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

  int get _estimatedTotalPrice => _nailVariantPrice + _selectedExtraServicesTotal;

  List<Map<String, dynamic>> get _discountBreakdown {
    final raw = _priceReview?['discountBreakdown'] ?? _priceReview?['discounts'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((discount) => Map<String, dynamic>.from(discount))
        .toList();
  }

  Future<void> _reviewPrice() async {
    if (_selectedBranch == null || _selectedDate == null || _selectedTime == null) return;
    setState(() => _isReviewingPrice = true);
    try {
      final formattedTime = _selectedTime!.length == 5 ? "$_selectedTime:00" : _selectedTime!;
      final artistId = _noArtistSelected ? null : _selectedStylist?['nailArtistId'] as String?;
      final review = await _apiService.reviewBookingPrice(
        salonId: _selectedBranch!['salonId'],
        bookingDate: _formatBookingDate(_selectedDate!),
        startTime: formattedTime,
        artistId: artistId,
        nailVariantId: _nailVariantId,
        serviceIds: _selectedExtraServices.whereType<String>().toList(),
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

  void _handleNextAction() {
    if (_currentStep == 0 && _selectedBranch == null) {
      _showSnackBar('Vui lòng chọn một chi nhánh salon!'); return;
    }
    if (_currentStep == 1) {
      if (_selectedExtraServices.contains(null)) {
        _showSnackBar('Có ô dịch vụ đang bị bỏ trống. Vui lòng chọn hoặc xóa nó đi!'); return;
      }
      final validServices = _selectedExtraServices.whereType<String>().toList();
      if (widget.nailData == null && validServices.isEmpty) {
        _showSnackBar('Vui lòng chọn ít nhất 1 dịch vụ để tiếp tục!'); return;
      }
    }
    if (_currentStep == 2 && (_selectedDate == null || (_selectedStylist == null && !_noArtistSelected) || _selectedTime == null)) {
      _showSnackBar('Vui lòng chọn đầy đủ ngày, thợ (hoặc để tự động) và khung giờ!'); return;
    }

    if (_currentStep < 3) {
      if (_currentStep == 2) {
        _reviewPrice();
      }
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _executeBooking();
    }
  }

  void _showSnackBar(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.primaryDark),
          onPressed: _handleBackAction,
        ),
        title: const Text(
          'Đặt Lịch Hẹn',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
            color: AppColors.primaryDark,
          ),
        ),
        backgroundColor: const Color(0xFFFDFBF7),
        elevation: 0,
        scrolledUnderElevation: 0,
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
                // STEP 1: CHOOSE BRANCH
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  physics: const BouncingScrollPhysics(),
                  child: BranchSelectionList(
                    salons: _salons,
                    isLoading: _isLoadingSalons,
                    selectedBranchId: _selectedBranch?['salonId'],
                    onBranchSelected: (branch) => setState(() => _selectedBranch = branch),
                    onBranchConfirmedOnMap: (branch) {
                      setState(() {
                        _selectedBranch = branch;
                      });
                      _handleNextAction(); // Auto navigate to next step!
                    },
                  ),
                ),

                // STEP 2: CHOOSE SERVICES
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  physics: const BouncingScrollPhysics(),
                  child: BookingServiceSelection(
                    nailData: widget.nailData,
                    services: _services,
                    selectedExtraServices: _selectedExtraServices,
                    onChanged: _handleServiceChanged,
                  ),
                ),

                // STEP 3: DATE & TIME & STYLIST
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  physics: const BouncingScrollPhysics(),
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
                        canSelect: (_selectedStylist != null || _noArtistSelected) && _selectedDate != null,
                        selectedDate: _selectedDate,
                        onTimeChanged: (time) => setState(() {
                          _selectedTime = time;
                          _priceReview = null;
                        }),
                      ),
                    ],
                  ),
                ),

                // STEP 4: SUMMARY
                SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Xác nhận thông tin đặt lịch',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, fontFamily: 'Georgia', color: AppColors.primaryDark),
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF3EFEA), width: 1.2),
                        ),
                        child: Column(
                          children: [
                            _buildSummaryRow(Icons.storefront_rounded, 'Chi nhánh', _selectedBranch?['name'] ?? ''),
                            _buildSummaryRow(Icons.calendar_month_rounded, 'Ngày hẹn', _selectedDate != null ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}' : ''),
                            _buildSummaryRow(Icons.access_time_rounded, 'Thời gian', _selectedTime != null ? _selectedTime!.substring(0, 5) : ''),
                            _buildSummaryRow(Icons.face_2_rounded, 'Thợ thực hiện',
                              _noArtistSelected ? 'Hệ thống tự phân công' : (_selectedStylist?['fullName'] ?? '')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildPromotionSelector(),
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: const Color(0xFFF3EFEA), width: 1.2),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Chi tiết thanh toán',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark),
                            ),
                            const SizedBox(height: 12),
                            if (_isReviewingPrice)
                              const Padding(
                                padding: EdgeInsets.only(bottom: 12),
                                child: LinearProgressIndicator(minHeight: 2, color: AppColors.primary, backgroundColor: Color(0xFFFFF0F5)),
                              ),
                            if (widget.nailData != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        'Thiết kế Nail: ${widget.nailData!['name']}',
                                        style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                                      ),
                                    ),
                                    Text(
                                      PriceFormatter.format(widget.nailData?['price']),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    ),
                                  ],
                                ),
                              ),
                            ..._selectedExtraServices.whereType<String>().map((serviceId) {
                              final serviceName = _serviceNameById(serviceId);
                              final servicePrice = _servicePriceById(serviceId);
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
                                          'Dịch vụ thêm: $serviceName',
                                          style: TextStyle(fontSize: 13, color: Colors.grey.shade600, fontWeight: FontWeight.w500),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      PriceFormatter.format(servicePrice),
                                      style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                                    )
                                  ],
                                ),
                              );
                            }),
                            if (_discountBreakdown.isNotEmpty) ...[
                              const Divider(height: 24, color: Color(0xFFF3EFEA)),
                              ..._discountBreakdown.map((discount) => _buildDiscountRow(discount)),
                            ],
                            const Divider(height: 24, color: Color(0xFFF3EFEA)),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Tổng thanh toán:',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark),
                                ),
                                Text(
                                  PriceFormatter.format(_priceReview?['totalPrice'] ?? _estimatedTotalPrice),
                                  style: const TextStyle(fontWeight: FontWeight.w900, color: AppColors.primary, fontSize: 20),
                                ),
                              ],
                            )
                          ],
                        ),
                      )
                    ],
                  ),
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
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Color(0xFFFFF0F5),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: AppColors.primary),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.bold)),
              const SizedBox(height: 2),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary, fontSize: 14)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildPromotionSelector() {
    final selectedPromotion = _promotions.where(
      (promotion) => promotion.promotionId == _selectedPromotionId,
    );
    final selectedLabel = selectedPromotion.isEmpty
        ? 'Chọn mã giảm giá...'
        : selectedPromotion.first.name;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3EFEA), width: 1.2),
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
                      'Khuyến mãi & Quà tặng',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primaryDark),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      selectedLabel,
                      style: TextStyle(color: selectedPromotion.isEmpty ? Colors.grey.shade500 : AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary),
                )
              else
                IconButton(
                  onPressed: () => setState(
                    () => _isPromotionExpanded = !_isPromotionExpanded,
                  ),
                  icon: Icon(
                    _isPromotionExpanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.primary,
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
              title: const Text('Không sử dụng khuyến mãi', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
              dense: true,
              activeColor: AppColors.primary,
              contentPadding: EdgeInsets.zero,
            ),
            if (!_isLoadingPromotions && _promotions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Không có chương trình khuyến mãi nào khả dụng.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ..._promotions.map(
              (promotion) => RadioListTile<int>(
                value: promotion.promotionId,
                groupValue: _selectedPromotionId ?? 0,
                onChanged: _handlePromotionChanged,
                activeColor: AppColors.primary,
                title: Text(
                  promotion.name,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                ),
                subtitle: Text(
                  promotion.description.isNotEmpty
                      ? '${promotion.discountLabel} - ${promotion.description}'
                      : promotion.discountLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
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
              style: const TextStyle(fontSize: 14, color: Colors.green, fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            amountDisplay?.isNotEmpty == true
                ? amountDisplay!
                : PriceFormatter.format(-(discount['amount'] ?? 0)),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    final steps = ['Chi nhánh', 'Dịch vụ', 'Thời gian', 'Xác nhận'];
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 16),
      decoration: const BoxDecoration(
        color: Color(0xFFFDFBF7),
        border: Border(bottom: BorderSide(color: Color(0xFFF3EFEA), width: 1)),
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isCurrent = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                // Number Circle or Checkmark
                Container(
                  width: 26,
                  height: 26,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCompleted
                        ? AppColors.primary
                        : (isCurrent ? const Color(0xFFFFF0F5) : Colors.white),
                    border: Border.all(
                      color: (isCompleted || isCurrent)
                          ? AppColors.primary
                          : Colors.grey.shade300,
                      width: isCurrent ? 2 : 1.2,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: isCompleted
                      ? const Icon(Icons.check_rounded, color: Colors.white, size: 14)
                      : Text(
                          '${index + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            color: isCurrent
                                ? AppColors.primary
                                : Colors.grey.shade500,
                          ),
                        ),
                ),
                const SizedBox(width: 8),
                
                // Step Title
                Expanded(
                  child: Text(
                    steps[index],
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: (isCurrent || isCompleted)
                          ? FontWeight.bold
                          : FontWeight.w600,
                      color: isCurrent
                          ? AppColors.primary
                          : (isCompleted ? AppColors.textPrimary : Colors.grey.shade400),
                    ),
                  ),
                ),
                
                // Connecting chevron
                if (index < steps.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: isCompleted ? AppColors.primary : Colors.grey.shade300,
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
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            Expanded(
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : _handleBackAction,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  side: const BorderSide(color: AppColors.primary, width: 1.2),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Quay lại', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
              ),
            )
          else
            const SizedBox.shrink(),
          if (_currentStep > 0) const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: ElevatedButton(
              onPressed: _isSubmitting ? null : _handleNextAction,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                elevation: 0,
              ),
              child: _isSubmitting
                  ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      _currentStep == 3 ? 'Xác nhận Đặt lịch' : 'Tiếp tục',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
