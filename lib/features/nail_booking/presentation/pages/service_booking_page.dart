import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/duration_formatter.dart';

import '../../../nail_booking/data/datasources/booking_api_service.dart';
import '../../../nail_booking/presentation/widgets/branch_selection_list.dart';
import '../../../nail_booking/presentation/widgets/booking_service_selection.dart';
import '../../../nail_booking/presentation/widgets/booking_date_selection.dart';
import '../../../nail_booking/presentation/widgets/booking_stylist_selection.dart';
import '../../../nail_booking/presentation/widgets/booking_time_selection.dart';

class ServiceBookingPage extends StatefulWidget {
  final Map<String, dynamic> baseService;

  const ServiceBookingPage({super.key, required this.baseService});

  @override
  State<ServiceBookingPage> createState() => _ServiceBookingPageState();
}

class _ServiceBookingPageState extends State<ServiceBookingPage> {
  final PageController _pageController = PageController();
  final BookingApiService _apiService = BookingApiService();

  int _currentStep =
      0; // 0: Salon, 1: Services, 2: DateTime & Stylist, 3: Summary
  bool _isSubmitting = false;

  // Data
  List<dynamic> _salons = [];
  List<dynamic> _services = [];
  List<dynamic> _artists = [];
  List<dynamic> _timeSlots = [];

  bool _isLoadingSalons = true;
  bool _isLoadingArtists = false;
  bool _isLoadingTimes = false;

  // Selections
  Map<String, dynamic>? _selectedSalon;
  List<String?> _selectedExtraServices = [];
  DateTime? _selectedDate;
  Map<String, dynamic>? _selectedStylist;
  String? _selectedTime;
  bool _noArtistSelected = false;

  @override
  void initState() {
    super.initState();
    _fetchInitialData();
  }

  Future<void> _fetchInitialData() async {
    try {
      final salons = await _apiService.getSalons();
      final services = await _apiService.getServices();
      if (mounted) {
        setState(() {
          _salons = salons;
          _services = services;
          _isLoadingSalons = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingSalons = false);
    }
  }

  Future<void> _fetchArtists() async {
    if (_selectedSalon == null || _selectedDate == null) return;
    setState(() {
      _isLoadingArtists = true;
      _artists = [];
      _selectedStylist = null;
      _selectedTime = null;
    });
    try {
      final artists = await _apiService.getNailArtistsBySalon(
        _selectedSalon!['salonId'],
      );
      if (mounted) {
        setState(() {
          _artists = artists;
          _isLoadingArtists = false;
          if (_artists.isEmpty) {
            _noArtistSelected = true;
          }
        });
        if (_artists.isEmpty) {
          _fetchTimeSlots();
        }
      }
    } catch (e) {
      if (mounted) setState(() => _isLoadingArtists = false);
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
      final dateStr = _selectedDate!.toIso8601String().split('T')[0];
      final times = await _apiService.getArtistAvailableSlots(
        _selectedStylist!['nailArtistId'],
        dateStr,
      );
      if (mounted)
        setState(() {
          _timeSlots = times;
          _isLoadingTimes = false;
        });
    } catch (e) {
      if (mounted) setState(() => _isLoadingTimes = false);
    }
  }

  void _loadSalonSlots() {
    if (_selectedSalon == null || _selectedDate == null) return;
    setState(() {
      _timeSlots = _apiService.getSalonOperatingSlots(
        _selectedSalon!,
        _selectedDate!,
      );
      _selectedTime = null;
    });
  }

  // --- LOGIC XỬ LÝ GỘP DỊCH VỤ VÀ TÍNH TIỀN ---

  // Hàm gộp các dịch vụ giống nhau (để tính Quantity x2, x3)
  Map<String, int> get _groupedServicesMap {
    final map = <String, int>{};
    // 1. Nạp dịch vụ gốc vào trước
    final baseId = widget.baseService['serviceId']?.toString() ?? '';
    if (baseId.isNotEmpty) map[baseId] = 1;

    // 2. Cộng dồn các dịch vụ thêm
    for (var id in _selectedExtraServices.whereType<String>()) {
      map[id] = (map[id] ?? 0) + 1;
    }
    return map;
  }

  Map<String, dynamic>? _getServiceDetail(String id) {
    if (id == widget.baseService['serviceId']) return widget.baseService;
    final matches = _services.where((s) => s['serviceId'] == id);
    return matches.isNotEmpty ? matches.first as Map<String, dynamic> : null;
  }

  int get _totalPrice {
    int total = 0;
    _groupedServicesMap.forEach((id, qty) {
      final svc = _getServiceDetail(id);
      final price = (svc?['price'] as num?)?.toInt() ?? 0;
      total += price * qty;
    });
    return total;
  }

  // --- LOGIC ĐẶT LỊCH (SUBMIT) ---
  Future<void> _executeBooking() async {
    if (_isSubmitting) return;
    setState(() => _isSubmitting = true);

    try {
      final bookingItems = _groupedServicesMap.entries.map((entry) {
        return {
          "nailVariantId": null,
          "serviceId": entry.key,
          "customerNailId": null,
          "quantity": entry.value,
        };
      }).toList();

      final formattedDate =
          "${_selectedDate!.year.toString().padLeft(4, '0')}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}T00:00:00";
      final formattedTime = _selectedTime!.length == 5
          ? "$_selectedTime:00"
          : _selectedTime!;

      final payload = {
        "salonId": _selectedSalon!['salonId'],
        "bookingDate": formattedDate,
        "startTime": formattedTime,
        "nailArtistId": _noArtistSelected
            ? null
            : _selectedStylist!['nailArtistId'],
        "holdToken": null,
        "bookingItems": bookingItems,
      };

      final response = await _apiService.createServiceBooking(payload);

      if (mounted) {
        final successData = {
          'bookingId': response['bookingId']?.toString() ?? '',
          'serviceName': widget.baseService['name'],
          'date': _selectedDate,
          'time': formattedTime,
          'stylistName': _noArtistSelected
              ? 'Tự động phân công'
              : _selectedStylist!['fullName'],
        };
        context.go('/booking-success', extra: successData);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi đặt lịch: $e')));
      }
    }
  }

  // --- ĐIỀU HƯỚNG ---
  void _handleNextAction() {
    if (_currentStep == 0 && _selectedSalon == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng chọn 1 chi nhánh!')),
      );
      return;
    }
    if (_currentStep == 1 && _selectedExtraServices.contains(null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Có ô dịch vụ đang bị bỏ trống!')),
      );
      return;
    }
    if (_currentStep == 2 &&
        (_selectedDate == null ||
            (_selectedStylist == null && !_noArtistSelected) ||
            _selectedTime == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Vui lòng chọn đầy đủ ngày, thợ (hoặc để tự động) và khung giờ!',
          ),
        ),
      );
      return;
    }

