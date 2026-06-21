import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';

// Import widgets (KHÔNG Import StylistSelection nữa)
import '../../../nail_booking/data/models/booking_mock_data.dart';
import '../../../nail_booking/presentation/widgets/booking_service_selection.dart';
import '../../../nail_booking/presentation/widgets/booking_date_selection.dart';
import '../../../nail_booking/presentation/widgets/booking_time_selection.dart';

// Import Model
import '../../../my_studio/data/studio_mock_data.dart';

class CustomNailBookingPage extends StatefulWidget {
  final StudioNailModel nail;

  const CustomNailBookingPage({super.key, required this.nail});

  @override
  State<CustomNailBookingPage> createState() => _CustomNailBookingPageState();
}

class _CustomNailBookingPageState extends State<CustomNailBookingPage> {
  final PageController _pageController = PageController();

  int _currentStep = 0;
  bool _isSubmitting = false;

  // Mock Lists
  final List<dynamic> _services = BookingMockData.extraServices;
  List<dynamic> _timeSlots = [];
  bool _isLoadingTimes = false;

  // User State
  List<String?> _selectedExtraServices = [];
  DateTime? _selectedDate;
  String? _selectedTime;

  @override
  void initState() {
    super.initState();
    // Khởi tạo không cần chọn thợ, thợ đã được foward sẵn từ model
  }

  // ==========================================
  // MOCK LOGIC TẠO DỮ LIỆU ĐỂ PREVIEW
  // ==========================================
  void _fetchTimeSlots() {
    // Chỉ cần chọn ngày là load giờ rảnh (của thợ được gán sẵn)
    if (_selectedDate == null) return;
    setState(() { _isLoadingTimes = true; _timeSlots = []; _selectedTime = null; });

    Future.delayed(const Duration(milliseconds: 500), () {
      if (!mounted) return;
      setState(() {
        _timeSlots = BookingMockData.timeSlots.map((time) => {
          'startTime': '$time:00',
          'isAvailable': true,
        }).toList();
        _isLoadingTimes = false;
      });
    });
  }

