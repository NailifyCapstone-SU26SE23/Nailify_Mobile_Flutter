import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/booking_mock_data.dart';
import '../widgets/branch_selection_list.dart';
import '../widgets/booking_service_selection.dart';
import '../widgets/booking_date_selection.dart';    // Ngày
import '../widgets/booking_stylist_selection.dart'; // Thợ
import '../widgets/booking_time_selection.dart';    // Giờ

class NailBookingPage extends StatefulWidget {
  final Map<String, dynamic>? nailData;

  const NailBookingPage({super.key, this.nailData});

  @override
  State<NailBookingPage> createState() => _NailBookingPageState();
}

class _NailBookingPageState extends State<NailBookingPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  Map<String, String>? _selectedBranch;
  List<String?> _selectedExtraServices = []; // Chỉ có dịch vụ phụ trợ
  DateTime? _selectedDate;
  String? _selectedTime;
  Map<String, dynamic>? _selectedStylist;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selectedDate = DateTime(now.year, now.month, now.day);
    _selectedStylist = BookingMockData.stylists[0]; // Mặc định
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _handleBackAction() {
    if (_currentStep > 0) {
      _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      Navigator.of(context).pop();
    }
  }

  void _handleNextAction() {
    if (_currentStep == 0 && _selectedBranch == null) {
      _showSnackBar('Vui lòng chọn một chi nhánh salon để tiếp tục!');
      return;
    }

    if (_currentStep == 1) {
      // Nếu chưa chọn mẫu nail và CŨNG CHƯA có dịch vụ extra nào -> CHỬI
      if (widget.nailData == null && (_selectedExtraServices.isEmpty || _selectedExtraServices.every((e) => e == null))) {
        _showSnackBar('Vui lòng chọn ít nhất 1 dịch vụ để đặt lịch!');
        return;
      }
      if (_selectedExtraServices.any((s) => s == null)) {
        _showSnackBar('Có trường dịch vụ đang bị bỏ trống!');
        return;
      }
    }

    if (_currentStep == 2 && (_selectedDate == null || _selectedTime == null || _selectedStylist == null)) {
      _showSnackBar('Vui lòng chọn đầy đủ ngày, thợ và giờ làm móng!');
      return;
    }

    if (_currentStep < 3) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _executeBooking();
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _executeBooking() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(children: [Icon(Icons.check_circle, color: Colors.green, size: 28), SizedBox(width: 8), Text('Thành công', style: TextStyle(fontWeight: FontWeight.bold))]),
        content: Text('Đơn đặt lịch của bạn tại ${_selectedBranch!['name']} vào lúc $_selectedTime (${_selectedDate!.day}/${_selectedDate!.month}) đã được xác nhận!\n\nCảm ơn bạn đã tin tưởng Nailify.', style: const TextStyle(fontSize: 14, height: 1.5)),
        actions: [
          TextButton(
            onPressed: () { Navigator.of(context).pop(); },
            child: const Text('Quay về trang chủ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  int _calculateTotal() {
    int total = 150000; // Giá làm móng nền cơ bản
    if (widget.nailData != null) total += 80000; // Ước tính phụ phí mẫu nail
    for (var s in _selectedExtraServices) {
      if (s != null) total += BookingMockData.servicePrices[s] ?? 0;
    }
    return total;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) { if (didPop) return; _handleBackAction(); },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.textPrimary), onPressed: _handleBackAction),
          title: const Text('Đặt Lịch Hẹn', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          centerTitle: true, backgroundColor: Colors.white, elevation: 0,
        ),
        body: Column(
          children: [
            _buildStepIndicator(),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: [

                  // 1: CHỌN SALON
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('1. Chọn chi nhánh Salon', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 16),
                        BranchSelectionList(selectedBranchId: _selectedBranch?['id'], onBranchSelected: (branch) => setState(() => _selectedBranch = branch)),
                      ],
                    ),
                  ),

                  // 2. CHỌN DỊCH VỤ
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('2. Chọn dịch vụ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 16),
                        BookingServiceSelection(
                          nailData: widget.nailData,
                          selectedExtraServices: _selectedExtraServices,
                          onChanged: (services) => setState(() => _selectedExtraServices = services),
                        ),
                      ],
                    ),
                  ),

                  // 3: NGÀY -> THỢ -> GIỜ
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 3.1. NGÀY
                        BookingDateSelection(
                          selectedDate: _selectedDate,
                          onDateChanged: (date) => setState(() {
                            _selectedDate = date;
                            _selectedTime = null; // Đổi ngày thì hủy giờ
                          }),
                        ),
                        const SizedBox(height: 32),
                        const Divider(height: 1, color: AppColors.borderLight),
                        const SizedBox(height: 32),

                        // 3.2. THỢ
                        BookingStylistSelection(
                          selectedStylistId: _selectedStylist?['id'],
                          onStylistSelected: (stylist) => setState(() {
                            _selectedStylist = stylist;
                            _selectedTime = null; // Đổi thợ thì hủy giờ
                          }),
                        ),
                        const SizedBox(height: 32),

                        // 3.3. GIỜ
                        BookingTimeSelection(
                          selectedDate: _selectedDate,
                          selectedTime: _selectedTime,
                          selectedStylist: _selectedStylist,
                          onTimeChanged: (time) => setState(() => _selectedTime = time),
                        )
                      ],
                    ),
                  ),

                  // BƯỚC 4: SUMMARY
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('4. Xác nhận thông tin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 20),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderLight)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildSummaryRow(Icons.storefront, 'Chi nhánh', _selectedBranch?['name'] ?? ''),
                              _buildSummaryRow(Icons.calendar_month, 'Thời gian', '$_selectedTime, ${_selectedDate?.day ?? ''}/${_selectedDate?.month ?? ''}/${_selectedDate?.year ?? ''}'),
                              _buildSummaryRow(Icons.face_2, 'Thợ thực hiện', '${_selectedStylist?['name'] ?? ''} - ${_selectedStylist?['role'] ?? ''}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderLight)),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Chi tiết dịch vụ & Thanh toán', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 16),

                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [Text('Dịch vụ làm móng cơ bản', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)), Text('150.000 Đ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14))],
                              ),
                              if (widget.nailData != null)
                                const Padding(
                                  padding: EdgeInsets.only(top: 12.0),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Mẫu thiết kế đính kèm', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)), Text('80.000 Đ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14))]),
                                ),

                              ..._selectedExtraServices.map((s) {
                                if (s == null) return const SizedBox.shrink();
                                int price = BookingMockData.servicePrices[s] ?? 0;
                                return Padding(
                                  padding: const EdgeInsets.only(top: 12.0),
                                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Dịch vụ: $s', style: const TextStyle(color: AppColors.textSecondary, fontSize: 14)), Text('${price.toString().replaceAllMapped(RegExp(r'(\d{3})(?=\d)'), (m) => '${m[1]}.')} Đ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14))]),
                                );
                              }),

                              const Padding(padding: EdgeInsets.symmetric(vertical: 16.0), child: Divider(height: 1, color: AppColors.borderLight)),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween, crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Tổng cộng:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text('${_calculateTotal().toString().replaceAllMapped(RegExp(r'(\d{3})(?=\d)'), (m) => '${m[1]}.')} Đ', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary)),
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
    String footerSummary = 'Đang đặt lịch...';

    if (_currentStep == 1) {
      int totalSvcs = (widget.nailData != null ? 1 : 0) + _selectedExtraServices.length;
      footerSummary = '$totalSvcs Dịch vụ';
    } else if (_currentStep >= 2) {
      if (_selectedDate != null && _selectedTime != null) footerSummary = '$_selectedTime, ${_selectedDate!.day}/${_selectedDate!.month}';
      if (_selectedStylist != null) footerSummary += ' (${_selectedStylist!['name']})';
    } else if (_selectedBranch != null) {
      footerSummary = _selectedBranch!['name']!;
    }

    return Container(
      padding: const EdgeInsets.all(20), decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Tóm tắt:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(footerSummary, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _handleNextAction,
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
            child: Text(_currentStep == 3 ? 'Book Now' : 'Tiếp tục', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }
}