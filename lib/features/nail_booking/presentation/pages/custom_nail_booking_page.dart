import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../generated/l10n.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../my_studio/data/models/customer_nail_model.dart';
import '../../../nails/data/models/shape_method_config_model.dart';
import '../../../nails/data/repositories/nail_variant_repository.dart';
import '../../data/datasources/booking_api_service.dart';
import '../../data/datasources/promotion_api_service.dart';
import '../../data/models/promotion_model.dart';
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
  final PromotionApiService _promotionApiService = PromotionApiService();

  int _currentStep = 0;
  bool _isSubmitting = false;
  bool _isLoadingServices = true;
  bool _isLoadingTimes = false;
  bool _isLoadingPromotions = false;
  bool _isPromotionExpanded = false;

  Future<List<ShapeMethodConfigModel>>? _shapeMethodsFuture;
  ShapeMethodConfigModel? _selectedShapeMethod;
  List<dynamic> _services = [];
  List<dynamic> _timeSlots = [];
  List<PromotionModel> _promotions = [];
  List<PromotionModel> _selectedPromotions = [];
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

  Future<List<ShapeMethodConfigModel>> _loadShapeMethods() async {
    final shapeId = widget.nail.nailShapeId;
    if (shapeId == null || shapeId <= 0) return const [];
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
      final promotions = await _promotionApiService.getVouchers();
      if (!mounted) return;
      setState(() {
        _promotions = promotions
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
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final salonId = widget.nail.salonId;
      final artistId = widget.nail.nailArtistId ?? '';
      final customerNailRequestId = widget.nail.customerNailRequestId;

      if (customerNailRequestId.isEmpty) {
        throw Exception('ID yeu cau mong custom khong hop le.');
      }
      if (salonId.isEmpty || artistId.isEmpty) {
        throw Exception('Thieu thong tin chi nhanh hoac tho.');
      }

      final response = await _apiService.createCustomNailBooking(
        salonId,
        _formatBookingDate(_selectedDate!),
        _normalizedSelectedTime,
        artistId,
        customerNailRequestId,
        _groupedServicesMap,
        shapeMethodConfigId: _selectedShapeMethodConfigId,
        selectedPromotionIds: _selectedPromotionIds,
      );

      if (!mounted) return;
      context.go(
        '/booking-success',
        extra: {
          'bookingId': response['bookingId']?.toString() ?? '',
          'serviceName': 'Custom: ${widget.nail.name}',
          'date': _selectedDate,
          'time': _normalizedSelectedTime,
          'price': response['price'],
          'discount': response['discount'],
          'totalPrice': response['totalPrice'],
          'discounts': response['discounts'] ?? response['discountBreakdown'],
          'stylistName': widget.nail.stylistName,
        },
      );
    } catch (e) {
      if (mounted) {
        _showSnackBar(e.toString().replaceAll('Exception: ', 'Loi: '));
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
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
    setState(() {
      _selectedExtraServices = services;
      _selectedTime = null;
      _timeSlots = [];
    });
    if (_selectedDate != null) _fetchTimeSlots();
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
    if (_currentStep == 0 && _selectedExtraServices.contains(null)) {
      _showSnackBar('Vui long chon hoac xoa dich vu dang bo trong.');
      return;
    }
    if (_currentStep == 1 && (_selectedDate == null || _selectedTime == null)) {
      _showSnackBar('Vui long chon ngay va khung gio.');
      return;
    }

    if (_currentStep < 2) {
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
      'price': widget.nail.customerNailPrice + widget.nail.price,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20, color: AppColors.primaryDark),
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
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (idx) => setState(() => _currentStep = idx),
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
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withOpacity(0.06)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected ? AppColors.primary : AppColors.borderLight,
                  ),
                ),
                child: RadioListTile<int>(
                  value: method.shapeMethodConfigId,
                  groupValue: _selectedShapeMethodConfigId,
                  onChanged: (_) {
                    setState(() => _selectedShapeMethod = method);
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
            onTimeChanged: (time) => setState(() => _selectedTime = time),
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
                  style: TextStyle(color: Color(0xFFC44569), fontSize: 12, fontWeight: FontWeight.bold),
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
    final double customPrice = (widget.nail.customerNailPrice + widget.nail.price).toDouble();
    final double shapePrice = _shapeMethodPrice.toDouble();
    final double servicesTotal = _groupedServicesMap.entries.fold<double>(
      0.0,
      (sum, entry) => sum + (_servicePriceById(entry.key) * entry.value),
    );
    final double subtotal = customPrice + shapePrice + servicesTotal;

    double discount = 0.0;
    for (final promo in _selectedPromotions) {
      if (promo.discountType == 'Percentage') {
        discount += subtotal * (promo.discountValue / 100);
      } else {
        discount += promo.discountValue;
      }
    }
    final double finalPrice = (subtotal - discount).clamp(0, double.maxFinite);

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
          const Text(
            'Chi tiết thanh toán',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          _buildCustomerNailPaymentItem(),
          if (widget.nail.price > 0)
            _buildPaymentLine('Phí xử lý custom', widget.nail.price),
          if (_shapeMethodPrice > 0)
            _buildPaymentLine(_shapeMethodName, _shapeMethodPrice),
          ..._groupedServicesMap.entries.map((entry) {
            return _buildPaymentLine(
              '${entry.value}x ${_serviceNameById(entry.key)}',
              _servicePriceById(entry.key) * entry.value,
              muted: true,
            );
          }),
          const Divider(height: 16),
          _buildPaymentLine('Tạm tính', subtotal, muted: true),
          if (discount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Khuyến mại giảm giá',
                    style: TextStyle(fontSize: 14, color: Colors.green),
                  ),
                  Text(
                    '-${PriceFormatter.format(discount)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green),
                  ),
                ],
              ),
            ),
          const Divider(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng cộng',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              Text(
                PriceFormatter.format(finalPrice),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerNailPaymentItem() {
    return Column(
      children: [
        _buildPaymentLine(
          'Thiết kế móng: ${widget.nail.name}',
          widget.nail.customerNailPrice,
        ),
        if (widget.nail.shapeName.isNotEmpty)
          _buildPaymentLine(
            'Dáng móng: ${widget.nail.shapeName}',
            0,
            muted: true,
          ),
        if (widget.nail.surfaceName.isNotEmpty)
          _buildPaymentLine(
            'Bề mặt: ${widget.nail.surfaceName}',
            0,
            muted: true,
          ),
        ...widget.nail.customerNailComponents
            .whereType<Map>()
            .map((component) => Map<String, dynamic>.from(component))
            .map(
              (component) => _buildPaymentLine(
                _customerComponentName(component),
                _customerComponentPrice(component),
                muted: true,
              ),
            ),
      ],
    );
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

  Widget _buildPromotionSelector() {
    final label = _selectedPromotions.isEmpty
        ? 'Không áp dụng khuyến mại'
        : 'Đã chọn ${_selectedPromotions.length} khuyến mại';

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
                  'Không có khuyến mại khả dụng.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ..._promotions.map((promotion) {
              final selected = _selectedPromotions.any(
                (item) => item.promotionId == promotion.promotionId,
              );
              return CheckboxListTile(
                value: selected,
                onChanged: (checked) {
                  setState(() {
                    if (checked == true) {
                      _selectedPromotions = [..._selectedPromotions, promotion];
                    } else {
                      _selectedPromotions = _selectedPromotions
                          .where(
                            (item) => item.promotionId != promotion.promotionId,
                          )
                          .toList();
                    }
                  });
                },
                title: Text(promotion.name),
                subtitle: Text(
                  promotion.description.isNotEmpty
                      ? '${promotion.discountLabel} - ${promotion.description}'
                      : promotion.discountLabel,
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
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
                      () {
                        final rawTitle = step['title'] as String;
                        if (rawTitle == 'Chọn tiệm') return S.of(context).selectSalon;
                        if (rawTitle == 'Dịch vụ') return S.of(context).servicesLabel;
                        if (rawTitle == 'Đặt lịch') return S.of(context).bookAppointment;
                        if (rawTitle == 'Hoàn tất') return S.of(context).completedLabel;
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
                          _currentStep == 2 ? 'Xác nhận đặt lịch' : 'Tiếp tục',
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
