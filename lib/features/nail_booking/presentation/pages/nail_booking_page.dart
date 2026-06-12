import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/branch_selection_list.dart';
import '../widgets/booking_date_time_selection.dart';
import '../widgets/booking_stylist_selection.dart';

class NailBookingPage extends StatefulWidget {
  final Map<String, dynamic>? nailData;

  const NailBookingPage({super.key, this.nailData});

  @override
  State<NailBookingPage> createState() => _NailBookingPageState();
}

class _NailBookingPageState extends State<NailBookingPage> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  // --- LƯU TRỮ DỮ LIỆU ĐẶT LỊCH ---
  Map<String, String>? _selectedBranch;
  DateTime? _selectedDate;
  String? _selectedTime;
  Map<String, String>? _selectedStylist;

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
    // chọn đủ thì tiếp
    if (_currentStep == 0 && _selectedBranch == null) {
      _showSnackBar('Vui lòng chọn một chi nhánh salon để tiếp tục!');
      return;
    }
    if (_currentStep == 1 && (_selectedDate == null || _selectedTime == null || _selectedStylist == null)) {
      _showSnackBar('Vui lòng chọn đầy đủ ngày, giờ và thợ làm móng!');
      return;
    }

    if (_currentStep < 2) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _executeBooking(); //đặt lịch ở bước 3
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // LOGIC HIỂN THỊ POPUP THÀNH CÔNG VÀ CHUYỂN TRANG
  void _executeBooking() {
    showDialog(
      context: context,
      barrierDismissible: false, // Bắt buộc bấm nút mới được thoát
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 28),
            SizedBox(width: 8),
            Text('Thành công', style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(
          'Đơn đặt lịch của bạn tại ${_selectedBranch!['name']} vào lúc $_selectedTime (${_selectedDate!.day}/${_selectedDate!.month}) đã được xác nhận!\n\nCảm ơn bạn đã tin tưởng Nailify.',
          style: const TextStyle(fontSize: 14, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Tắt popup
              //Navigator.of(context).pop(); // Thoát màn hình đặt lịch (con bug)
            },
            child: const Text('Quay về trang chủ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 15)),
          ),
        ],
      ),
    );
  }

  // WIDGET DÙNG CHUNG  ĐỂ HIỂN THỊ CÁC DÒNG TÓM TẮT
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

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackAction();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.textPrimary),
            onPressed: _handleBackAction,
          ),
          title: const Text('Đặt Lịch Hẹn', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          centerTitle: true,
          backgroundColor: Colors.white,
          elevation: 0,
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

                  // BƯỚC 1: CHỌN SALON
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (widget.nailData != null) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.asset(
                                    widget.nailData!['image'] ?? '', width: 40, height: 40, fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) => const Icon(Icons.image, color: Colors.grey),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(child: Text('Đang đặt lịch cho mẫu:\n${widget.nailData!['name']}', style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.primary, fontSize: 13))),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],

                        const Text('1. Chọn chi nhánh Salon', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 16),

                        BranchSelectionList(
                          selectedBranchId: _selectedBranch?['id'],
                          onBranchSelected: (branch) => setState(() => _selectedBranch = branch),
                        ),
                      ],
                    ),
                  ),

                  // BƯỚC 2: CHỌN LỊCH HẸN & KỸ THUẬT VIÊN

                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        BookingDateTimeSelection(
                          selectedDate: _selectedDate,
                          selectedTime: _selectedTime,
                          onDateChanged: (date) => setState(() => _selectedDate = date),
                          onTimeChanged: (time) => setState(() => _selectedTime = time),
                        ),
                        const SizedBox(height: 32),
                        BookingStylistSelection(
                          selectedStylistId: _selectedStylist?['id'],
                          onStylistSelected: (stylist) => setState(() => _selectedStylist = stylist),
                        ),
                      ],
                    ),
                  ),

                  // BƯỚC 3: SUMMARY (XÁC NHẬN THÔNG TIN & GIÁ)
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('3. Xác nhận thông tin', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                        const SizedBox(height: 20),

                        // THÔNG TIN CHI TIẾT ĐẶT LỊCH
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderLight),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Nếu có mẫu móng thì hiển thị
                              if (widget.nailData != null) ...[
                                _buildSummaryRow(Icons.diamond_outlined, 'Mẫu thiết kế', widget.nailData!['name']),
                                const Divider(height: 20, color: AppColors.borderLight),
                              ],
                              _buildSummaryRow(Icons.storefront, 'Chi nhánh', _selectedBranch?['name'] ?? ''),
                              _buildSummaryRow(Icons.calendar_month, 'Thời gian', '$_selectedTime, ${_selectedDate?.day ?? ''}/${_selectedDate?.month ?? ''}/${_selectedDate?.year ?? ''}'),
                              _buildSummaryRow(Icons.face_2, 'Thợ thực hiện', '${_selectedStylist?['name'] ?? ''} - ${_selectedStylist?['role'] ?? ''}'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 24),

                        // CHI PHÍ ƯỚC TÍNH (set cứng)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.borderLight),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Chi tiết thanh toán', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
                              const SizedBox(height: 16),

                              const Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text('Dịch vụ làm móng cơ bản', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                                  Text('150.000 Đ', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  const Text('Phụ phí thiết kế mẫu', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
                                  Text(widget.nailData != null ? '80.000 Đ' : '0 Đ', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                                ],
                              ),

                              const Padding(
                                padding: EdgeInsets.symmetric(vertical: 16.0),
                                child: Divider(height: 1, color: AppColors.borderLight),
                              ),

                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  const Text('Tổng cộng:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  Text(
                                      widget.nailData != null ? '230.000 Đ' : '150.000 Đ',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: AppColors.primary)
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '*Lưu ý: Giá trên chỉ là ước tính, chi phí thực tế có thể thay đổi dựa trên tình trạng móng thực tế của bạn tại cửa hàng.',
                          style: TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic),
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
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(3, (index) {
          bool isCompleted = index <= _currentStep;
          return Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isCompleted ? AppColors.primary : Colors.grey.shade300,
                child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              if (index < 2)
                Container(width: 40, height: 2, color: index < _currentStep ? AppColors.primary : Colors.grey.shade300),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildFooter() {
    String footerSummary = 'Chưa cấu hình lịch hẹn';

    if (_selectedBranch != null) {
      footerSummary = _selectedBranch!['name']!;
    }

    if (_currentStep >= 1) {
      if (_selectedDate != null && _selectedTime != null) {
        footerSummary += ' | $_selectedTime, ${_selectedDate!.day}/${_selectedDate!.month}';
      }
      if (_selectedStylist != null) {
        footerSummary += ' (${_selectedStylist!['name']})';
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Đã chọn:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(
                  footerSummary,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          ElevatedButton(
            onPressed: _handleNextAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _currentStep == 2 ? 'Book Now' : 'Tiếp tục', // <--- THAY ĐỔI CHỮ NÚT Ở BƯỚC 3
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}