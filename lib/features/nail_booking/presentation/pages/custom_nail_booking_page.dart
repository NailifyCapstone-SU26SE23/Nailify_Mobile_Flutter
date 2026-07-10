import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';

import '../widgets/booking_service_selection.dart';
import '../widgets/booking_date_selection.dart';
import '../widgets/booking_seat_selection.dart'; // IMPORT WIDGET GHE
import '../widgets/booking_promotion_sheet.dart';
import '../widgets/booking_time_selection.dart';

// Import API & Model
import '../../data/datasources/booking_api_service.dart';
import '../../data/models/promotion_model.dart';
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

  int _currentStep = 0; // 0: Dịch vụ thêm, 1: Ngày/Giờ, 2: Xác nhận
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
  List<PromotionModel> _selectedPromotions = [];

  // Hold slot state
  String? _holdToken;
  DateTime? _holdExpiresAt;
  int _holdRemainingSeconds = 0;
  bool _isHolding = false;
  Timer? _holdTimer;

  @override
  void initState() {
    super.initState();
    _fetchServices();
  }

  @override
  void dispose() {
    // Huỷ giữ chỗ khi user thoát khỏi quá trình đặt lịch
    if (_holdToken != null) {
      _apiService.cancelHoldSlot(_holdToken!);
    }
    _holdTimer?.cancel();
    super.dispose();
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

  // XUỶ LÝ LOGIC GIÁ & SỐ LƯỢNG DỊCH VỤ THÊM
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

  int get _totalPrice {
    return widget.nail.price + _selectedExtraServicesTotal;
  }

  int get _discountAmount {
    if (_selectedPromotions.isEmpty) return 0;
    double totalDiscount = 0;
    final subtotal = _totalPrice.toDouble();
    for (var promo in _selectedPromotions) {
      if (promo.discountType == 'Percentage') {
        totalDiscount += subtotal * (promo.discountValue / 100);
      } else {
        totalDiscount += promo.discountValue;
      }
    }
    return totalDiscount.toInt();
  }

  int get _finalPrice {
    final finalPrice = _totalPrice - _discountAmount;
    return finalPrice < 0 ? 0 : finalPrice;
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
        selectedPromotionIds: _selectedPromotions.isEmpty
            ? null
            : _selectedPromotions.map((p) => p.promotionId).toList(),
        holdToken: _holdToken,
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

  // ── HOLD SLOT LOGIC ─────────────────────────────────────────────────────────

  /// Giữ chỗ slot khi user chọn giờ.
  Future<void> _holdSlot(String time) async {
    final artistId = widget.nail.nailArtistId ?? '';
    final salonId = widget.nail.salonId ?? '';
    if (artistId.isEmpty || salonId.isEmpty || _selectedDate == null) return;

    final bookingDate = "${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}T00:00:00";
    final formattedTime = time.length == 5 ? '$time:00' : time;

    // Build bookingItems: customerNail + extra services
    final bookingItems = <Map<String, dynamic>>[
      {'customerNailId': widget.nail.customerNailId, 'quantity': 1},
      ..._groupedServicesMap.entries.map((e) => {'serviceId': e.key, 'quantity': e.value}),
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

      // Đồng bộ đồng hồ: dùng expiresAt UTC từ server
      DateTime? expiresAt;
      if (expiresAtStr != null) {
        try { expiresAt = DateTime.parse(expiresAtStr).toUtc(); } catch (_) {}
      }
      final remaining = expiresAt != null
          ? expiresAt.difference(DateTime.now().toUtc()).inSeconds.clamp(0, 600)
          : (data['remainingSeconds'] as num?)?.toInt() ?? 300;

      setState(() {
        _holdToken = token;
        _holdExpiresAt = expiresAt;
        _holdRemainingSeconds = remaining;
        _isHolding = true;
      });
      _startHoldTimer(token, expiresAt);
    } catch (_) {
      // Không throw — không chặn user chọn giờ
    }
  }

  void _startHoldTimer(String token, DateTime? expiresAt) {
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) { _holdTimer?.cancel(); return; }

      final remaining = expiresAt != null
          ? expiresAt.difference(DateTime.now().toUtc()).inSeconds.clamp(0, 600)
          : (_holdRemainingSeconds - 1).clamp(0, 600);

      if (_holdToken != token) { _holdTimer?.cancel(); return; }

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
          _pageController.animateToPage(1,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut);
        }
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Thời gian giữ chỗ đã hết! Vui lòng chọn lại khung giờ.')),
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
          _buildHoldCountdownBanner(),
          Expanded(
            child: PageView(
              controller: _pageController,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (idx) => setState(() => _currentStep = idx),
              children: [
                // BƯỚC 0: CHỌN GHẾ (Đã ẩn)
                /*
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: BookingSeatSelection(
                    selectedSeatId: _selectedSeat,
                    onSeatSelected: (seatId) => setState(() => _selectedSeat = seatId),
                  ),
                ),
                */

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
                        onTimeChanged: (time) {
                          // Huỷ hold cũ nếu user đổi giờ
                          if (_holdToken != null) _cancelCurrentHold();
                          setState(() => _selectedTime = time);
                          _holdSlot(time);
                        },
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
                            // _buildSummaryRow(Icons.chair, 'Ghế', _selectedSeat != null ? 'Ghế ${_selectedSeat!.split('_').last}' : ''),
                            _buildSummaryRow(Icons.calendar_month, 'Ngày hẹn', _selectedDate != null ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}' : ''),
                            _buildSummaryRow(Icons.access_time, 'Thời gian', _selectedTime ?? ''),
                            _buildSummaryRow(Icons.face, 'Thợ thực hiện', widget.nail.stylistName),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Khối chọn khuyến mãi
                      _buildPromotionSelector(),
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
                                 const Text('Tạm tính:', style: TextStyle(fontWeight: FontWeight.bold)),
                                 Text(
                                   PriceFormatter.format(_totalPrice),
                                   style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                 ),
                               ],
                             ),
                             if (_discountAmount > 0)
                               Padding(
                                 padding: const EdgeInsets.only(top: 8.0),
                                 child: Row(
                                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                   children: [
                                     const Text('Giảm giá:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
                                     Text('-${PriceFormatter.format(_discountAmount)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 16)),
                                   ],
                                 ),
                               ),
                             const Divider(height: 16),
                             Row(
                               mainAxisAlignment: MainAxisAlignment.spaceBetween,
                               children: [
                                 const Text('Tổng cộng:', style: TextStyle(fontWeight: FontWeight.bold)),
                                 Text(
                                   PriceFormatter.format(_finalPrice),
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

  Widget _buildPromotionSelector() {
    final hasPromos = _selectedPromotions.isNotEmpty;
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BookingPromotionSheet(
            selectedPromotions: _selectedPromotions,
            onConfirm: (promos) => setState(() => _selectedPromotions = promos),
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasPromos ? AppColors.primary.withOpacity(0.06) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasPromos ? AppColors.primary.withOpacity(0.5) : Colors.grey.shade300,
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
                    ? 'Đã chọn ${_selectedPromotions.length} khuyến mãi'
                    : 'Chọn voucher / khuyến mãi',
                style: TextStyle(
                  color: hasPromos ? AppColors.primary : Colors.grey.shade600,
                  fontWeight: hasPromos ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: hasPromos ? AppColors.primary : Colors.grey.shade400),
          ],
        ),
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
                : Text(_currentStep == 2 ? 'Xác nhận Đặt lịch' : 'Tiếp tục', style: const TextStyle(fontWeight: FontWeight.bold)),
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
                  ? 'Chỗ có thể bị giải phóng sau $min:$sec giây!'
                  : 'Slot đang được giữ chỗ cho bạn – còn $min:$sec để hoàn tất',
              style: const TextStyle(
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}