import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';

import '../widgets/booking_service_selection.dart';
import '../widgets/booking_date_selection.dart';
import '../widgets/booking_time_selection.dart';

// Import API & Model
import '../../data/datasources/booking_api_service.dart';
import '../../../my_studio/data/models/customer_nail_model.dart';

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

  int _currentStep = 0;
  bool _isSubmitting = false;

  // Data
  List<dynamic> _services = [];
  List<dynamic> _timeSlots = [];

  bool _isLoadingServices = true;
  bool _isLoadingTimes = false;

  // Selections
  List<String?> _selectedExtraServices = [];
  DateTime? _selectedDate;
  String? _selectedTime;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  Future<void> _fetchServices() async {
    try {
      final services = await _apiService.getServices();
      if (mounted) {
        setState(() {
          _services = services;
          _isLoadingServices = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingServices = false);
    }
  }

  Future<void> _fetchTimeSlots() async {
    if (_selectedDate == null) return;
    setState(() {
      _isLoadingTimes = true;
      _timeSlots = [];
      _selectedTime = null;
    });

    try {
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      final artistId =
          widget.nail.nailArtistId ?? '';

      if (artistId.isEmpty) {
        throw Exception('Không tìm thấy thông tin đặt lịch');
      }

      final times = await _apiService.getArtistAvailableSlots(
        artistId,
        dateStr,
      );
      if (mounted) {
        setState(() {
          _timeSlots = times;
          _isLoadingTimes = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTimes = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi: $e')));
      }
    }
  }

  void _handleServiceChanged(List<String?> services) {
    setState(() {
      _selectedExtraServices = services;
      _selectedTime = null;
      _timeSlots = [];
    });
    if (_selectedDate != null) _fetchTimeSlots();
  }

  Map<String, int> get _groupedServicesMap {
    final map = <String, int>{};
    for (var id in _selectedExtraServices.whereType<String>()) {
      map[id] = (map[id] ?? 0) + 1;
    }
    return map;
  }

  String _serviceNameById(String? serviceId) {
    if (serviceId == null) return '';
    final matches = _services.where((s) => s['serviceId'] == serviceId);
    return matches.isNotEmpty ? matches.first['name'] : serviceId;
  }

  int _servicePriceById(String? serviceId) {
    if (serviceId == null) return 0;
    final matches = _services.where((s) => s['serviceId'] == serviceId);
    return matches.isNotEmpty ? (matches.first['price'] as num).toInt() : 0;
  }

  int get _selectedExtraServicesTotal {
    int total = 0;
    _groupedServicesMap.forEach((id, qty) {
      total += _servicePriceById(id) * qty;
    });
    return total;
  }

  int get _shapeMethodPrice => (widget.shapeMethodPrice ?? 0).round();

  int get _estimatedTotalPrice =>
      widget.nail.customerNailPrice +
      widget.nail.price +
      _shapeMethodPrice +
      _selectedExtraServicesTotal;

  bool get _showLegacyCustomerNailPaymentRow => false;

  Future<void> _executeBooking() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final salonId = widget.nail.salonId;
      final artistId = widget.nail.nailArtistId ?? '';
      final nailRequestId = widget.nail.customerNailRequestId;

      if (nailRequestId.isEmpty) {
        throw Exception('Yêu cầu đặt lịch không tồn tại.');
      }

      if (salonId.isEmpty || artistId.isEmpty) {
        throw Exception(
          'Yêu cầu đặt lịch không phù hợp',
        );
      }

      final formattedDate =
          "${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}T00:00:00";
      final formattedTime = _selectedTime!.length == 5
          ? "$_selectedTime:00"
          : _selectedTime!;

      final response = await _apiService.createCustomNailBooking(
        salonId,
        formattedDate,
        formattedTime,
        artistId,
        nailRequestId,
        _groupedServicesMap,
        widget.shapeMethodConfigId,
      );

      if (mounted) {
        final bookingDetails = {
          'bookingId': response['bookingId']?.toString() ?? '',
          'serviceName': 'Custom: ${widget.nail.name}',
          'date': _selectedDate,
          'time': formattedTime,
          'stylistName': widget.nail.stylistName,
        };
        context.go('/booking-success', extra: bookingDetails);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString().replaceAll('Exception: ', 'Lỗi: ')),
          ),
        );
      }
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
    if (_currentStep == 0 && _selectedExtraServices.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Bạn cần phải hoàn thành bước này!')),
      );
      return;
    }
    if (_currentStep == 1 && (_selectedDate == null || _selectedTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vui lòng chọn ngày và thời gian!'),
        ),
      );
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

  @override
  Widget build(BuildContext context) {
    final customNailMappedData = {
      'name': widget.nail.name,
      'price': widget.nail.price,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: _handleBackAction,
        ),
        title: const Text(
          'Đặt lịch Custom Nail',
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
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (idx) => setState(() => _currentStep = idx),
                    children: [
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: BookingServiceSelection(
                          nailData: customNailMappedData,
                          services: _services,
                          selectedExtraServices: _selectedExtraServices,
                          onChanged: _handleServiceChanged,
                        ),
                      ),

                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(16),
                              margin: const EdgeInsets.only(bottom: 24),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.blue.shade200),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.face_retouching_natural,
                                    color: Colors.blue,
                                    size: 28,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Thợ nail:',
                                          style: TextStyle(
                                            color: Colors.blue,
                                            fontSize: 12,
                                          ),
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
                            ),

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
                              canSelect:
                                  _selectedDate !=
                                  null,
                              selectedDate: _selectedDate,
                              onTimeChanged: (time) =>
                                  setState(() => _selectedTime = time),
                            ),
                          ],
                        ),
                      ),

                      // BÆ¯á»šC 2: SUMMARY
                      SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Xác nhận thông tin',
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
                                border: Border.all(
                                  color: AppColors.borderLight,
                                ),
                              ),
                              child: Column(
                                children: [
                                  _buildSummaryRow(
                                    Icons.calendar_month,
                                    'Ngày hẹn',
                                    _selectedDate != null
                                        ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                        : '',
                                  ),
                                  _buildSummaryRow(
                                    Icons.access_time,
                                    'Thời gian',
                                    _selectedTime ?? '',
                                  ),
                                  _buildSummaryRow(
                                    Icons.face,
                                    'Thợ nail',
                                    widget.nail.stylistName,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.borderLight,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Chi tiết thanh toán',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  _buildCustomerNailPaymentItem(),
                                  if (widget.nail.price > 0)
                                    _buildPaymentLine(
                                      'Extra component',
                                      widget.nail.price,
                                    ),
                                  if (_showLegacyCustomerNailPaymentRow)
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8.0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        children: [
                                          Expanded(
                                            child: Text(
                                              widget.nail.name,
                                              style: const TextStyle(
                                                fontSize: 14,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            PriceFormatter.format(
                                              widget.nail.price,
                                            ),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                  ..._groupedServicesMap.entries.map((entry) {
                                    final serviceId = entry.key;
                                    final qty = entry.value;
                                    final price = _servicePriceById(serviceId);
                                    return Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 8.0,
                                      ),
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceBetween,
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Expanded(
                                            child: Padding(
                                              padding: const EdgeInsets.only(
                                                right: 12.0,
                                              ),
                                              child: Text(
                                                '${qty}x ${_serviceNameById(serviceId)}',
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ),
                                          ),
                                          Text(
                                            PriceFormatter.format(price * qty),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  }),

                                  const Divider(height: 24),
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        'Tổng tạm tính:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      Text(
                                        PriceFormatter.format(
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

  Widget _buildCustomerNailPaymentItem() {
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
                  widget.nail.name,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              Text(
                PriceFormatter.format(
                  widget.nail.customerNailPrice + _shapeMethodPrice,
                ),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ..._customerNailDetailPaymentLines(widget.nail),
        ],
      ),
    );
  }

  List<Widget> _customerNailDetailPaymentLines(CustomerNailModel nail) {
    return [
      if (nail.nailSurface != null)
        _buildNestedPaymentLine(
          'Bề mặt ${nail.nailSurface!['name'] ?? nail.nailSurface!['Name'] ?? ''}',
          nail.nailSurface!['price'] ?? 0,
        ),
      if (nail.nailShape != null)
        _buildNestedPaymentLine(
          widget.shapeMethodName ?? 'Phom móng',
          widget.shapeMethodPrice ?? 0
        ),
      ..._customerNailComponentLines(nail).map(
            (line) => _buildNestedPaymentLine(
          '${line.quantity}x ${line.name}',
          line.price * line.quantity,
        ),
      ),
    ];
  }

  Widget _buildPaymentLine(String label, num price) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(label, style: const TextStyle(fontSize: 14)),
            ),
          ),
          Text(
            PriceFormatter.format(price),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  List<_ComponentPaymentLine> _customerNailComponentLines(
    CustomerNailModel nail,
  ) {
    final grouped = <String, _ComponentPaymentLine>{};
    for (final raw in nail.customerNailComponents) {
      if (raw is! Map) continue;
      final component = raw['component'] ?? raw['Component'];
      final customerComponent =
          raw['customerComponent'] ?? raw['CustomerComponent'];
      final source = component is Map
          ? component
          : customerComponent is Map
          ? customerComponent
          : null;
      final name = source?['name']?.toString().trim().isNotEmpty == true
          ? source!['name'].toString().trim()
          : source?['Name']?.toString().trim().isNotEmpty == true
          ? source!['Name'].toString().trim()
          : 'Component';
      final price = _asDouble(source?['price'] ?? source?['Price']);
      final key = '$name|$price';
      final current = grouped[key];
      grouped[key] = current == null
          ? _ComponentPaymentLine(name: name, quantity: 1, price: price)
          : current.copyWith(quantity: current.quantity + 1);
    }
    return grouped.values.toList();
  }

  Widget _buildNestedPaymentLine(String label, num price) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6),
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

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
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
              padding: const EdgeInsets.only(right: 12.0),
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
                  'Quay lại',
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
                    _currentStep == 2 ? 'Xác nhận đặt lịch' : 'Tiếp theo',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ComponentPaymentLine {
  final String name;
  final int quantity;
  final double price;

  const _ComponentPaymentLine({
    required this.name,
    required this.quantity,
    required this.price,
  });

  _ComponentPaymentLine copyWith({int? quantity}) {
    return _ComponentPaymentLine(
      name: name,
      quantity: quantity ?? this.quantity,
      price: price,
    );
  }
}

