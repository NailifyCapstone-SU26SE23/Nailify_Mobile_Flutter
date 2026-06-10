import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/shape_selection_grid.dart';
import '../widgets/length_slider.dart';
import '../widgets/color_selection_grid.dart';
import '../widgets/pattern_selection_grid.dart';
import '../widgets/accessory_selection_grid.dart';
import '../widgets/summary_preview.dart';         //Widget 1
import '../widgets/summary_notes.dart';           //Widget 2
import '../widgets/summary_details_price.dart';   //Widget 3
import '../../data/models/custom_nail_model.dart';

class CustomNailStepperPage extends StatefulWidget {
  const CustomNailStepperPage({super.key});

  @override
  State<CustomNailStepperPage> createState() => _CustomNailStepperPageState();
}

class _CustomNailStepperPageState extends State<CustomNailStepperPage> {
  final CustomNailModel _nailDesign = CustomNailModel();
  final PageController _pageController = PageController();
  final TextEditingController _notesController = TextEditingController(); // Quản lý dữ liệu ô nhập note
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _nailDesign.selectedColor = 'Soft Pink';
    _nailDesign.selectedPattern = 'French Tip';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _notesController.dispose();
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
    if (_currentStep < 4) {
      _pageController.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      // XỬ LÝ NÚT BOOK NOW Ở BƯỚC CUỐI CÙNG
      _executeBooking();
    }
  }

  void _executeBooking() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.green),
            SizedBox(width: 8),
            Text('Thành công'),
          ],
        ),
        content: Text('Đơn đặt lịch thiết kế móng (${_nailDesign.selectedShape}) đã được ghi nhận hệ thống thành công!'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop(); // Đóng popup
              // Sẽ làm luồng booking
            },
            child: const Text('Quay về trang chủ', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar(String hint) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: const TextStyle(color: Colors.grey, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: Colors.grey),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(vertical: 0),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
              child: IconButton(icon: const Icon(Icons.tune, color: AppColors.primary), onPressed: () {}),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ActionChip(
              label: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Event ', style: TextStyle(fontSize: 12)), Icon(Icons.keyboard_arrow_down, size: 14)]),
              onPressed: () {},
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
              padding: EdgeInsets.zero,
            ),
            const SizedBox(width: 8),
            ActionChip(
              label: const Row(mainAxisSize: MainAxisSize.min, children: [Text('Filter ', style: TextStyle(fontSize: 12)), Icon(Icons.filter_list, size: 14)]),
              onPressed: () {},
              backgroundColor: Colors.white,
              side: BorderSide(color: Colors.grey.shade300),
              padding: EdgeInsets.zero,
            ),
          ],
        ),
        const SizedBox(height: 16),
      ],
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
          leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.textPrimary), onPressed: _handleBackAction),
          title: const Text('Custom Nail', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
                  // BƯỚC 1: SHAPE & LENGTH
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('1. Select Nail Shape', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ShapeSelectionGrid(selectedShape: _nailDesign.selectedShape, onChanged: (val) => setState(() => _nailDesign.selectedShape = val)),
                        const SizedBox(height: 40),
                        const Text('2. Select Nail Length', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 30),
                        LengthSlider(currentValue: _nailDesign.lengthValue, onChanged: (val) => setState(() => _nailDesign.lengthValue = val), label: _nailDesign.lengthText),
                      ],
                    ),
                  ),

                  // BƯỚC 2: COLOR SELECTION
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('3. Select Nail Color', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        ColorSelectionGrid(selectedColor: _nailDesign.selectedColor, onChanged: (color) => setState(() => _nailDesign.selectedColor = color)),
                      ],
                    ),
                  ),

                  // BƯỚC 3: PATTERN & DESIGN
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('3. Select pattern & design', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildSearchBar('Search pattern, design...'),
                        PatternSelectionGrid(selectedPattern: _nailDesign.selectedPattern, onChanged: (pattern) => setState(() => _nailDesign.selectedPattern = pattern)),
                      ],
                    ),
                  ),

                  // BƯỚC 4: ACCESSORIES
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('4. Select accessory', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        _buildSearchBar('Search accessory...'),
                        AccessorySelectionGrid(
                          selectedAccessories: _nailDesign.accessories,
                          onToggle: (accessory) {
                            setState(() {
                              if (_nailDesign.accessories.contains(accessory)) {
                                _nailDesign.accessories.remove(accessory);
                              } else {
                                _nailDesign.accessories.add(accessory);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // BƯỚC 5: SUMMARY & CONFIRMATION (Trang lắp ráp 3 widget yêu cầu)
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('5. Review Your Design', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 20),

                        // Thành phần 1:  preview mẫu móng
                        const SummaryPreview(),
                        const SizedBox(height: 24),

                        // Thành phần 2: Ô nhập note ghi chú
                        SummaryNotes(controller: _notesController),
                        const SizedBox(height: 24),

                        // Thành phần 3: Liệt kê chi tiết thông số và tổng tiền ước tính
                        SummaryDetailsPrice(nailDesign: _nailDesign),
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
        children: List.generate(5, (index) {
          bool isCompleted = index <= _currentStep;
          return Row(
            children: [
              CircleAvatar(
                radius: 14,
                backgroundColor: isCompleted ? AppColors.primary : Colors.grey.shade300,
                child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontSize: 12)),
              ),
              if (index < 4)
                Container(width: 30, height: 2, color: index < _currentStep ? AppColors.primary : Colors.grey.shade300),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildFooter() {
    String summaryText = '${_nailDesign.selectedShape} - ${_nailDesign.lengthText}';
    if (_currentStep >= 1) summaryText += ' - ${_nailDesign.selectedColor}';
    if (_currentStep >= 2) summaryText += ' - ${_nailDesign.selectedPattern}';
    if (_currentStep >= 3) {
      summaryText += _nailDesign.accessories.isNotEmpty ? ' - ${_nailDesign.accessories.length} Items' : ' - No Accessory';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Your Design:', style: TextStyle(color: Colors.grey, fontSize: 12)),
                Text(
                  summaryText,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          ElevatedButton(
            onPressed: _handleNextAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              _currentStep == 4 ? 'Book Now' : 'Next Step', // Đổi chữ nút hành động sang Book Now tại bước 5
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}