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
import '../widgets/booking_seat_selection.dart'; // IMPORT WIDGET GHE
import '../widgets/booking_promotion_sheet.dart';
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
  int _currentStep = 0; // 0: Salon, 1: Seat, 2: Service, 3: DateTime & Staff, 4: Summary
  bool _isSubmitting = false;

  // API Lists
  List<dynamic> _salons = [];
  List<dynamic> _services = [];
  List<dynamic> _artists = [];
  List<dynamic> _timeSlots = [];

  bool _isLoadingSalons = true;
  bool _isLoadingArtists = false;
  bool _isLoadingTimes = false;

  // User State
  Map<String, dynamic>? _selectedBranch;
  String? _selectedSeat; // Thêm biến lưu ghế
  List<String?> _selectedExtraServices = [];
  DateTime? _selectedDate;
  Map<String, dynamic>? _selectedStylist;
  String? _selectedTime;
  List<PromotionModel> _selectedPromotions = [];
  bool _noArtistSelected = false; // Khách không chọn thợ, hệ thống tự phân công

  @override
  void initState() {
    super.initState();
    _fetchSalons();
    _fetchServices();
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
        _selectedExtraServices.whereType<String>().toList(), // Lọc bỏ null trước khi gọi API
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
      // Không chọn thợ: generate slots từ lịch salon
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
          selectedPromotionIds: _selectedPromotions.isEmpty
              ? null
              : _selectedPromotions.map((p) => p.promotionId).toList(),
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

  // Getter cho _selectedPromotionIds
  List<int>? get _selectedPromotionIdsOrNull => _selectedPromotions.isEmpty
      ? null
      : _selectedPromotions.map((p) => p.promotionId).toList();

  void _handleServiceChanged(List<String?> services) {
    setState(() {
      _selectedExtraServices = services;
      _selectedStylist = null;
      _selectedTime = null;
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

  int get _estimatedTotalPrice => _nailVariantPrice + _selectedExtraServicesTotal;

  int get _discountAmount {
    if (_selectedPromotions.isEmpty) return 0;
    double totalDiscount = 0;
    final subtotal = _estimatedTotalPrice.toDouble();
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
    final finalPrice = _estimatedTotalPrice - _discountAmount;
    return finalPrice < 0 ? 0 : finalPrice;
  }

  void _handleNextAction() {
    if (_currentStep == 0 && _selectedBranch == null) {
      _showSnackBar('Vui lòng chọn một chi nhánh salon!'); return;
    }
    if (_currentStep == 1 && _selectedSeat == null) {
      _showSnackBar('Vui lòng chọn ghế ngồi!'); return;
    }
    if (_currentStep == 2) {
      // Bắt lỗi nếu bấm "Thêm dịch vụ" nhưng thả trống Dropdown
      if (_selectedExtraServices.contains(null)) {
        _showSnackBar('Có ô dịch vụ đang bị bỏ trống. Vui lòng chọn hoặc xóa nó đi!'); return;
      }
      final validServices = _selectedExtraServices.whereType<String>().toList();
      if (widget.nailData == null && validServices.isEmpty) {
        _showSnackBar('Vui lòng chọn ít nhất 1 dịch vụ để tiếp tục!'); return;
      }
    }
    if (_currentStep == 3 && (_selectedDate == null || (_selectedStylist == null && !_noArtistSelected) || _selectedTime == null)) {
      _showSnackBar('Vui lòng chọn đầy đủ ngày, thợ (hoặc để tự động) và khung giờ!'); return;
    }

    if (_currentStep < 4) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _executeBooking();
    }
  }

  void _showSnackBar(String msg) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: _handleBackAction),
        title: const Text('Đặt Lịch Hẹn', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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

                // BƯỚC 1: CHỌN SALON
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: BranchSelectionList(
                    salons: _salons,
                    isLoading: _isLoadingSalons,
                    selectedBranchId: _selectedBranch?['salonId'],
                    onBranchSelected: (branch) => setState(() {
                      _selectedBranch = branch;
                      _selectedSeat = null; // Reset ghế khi đổi chi nhánh
                    }),
                  ),
                ),

                // BƯỚC 2: CHỌN GHẾ
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: BookingSeatSelection(
                    selectedSeatId: _selectedSeat,
                    onSeatSelected: (seatId) => setState(() => _selectedSeat = seatId),
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
                        canSelect: (_selectedStylist != null || _noArtistSelected) && _selectedDate != null,
                        selectedDate: _selectedDate,
                        onTimeChanged: (time) => setState(() {
                          _selectedTime = time;
                        }),
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
                      const Text('Xác nhận thông tin đặt lịch', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.borderLight)),
                        child: Column(
                          children: [
                            _buildSummaryRow(Icons.storefront, 'Chi nhánh', _selectedBranch?['name'] ?? ''),
                            _buildSummaryRow(Icons.chair, 'Ghế', _selectedSeat != null ? 'Ghế ${_selectedSeat!.split('_').last}' : ''),
                            _buildSummaryRow(Icons.calendar_month, 'Ngày hẹn', _selectedDate != null ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}' : ''),
                            _buildSummaryRow(Icons.access_time, 'Thời gian', _selectedTime != null ? _selectedTime!.substring(0, 5) : ''),
                            _buildSummaryRow(Icons.face, 'Thợ thực hiện',
                              _noArtistSelected ? 'Tự động phân công' : (_selectedStylist?['fullName'] ?? '')),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
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
                            if (widget.nailData != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text('Biến thể Nail: ${widget.nailData!['name']}', style: const TextStyle(fontSize: 14))),
                                    Text(
                                      PriceFormatter.format(widget.nailData?['price']),
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                              ),

                                  // Fix: Lọc bỏ null trước khi render list summary
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
                                        padding: const EdgeInsets.only(right: 12.0), // Cách giá tiền một khoảng nhỏ
                                        child: Text(
                                          'Dịch vụ thêm: $serviceName',
                                          style: const TextStyle(fontSize: 14, color: Colors.grey),
                                        ),
                                      ),
                                    ),
                                    Text(
                                      PriceFormatter.format(servicePrice),
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
                                   PriceFormatter.format(_estimatedTotalPrice),
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
            onConfirm: (promos) => setState(() {
              _selectedPromotions = promos;
            }),
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

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16), color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(5, (index) {
          bool isCompleted = index <= _currentStep;
          return Row(
            children: [
              CircleAvatar(radius: 12, backgroundColor: isCompleted ? AppColors.primary : Colors.grey.shade300, child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 11))),
              if (index < 4) Container(width: 30, height: 2, color: index < _currentStep ? AppColors.primary : Colors.grey.shade300),
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
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: _isSubmitting ? null : _handleBackAction,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Quay lại', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
            )
          else
            const SizedBox.shrink(),
          ElevatedButton(
            onPressed: _isSubmitting ? null : _handleNextAction,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: _isSubmitting
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(_currentStep == 4 ? 'Xác nhận Đặt lịch' : 'Tiếp tục', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
