import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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

  // Hold slot state
  String? _holdToken;
  DateTime? _holdExpiresAt;
  int _holdRemainingSeconds = 0;
  bool _isHolding = false;
  Timer? _holdTimer;

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
    // Huỷ giữ chỗ khi user thoát khỏi quá trình đặt lịch
    if (_holdToken != null) {
      _apiService.cancelHoldSlot(_holdToken!);
    }
    _holdTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  // ── Getters ──────────────────────────────────────────────────────────────

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

  int get _selectedExtraServicesTotal {
    return _selectedExtraServices.whereType<String>().fold<int>(
      0,
      (total, serviceId) => total + _servicePriceById(serviceId),
    );
  }

  int get _estimatedTotalPrice {
    return widget.nail.customerNailPrice +
        widget.nail.price +
        _shapeMethodPrice +
        _selectedExtraServicesTotal;
  }

  Map<String, int> get _groupedServicesMap {
    final map = <String, int>{};
    for (final id in _selectedExtraServices.whereType<String>()) {
      map[id] = (map[id] ?? 0) + 1;
    }
    return map;
  }

  List<int>? get _selectedPromotionIds {
    if (_selectedPromotions.isEmpty) return null;
    return _selectedPromotions.map((p) => p.promotionId).toList();
  }

  String get _normalizedSelectedTime {
    final time = _selectedTime ?? '';
    return time.length == 5 ? '$time:00' : time;
  }

  // ── API calls ─────────────────────────────────────────────────────────────

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
        _timeSlots = times;
        _isLoadingTimes = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _isLoadingTimes = false);
      _showSnackBar('Loi tai gio ranh: $e');
    }
  }

  // ── Hold Slot Logic ───────────────────────────────────────────────────────

  Future<void> _holdSlot(String time) async {
    final artistId = widget.nail.nailArtistId ?? '';
    final salonId = widget.nail.salonId;
    if (artistId.isEmpty || salonId.isEmpty || _selectedDate == null) return;

    final bookingDate = _formatBookingDate(_selectedDate!);
    final formattedTime = time.length == 5 ? '$time:00' : time;

    final bookingItems = <Map<String, dynamic>>[
      {'customerNailId': widget.nail.customerNailId, 'quantity': 1},
      ..._groupedServicesMap.entries
          .map((e) => {'serviceId': e.key, 'quantity': e.value}),
    ];

    try {
      final data = await _apiService.holdSlot(
        salonId: salonId,
        nailArtistId: artistId,
        bookingDate: bookingDate,
        startTime: formattedTime,
        bookingItems: bookingItems,
      );

      if (!mounted) return;

      final token = data['holdToken']?.toString();
      final expiresAtStr = data['expiresAt']?.toString();
      if (token == null || token.isEmpty) return;

      DateTime? expiresAt;
      if (expiresAtStr != null) {
        try {
          expiresAt = DateTime.parse(expiresAtStr).toUtc();
        } catch (_) {}
      }
      final remaining = (data['remainingSeconds'] as num?)?.toInt() ?? 300;

      setState(() {
        _holdToken = token;
        _holdExpiresAt = expiresAt;
        _holdRemainingSeconds = remaining;
        _isHolding = true;
      });
      _startHoldTimer(token, expiresAt);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content:
                Text('Khung giờ này vừa mới có người chọn. Vui lòng chọn giờ khác.'),
            backgroundColor: Colors.red,
          ),
        );
        setState(() {
          _holdToken = null;
          _isHolding = false;
          _holdRemainingSeconds = 0;
          _selectedTime = null;
        });
        _fetchTimeSlots();
      }
    }
  }

  void _startHoldTimer(String token, DateTime? expiresAt) {
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) {
        _holdTimer?.cancel();
        return;
      }

      final remaining = (_holdRemainingSeconds - 1).clamp(0, 600);

      if (_holdToken != token) {
        _holdTimer?.cancel();
        return;
      }

      if (remaining <= 0) {
        _holdTimer?.cancel();
        setState(() {
          _holdToken = null;
          _holdExpiresAt = null;
          _holdRemainingSeconds = 0;
          _isHolding = false;
          _selectedTime = null;
        });
        if (_currentStep == 2) {
          _pageController.animateToPage(
            1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Thời gian giữ chỗ đã hết! Vui lòng chọn lại khung giờ.'),
          ),
        );
      } else {
        setState(() => _holdRemainingSeconds = remaining);
      }
    });
  }

  void _cancelCurrentHold() {
    if (_holdToken != null) {
      _apiService.cancelHoldSlot(_holdToken!); // fire-and-forget
    }
    _holdTimer?.cancel();
    _holdTimer = null;
    setState(() {
      _holdToken = null;
      _holdExpiresAt = null;
      _holdRemainingSeconds = 0;
      _isHolding = false;
    });
  }

  // ── Booking ───────────────────────────────────────────────────────────────

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
      if (salonId.isEmpty) {
        throw Exception('Thieu thong tin chi nhanh.');
      }
      
      final isNoArtist = artistId.isEmpty;

      final response = await _apiService.createCustomNailBooking(
        salonId,
        _formatBookingDate(_selectedDate!),
        _normalizedSelectedTime,
        isNoArtist ? null : artistId,
        customerNailRequestId,
        _groupedServicesMap,
        shapeMethodConfigId: _selectedShapeMethodConfigId,
        selectedPromotionIds: _selectedPromotionIds,
        holdToken: isNoArtist ? null : _holdToken,
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

  // ── Helpers ───────────────────────────────────────────────────────────────

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
    // Huỷ giữ chỗ cũ khi đổi dịch vụ
    if (_holdToken != null) _cancelCurrentHold();
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

  Future<void> _handleNextAction() async {
    if (_currentStep == 0 && _selectedExtraServices.contains(null)) {
      _showSnackBar('Vui long chon hoac xoa dich vu dang bo trong.');
      return;
    }
    if (_currentStep == 1) {
      if (_selectedDate == null || _selectedTime == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Vui lòng chọn đầy đủ ngày và khung giờ!'),
          ),
        );
        return;
      }
      // Chỉ tạo hold mới nếu chưa có token (tránh reset timer khi back/forward)
      final bool isNoArtist = widget.nail.nailArtistId == null || widget.nail.nailArtistId!.isEmpty;
      if (!isNoArtist) {
        if (_holdToken == null || !_isHolding) {
          await _holdSlot(_selectedTime!);
          if (!mounted) return;
          if (_holdToken == null) return;
        }
      }
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

  void _showSnackBar(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════

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
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: _handleBackAction,
        ),
        title: const Text(
          'Dat lich custom nail',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
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

  // ══════════════════════════════════════════════════════════════
  // STEP WIDGETS
  // ══════════════════════════════════════════════════════════════

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
            onTimeChanged: (time) {
              // Chỉ lưu giờ đã chọn, KHÔNG gọi holdSlot.
              // holdSlot sẽ được gọi khi user bấm "Tiếp theo" sang bước Xác nhận.
              if (_holdToken != null) _cancelCurrentHold();
              setState(() {
                _selectedTime = time;
                _holdToken = null;
                _isHolding = false;
                _holdRemainingSeconds = 0;
              });
            },
            onRefreshSlots: _fetchTimeSlots,
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
            'Xac nhan thong tin',
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

  // ══════════════════════════════════════════════════════════════
  // COMPONENT WIDGETS
  // ══════════════════════════════════════════════════════════════

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
              'Phuong phap tao form',
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
                    color:
                        selected ? AppColors.primary : AppColors.borderLight,
                  ),
                ),
                child: RadioListTile<int>(
                  value: method.shapeMethodConfigId,
                  groupValue: _selectedShapeMethodConfigId ?? -1,
                  onChanged: (val) {
                    setState(() => _selectedShapeMethod = method);
                  },
                  title: Text(method.name),
                  subtitle: Text('${method.duration} phut'),
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

  Widget _buildAssignedArtistCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.face_retouching_natural, color: Colors.blue),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tho da duyet',
                  style: TextStyle(color: Colors.blue, fontSize: 12),
                ),
                Text(
                  widget.nail.stylistName,
                  style: const TextStyle(
                    color: Colors.blue,
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
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            Icons.calendar_month,
            'Ngay hen',
            _selectedDate == null
                ? ''
                : '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}',
          ),
          _buildSummaryRow(
            Icons.access_time,
            'Thoi gian',
            _selectedTime == null ? '' : _selectedTime!.substring(0, 5),
          ),
          _buildSummaryRow(
            Icons.face,
            'Tho thuc hien',
            widget.nail.stylistName,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentDetails() {
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
          const Text(
            'Chi tiet thanh toan',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          const SizedBox(height: 12),
          _buildCustomerNailPaymentItem(),
          if (widget.nail.price > 0)
            _buildPaymentLine('Phi xu ly custom', widget.nail.price),
          if (_shapeMethodPrice > 0)
            _buildPaymentLine(_shapeMethodName, _shapeMethodPrice),
          ..._groupedServicesMap.entries.map((entry) {
            return _buildPaymentLine(
              '${entry.value}x ${_serviceNameById(entry.key)}',
              _servicePriceById(entry.key) * entry.value,
              muted: true,
            );
          }),
          const Divider(height: 24),
          _buildPaymentLine(
            'Tong tam tinh',
            _estimatedTotalPrice,
            strong: true,
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerNailPaymentItem() {
    return Column(
      children: [
        _buildPaymentLine(
          'Thiet ke mong: ${widget.nail.name}',
          widget.nail.customerNailPrice,
        ),
        if (widget.nail.shapeName.isNotEmpty)
          _buildPaymentLine(
            'Dang mong: ${widget.nail.shapeName}',
            0,
            muted: true,
          ),
        if (widget.nail.surfaceName.isNotEmpty)
          _buildPaymentLine(
            'Be mat: ${widget.nail.surfaceName}',
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
    return name == null || name.isEmpty ? 'Thanh phan custom' : name;
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
        ? 'Khong ap dung khuyen mai'
        : 'Da chon ${_selectedPromotions.length} khuyen mai';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
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
                  'Khong co khuyen mai kha dung.',
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          final isCompleted = index <= _currentStep;
          return Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor:
                    isCompleted ? AppColors.primary : Colors.grey.shade300,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              if (index < 2)
                Container(
                  width: 40,
                  height: 2,
                  color: index < _currentStep
                      ? AppColors.primary
                      : Colors.grey.shade300,
                ),
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
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_currentStep > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : _handleBackAction,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 15,
                  ),
                  side: const BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Quay lai',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _handleNextAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: _isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _currentStep == 2 ? 'Xac nhan dat lich' : 'Tiep tuc',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoldCountdownBanner() {
    if (!_isHolding) return const SizedBox.shrink();
    final secs = _holdRemainingSeconds;
    final min = (secs ~/ 60).toString().padLeft(2, '0');
    final sec = (secs % 60).toString().padLeft(2, '0');
    final isUrgent = secs <= 60;
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
                  ? 'Chỗ có thể bị hủy sau $min:$sec giây!'
                  : 'Slot đang được giữ chỗ cho bạn – còn $min:$sec để hoàn tất',
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
}