    if (_currentStep < 3) {
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
    // Truyền Data ảo để Widget BookingServiceSelection không bị văng lỗi null
    final dummyNailData = {'name': 'Danh sách dịch vụ thêm', 'price': 0};

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20),
          onPressed: () => _currentStep > 0
              ? _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                )
              : context.pop(),
        ),
        title: const Text(
          'Đặt Lịch Dịch Vụ',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
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
                // STEP 0: SALON
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: BranchSelectionList(
                    salons: _salons,
                    isLoading: _isLoadingSalons,
                    selectedBranchId: _selectedSalon?['salonId'],
                    onBranchSelected: (salon) => setState(() {
                      _selectedSalon = salon;
                      _artists.clear();
                      _selectedStylist = null;
                      _selectedTime = null;
                    }),
                  ),
                ),

                // STEP 1: CHỌN DỊCH VỤ
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Dịch vụ đã chọn',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildBaseServiceCard(), // Widget hiển thị dịch vụ gốc
                      const SizedBox(height: 24),
                      const Divider(),
                      BookingServiceSelection(
                        nailData:
                            dummyNailData, // Pass dummy để tắt tính năng móng
                        services: _services,
                        selectedExtraServices: _selectedExtraServices,
                        onChanged: (services) =>
                            setState(() => _selectedExtraServices = services),
                      ),
                    ],
                  ),
                ),

                // STEP 2: NGÀY/THỢ/GIỜ
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
                        onTimeChanged: (time) =>
                            setState(() => _selectedTime = time),
                      ),
                    ],
                  ),
                ),

                // STEP 3: SUMMARY
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Xác nhận thông tin',
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
                              _selectedSalon?['name'] ?? '',
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
                              _selectedTime ?? '',
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
                            const SizedBox(height: 16),

                            // Render Danh sách dịch vụ gộp
                            ..._groupedServicesMap.entries.map((entry) {
                              final svc = _getServiceDetail(entry.key);
                              final name = svc?['name'] ?? 'N/A';
                              final price =
                                  (svc?['price'] as num?)?.toInt() ?? 0;
                              final qty = entry.value;

                              return Padding(
                                padding: const EdgeInsets.only(bottom: 12.0),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start, // Căn trên cùng
                                  children: [
                                    // BỌC THÊM PADDING BÊN TRONG EXPANDED
                                    Expanded(
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          right: 12.0,
                                        ),
                                        child: Text(
                                          '${qty}x $name',
                                          style: const TextStyle(fontSize: 14),
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
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text(
                                  'Tổng cộng tạm tính:',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                Text(
                                  PriceFormatter.format(_totalPrice),
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

  // --- WIDGET DỊCH VỤ GỐC ---
  Widget _buildBaseServiceCard() {
    final name = widget.baseService['name']?.toString() ?? 'Dịch vụ';
    final price = (widget.baseService['price'] as num?)?.toInt() ?? 0;
    final duration = (widget.baseService['duration'] as num?)?.toInt() ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.spa_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DurationFormatter.format(duration),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            PriceFormatter.format(price),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  // Tiện ích UI
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

  Widget _buildStepIndicator() {
    return Container(
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
                    _currentStep == 3 ? 'Xác nhận Đặt lịch' : 'Tiếp tục',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