  void _executeBooking() {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;

      final bookingDetails = {
        'bookingId': 'mock_booking_123',
        'serviceName': 'Custom: ${widget.nail.name}',
        'date': _selectedDate,
        'time': '$_selectedTime:00',
        'stylistName': widget.nail.stylistName ?? 'Thợ được chỉ định',
      };
      context.go('/booking-success', extra: bookingDetails);
    });
  }

  // ==========================================
  // XỬ LÝ LOGIC GIÁ & DỊCH VỤ
  // ==========================================
  void _handleServiceChanged(List<String?> services) {
    setState(() {
      _selectedExtraServices = services;
      _selectedTime = null;
      _timeSlots = [];
    });
    if (_selectedDate != null) _fetchTimeSlots();
  }

  String _serviceNameById(String? serviceId) {
    if (serviceId == null) return '';
    final matches = _services.where((s) => s['id'] == serviceId);
    return matches.isNotEmpty ? matches.first['name'] : serviceId;
  }

  int _servicePriceById(String? serviceId) {
    if (serviceId == null) return 0;
    final matches = _services.where((s) => s['id'] == serviceId);
    return matches.isNotEmpty ? (matches.first['price'] as int) : 0;
  }

  int get _selectedExtraServicesTotal {
    return _selectedExtraServices.whereType<String>().fold<int>(
      0, (total, serviceId) => total + _servicePriceById(serviceId),
    );
  }

  // ==========================================
  // ĐIỀU HƯỚNG BƯỚC
  // ==========================================
  void _handleBackAction() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      context.pop();
    }
  }

  void _handleNextAction() {
    if (_currentStep == 0 && _selectedExtraServices.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Có ô dịch vụ đang bị bỏ trống!')));
      return;
    }
    if (_currentStep == 1 && (_selectedDate == null || _selectedTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn đầy đủ ngày và khung giờ!')));
      return;
    }

    if (_currentStep < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _executeBooking();
    }
  }

  @override
  Widget build(BuildContext context) {
    final customNailMappedData = {
      'name': widget.nail.name,
      'price': widget.nail.price ?? 0,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: _handleBackAction),
        title: const Text('Đặt Lịch Custom Nail', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
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
                // BƯỚC 1: CHỌN DỊCH VỤ THÊM
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: BookingServiceSelection(
                    nailData: customNailMappedData,
                    services: _services,
                    selectedExtraServices: _selectedExtraServices,
                    onChanged: _handleServiceChanged,
                  ),
                ),

                // BƯỚC 2: CHỌN NGÀY -> GIỜ
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Banner Thông tin Salon & Thợ (Bất biến)
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.storefront, color: Colors.blue, size: 20),
                                const SizedBox(width: 12),
                                Expanded(child: Text('Salon duyệt: ${widget.nail.salonName}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))),
                              ],
                            ),
                            const Divider(color: Colors.blue, height: 20),
                            Row(
                              children: [
                                const Icon(Icons.face_retouching_natural, color: Colors.blue, size: 20),
                                const SizedBox(width: 12),
                                Expanded(child: Text('Thợ thực hiện: ${widget.nail.stylistName ?? "Đã được chỉ định"}', style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600))),
                              ],
                            ),
                          ],
                        ),
                      ),

                      BookingDateSelection(
                        selectedDate: _selectedDate,
                        onDateChanged: (date) {
                          setState(() => _selectedDate = date);
                          _fetchTimeSlots(); // Forward tới gọi hàm lấy giờ rảnh
                        },
                      ),
                      const SizedBox(height: 24),

                      BookingTimeSelection(
                        timeSlots: _timeSlots,
                        isLoading: _isLoadingTimes,
                        selectedTime: _selectedTime,
                        canSelect: _selectedDate != null, // Chỉ cần chọn ngày là được phép chọn giờ
                        selectedDate: _selectedDate,
                        onTimeChanged: (time) => setState(() => _selectedTime = time),
                      ),
                    ],
                  ),
                ),

                // BƯỚC 3: SUMMARY
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Xác nhận thông tin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderLight)),
                        child: Column(
                          children: [
                            _buildSummaryRow(Icons.storefront, 'Chi nhánh', widget.nail.salonName ?? ''),
                            _buildSummaryRow(Icons.calendar_month, 'Ngày hẹn', _selectedDate != null ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}' : ''),
                            _buildSummaryRow(Icons.access_time, 'Thời gian', _selectedTime ?? ''),
                            _buildSummaryRow(Icons.face, 'Thợ thực hiện', widget.nail.stylistName ?? 'Đã được chỉ định'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderLight)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Chi tiết thanh toán', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 12),
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(child: Text('Móng Custom: ${widget.nail.name}', style: const TextStyle(fontSize: 14))),
                                  Text(
                                    PriceFormatter.format(widget.nail.price ?? 0),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),
                            ..._selectedExtraServices.whereType<String>().map((serviceId) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Dịch vụ thêm: ${_serviceNameById(serviceId)}', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                                    Text(
                                      PriceFormatter.format(_servicePriceById(serviceId)),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    )
                                  ],
                                ),
                              );
                            }),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tổng cộng tạm tính:', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text(
                                  PriceFormatter.format((widget.nail.price ?? 0) + _selectedExtraServicesTotal),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18),
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
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16), color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          bool isCompleted = index <= _currentStep;
          return Row(
            children: [
              CircleAvatar(radius: 12, backgroundColor: isCompleted ? AppColors.primary : Colors.grey.shade300, child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11))),
              if (index < 2) Container(width: 40, height: 2, color: index < _currentStep ? AppColors.primary : Colors.grey.shade300),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildFooter() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: _isSubmitting ? null : _handleNextAction,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_currentStep == 2 ? 'Xác nhận Đặt lịch' : 'Tiếp tục', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}