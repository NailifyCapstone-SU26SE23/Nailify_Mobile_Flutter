// lib/features/nail_booking/presentation/pages/nail_booking_page.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/auth_guard.dart';

import '../../data/datasources/booking_api_service.dart';
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
  int _currentStep = 0; // 0: Salon, 1: Service, 2: DateTime & Staff, 3: Summary
  bool _isSubmitting = false;

  // API Lists
  List<dynamic> _salons = [];
  List<dynamic> _artists = [];
  List<dynamic> _timeSlots = [];

  bool _isLoadingSalons = true;
  bool _isLoadingArtists = false;
  bool _isLoadingTimes = false;

  // User State
  Map<String, dynamic>? _selectedBranch;
  List<String?> _selectedExtraServices = [];
  DateTime? _selectedDate;
  Map<String, dynamic>? _selectedStylist;
  String? _selectedTime;

  @override
  void initState() {
    super.initState();
    _fetchSalons();
  }

  int get _nailVariantId {
    return int.tryParse(widget.nailData?['id']?.toString() ?? '0') ?? 0;
  }

  String _formatBookingDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return "$y-$m-${d}T00:00:00.000Z";
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
      final data = await _apiService.getSuggestedArtists(_selectedBranch!['salonId'], dateStr, _nailVariantId);
      setState(() { _artists = data; _isLoadingArtists = false; });
    } catch (e) {
      setState(() => _isLoadingArtists = false);
      _showSnackBar('Lỗi tải danh sách thợ: $e');
    }
  }

  Future<void> _fetchTimeSlots() async {
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

  Future<void> _executeBooking() async {
    AuthGuard.check(context, () async {
      if (_isSubmitting) return;
      setState(() => _isSubmitting = true);
      try {
        await _apiService.createBooking(
            _selectedBranch!['salonId'],
            _formatBookingDate(_selectedDate!),
            _selectedTime!,
            _selectedStylist!['nailArtistId'],
            _nailVariantId
        );

        if (!mounted) return;
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Thành công')]),
            content: const Text('Đơn đặt lịch của bạn đã được xác nhận thành công!'),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.go('/');
                },
                child: const Text('Quay về trang chủ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        );
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

  void _handleNextAction() {
    if (_currentStep == 0 && _selectedBranch == null) {
      _showSnackBar('Vui lòng chọn một chi nhánh salon!'); return;
    }
    if (_currentStep == 1) {
      if (widget.nailData == null && (_selectedExtraServices.isEmpty || _selectedExtraServices.every((e) => e == null))) {
        _showSnackBar('Vui lòng chọn ít nhất 1 dịch vụ để tiếp tục!'); return;
      }
      if (_selectedExtraServices.any((s) => s == null)) {
        _showSnackBar('Có trường dịch vụ phụ trợ đang bị bỏ trống!'); return;
      }
    }
    if (_currentStep == 2 && (_selectedDate == null || _selectedStylist == null || _selectedTime == null)) {
      _showSnackBar('Vui lòng chọn đầy đủ ngày, thợ và khung giờ!'); return;
    }

    if (_currentStep < 3) {
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
                    onBranchSelected: (branch) => setState(() => _selectedBranch = branch),
                  ),
                ),

                // BƯỚC 2: CHỌN DỊCH VỤ (MỚI TÁI TÍCH HỢP)
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: BookingServiceSelection(
                    nailData: widget.nailData,
                    selectedExtraServices: _selectedExtraServices,
                    onChanged: (services) => setState(() => _selectedExtraServices = services),
                  ),
                ),

                // BƯỚC 3: NGÀY -> THỢ -> GIỜ (ĐÃ SỬA Ô CHỌN THỢ LUÔN HIỆN)
                SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      BookingDateSelection(
                        selectedDate: _selectedDate,
                        onDateChanged: (date) {
                          setState(() => _selectedDate = date);
                          _fetchArtists(); // Tự động cập nhật danh sách thợ
                        },
                      ),
                      const SizedBox(height: 24),

                      BookingStylistSelection(
                        artists: _artists,
                        isLoading: _isLoadingArtists,
                        selectedStylistId: _selectedStylist?['nailArtistId'],
                        onStylistSelected: (artist) {
                          setState(() => _selectedStylist = artist);
                          _fetchTimeSlots(); // Tìm giờ rảnh của thợ vừa chọn
                        },
                      ),
                      const SizedBox(height: 24),

                      BookingTimeSelection(
                        timeSlots: _timeSlots,
                        isLoading: _isLoadingTimes,
                        selectedTime: _selectedTime,
                        canSelect: _selectedStylist != null && _selectedDate != null,
                        onTimeChanged: (time) => setState(() => _selectedTime = time),
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
                            _buildSummaryRow(Icons.calendar_month, 'Ngày hẹn', _selectedDate != null ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}' : ''),
                            _buildSummaryRow(Icons.access_time, 'Thời gian', _selectedTime != null ? _selectedTime!.substring(0, 5) : ''),
                            _buildSummaryRow(Icons.face, 'Thợ thực hiện', _selectedStylist?['fullName'] ?? ''),
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
                            if (widget.nailData != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(child: Text('Biến thể Nail: ${widget.nailData!['name']}', style: const TextStyle(fontSize: 14))),
                                    Text('${widget.nailData!['price']} Đ', style: const TextStyle(fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ..._selectedExtraServices.map((serviceName) {
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text('Dịch vụ thêm: $serviceName', style: const TextStyle(fontSize: 14, color: Colors.grey)),
                                    const Text('Phí tại quầy', style: TextStyle(fontStyle: FontStyle.italic, color: Colors.grey, fontSize: 13)),
                                  ],
                                ),
                              );
                            }),
                            const Divider(height: 24),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                const Text('Tổng cộng tạm tính:', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('${widget.nailData?['price'] ?? 0} Đ', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 18)),
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
              if (index < 3) Container(width: 30, height: 2, color: index < _currentStep ? AppColors.primary : Colors.grey.shade300),
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
                : Text(_currentStep == 3 ? 'Xác nhận Đặt lịch' : 'Tiếp tục', style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}