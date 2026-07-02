import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';

import '../widgets/booking_service_selection.dart';
import '../widgets/booking_date_selection.dart';
import '../widgets/booking_seat_selection.dart'; // IMPORT WIDGET GHE
import '../widgets/booking_time_selection.dart';

// Import API & Model
import '../../data/datasources/booking_api_service.dart';
import '../../../my_studio/data/models/customer_nail_model.dart'; // Đảm bảo import Model chính xác

class CustomNailBookingPage extends StatefulWidget {
  final CustomerNailModel nail; // Nhận vào móng đã được duyệt

  const CustomNailBookingPage({super.key, required this.nail});

  @override
  State<CustomNailBookingPage> createState() => _CustomNailBookingPageState();
}

class _CustomNailBookingPageState extends State<CustomNailBookingPage> {
  final PageController _pageController = PageController();
  final BookingApiService _apiService = BookingApiService();

  int _currentStep = 0; // 0: Seat, 1: Dịch vụ thêm, 2: Ngày/Giờ, 3: Xác nhận
  bool _isSubmitting = false;

  // Data
  List<dynamic> _services = [];
  List<dynamic> _timeSlots = [];

  bool _isLoadingServices = true;
  bool _isLoadingTimes = false;

  // Selections
  String? _selectedSeat; // Thêm biến lưu ghế
  List<String?> _selectedExtraServices = [];
  DateTime? _selectedDate;
  String? _selectedTime;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  // --- API LẤY DANH SÁCH DỊCH VỤ ---
  Future<void> _fetchServices() async {
    try {
      final services = await _apiService.getServices();
      if (mounted) setState(() { _services = services; _isLoadingServices = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoadingServices = false);
    }
  }

  // --- API LẤY GIỜ RẢNH CỦA THỢ ĐÃ ĐƯỢC CHỈ ĐỊNH ---
  Future<void> _fetchTimeSlots() async {
    if (_selectedDate == null) return;
    setState(() { _isLoadingTimes = true; _timeSlots = []; _selectedTime = null; });

    try {
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      final artistId = widget.nail.nailArtistId ?? ''; // Lấy nailArtistId từ approved artist

      if (artistId.isEmpty) throw Exception('Không tìm thấy thông tin Thợ được chỉ định');

      final times = await _apiService.getArtistAvailableSlots(artistId, dateStr);
      if (mounted) setState(() { _timeSlots = times; _isLoadingTimes = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoadingTimes = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải giờ rảnh: $e')));
      }
    }
  }

  // XỬ LÝ LOGIC GIÁ & SỐ LƯỢNG DỊCH VỤ THÊM
  void _handleServiceChanged(List<String?> services) {
    setState(() {
      _selectedExtraServices = services;
      _selectedTime = null;
      _timeSlots = [];
    });
    if (_selectedDate != null) _fetchTimeSlots();
  }

  // Nhóm dịch vụ (x2, x3)
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

  // SUBMIT API ĐẶT LỊCH
  Future<void> _executeBooking() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final salonId = widget.nail.salonId;
      final artistId = widget.nail.nailArtistId ?? '';
      final nailId = widget.nail.customerNailId;

      if (nailId <= 0) {
        throw Exception('ID Móng không hợp lệ.');
      }

      if (salonId == null || salonId.isEmpty || artistId.isEmpty) {
        throw Exception('Dữ liệu Móng Custom bị thiếu thông tin Chi nhánh hoặc Thợ');
      }

      final formattedDate = "${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}T00:00:00";
      final formattedTime = _selectedTime!.length == 5 ? "$_selectedTime:00" : _selectedTime!;

      final response = await _apiService.createCustomNailBooking(
        salonId,
        formattedDate,
        formattedTime,
        artistId,
        nailId,
        _groupedServicesMap,
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
          SnackBar(content: Text(e.toString().replaceAll('Exception: ', 'Lỗi: '))),
        );
      }
    }
  }

  // --- ĐIỀU HƯỚNG BƯỚC ---
  void _handleBackAction() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      context.pop();
    }
  }

  void _handleNextAction() {
    if (_currentStep == 0 && _selectedSeat == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn ghế ngồi!')));
      return;
    }
    if (_currentStep == 1 && _selectedExtraServices.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Có ô dịch vụ đang bị bỏ trống!')));
      return;
    }
    if (_currentStep == 2 && (_selectedDate == null || _selectedTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn đầy đủ ngày và khung giờ!')));
      return;
    }

    if (_currentStep < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _executeBooking();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Tạo Map ảo truyền vào Widget ServiceSelection
    final customNailMappedData = {
      'name': widget.nail.name,
      'price': widget.nail.price,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: _handleBackAction),
        title: const Text('Đặt Lịch Custom Nail', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        backgroundColor: Colors.white, elevation: 0, centerTitle: true,
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
                // BƯỚC 0: CHỌN GHẾ
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: BookingSeatSelection(
                    selectedSeatId: _selectedSeat,
                    onSeatSelected: (seatId) => setState(() => _selectedSeat = seatId),
                  ),
                ),

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

                // CHỌN NGÀY -> GIỜ
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      //Thợ đã duyệt
                      Container(
                        padding: const EdgeInsets.all(16),
                        margin: const EdgeInsets.only(bottom: 24),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.blue.shade200)),
                        child: Row(
                          children: [
                            const Icon(Icons.face_retouching_natural, color: Colors.blue, size: 28),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Chuyên viên thực hiện:', style: TextStyle(color: Colors.blue, fontSize: 12)),
                                  Text(widget.nail.stylistName, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 16)),
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
                          _fetchTimeSlots(); // Forward tới gọi hàm lấy giờ rảnh của thợ
                        },
                      ),
                      const SizedBox(height: 24),

                      BookingTimeSelection(
                        timeSlots: _timeSlots,
                        isLoading: _isLoadingTimes,
                        selectedTime: _selectedTime,
                        canSelect: _selectedDate != null, // Chỉ cần chọn ngày là lấy giờ
                        selectedDate: _selectedDate,
                        onTimeChanged: (time) => setState(() => _selectedTime = time),
                      ),
                    ],
                  ),
                ),

                // BƯỚC 2: SUMMARY
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
                            // Ko hiện tên Salon ở đây vì trong Móng Custom làm méo gì có tên Salon, hiện Thợ là đủ uy tín (uy tin như nha cai den tu chauau)
                            _buildSummaryRow(Icons.chair, 'Ghế', _selectedSeat != null ? 'Ghế ${_selectedSeat!.split('_').last}' : ''),
                            _buildSummaryRow(Icons.calendar_month, 'Ngày hẹn', _selectedDate != null ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}' : ''),
                            _buildSummaryRow(Icons.access_time, 'Thời gian', _selectedTime ?? ''),
                            _buildSummaryRow(Icons.face, 'Thợ thực hiện', widget.nail.stylistName),
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
                                  Expanded(child: Text('Thiết kế Móng: ${widget.nail.name}', style: const TextStyle(fontSize: 14))),
                                  Text(
                                    PriceFormatter.format(widget.nail.price),
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                ],
                              ),
                            ),

                            // DUYỆT QUA MAP ĐỂ IN RA SỐ LƯỢNG x2, x3
                            ..._groupedServicesMap.entries.map((entry) {
                              final serviceId = entry.key;
                              final qty = entry.value;
                              final price = _servicePriceById(serviceId);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // BỌC EXPANDED Ở ĐÂY
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(right: 12.0), // Cách phần giá một khoảng an toàn
                                        child: Text(
                                          '${qty}x ${_serviceNameById(serviceId)}',
                                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      PriceFormatter.format(price * qty),
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
                                  PriceFormatter.format(widget.nail.price + _selectedExtraServicesTotal),
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
        children: List.generate(4, (index) {
          bool isCompleted = index <= _currentStep;
          return Row(
            children: [
              CircleAvatar(radius: 12, backgroundColor: isCompleted ? AppColors.primary : Colors.grey.shade300, child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11))),
              if (index < 3) Container(width: 40, height: 2, color: index < _currentStep ? AppColors.primary : Colors.grey.shade300),
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
          if (_currentStep > 0)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: OutlinedButton(
                onPressed: _isSubmitting ? null : _handleBackAction,
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15), side: const BorderSide(color: AppColors.primary), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text('Quay lại', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _handleNextAction,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_currentStep == 3 ? 'Xác nhận Đặt lịch' : 'Tiếp tục', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}