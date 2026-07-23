import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/shape_selection_grid.dart';
import '../widgets/length_slider.dart';
import '../widgets/color_selection_grid.dart';
import '../widgets/pattern_selection_grid.dart';
import '../widgets/accessory_selection_grid.dart';
import '../widgets/summary_preview.dart';
import '../widgets/summary_notes.dart';
import '../widgets/summary_details_price.dart';
import '../../data/models/custom_nail_model.dart';
import '../../data/models/custom_nail_mock_data.dart';
import 'package:go_router/go_router.dart';

class CustomNailStepperPage extends StatefulWidget {
  final Map<String, dynamic>? recommendedData;

  const CustomNailStepperPage({super.key, this.recommendedData});

  @override
  State<CustomNailStepperPage> createState() => _CustomNailStepperPageState();
}

class _CustomNailStepperPageState extends State<CustomNailStepperPage> {
  final CustomNailModel _nailDesign = CustomNailModel();
  final PageController _pageController = PageController();
  final TextEditingController _notesController = TextEditingController();
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    _prefillRecommendedData();
  }

  String _findClosestColorName(String hexStr) {
    final cleanHex = hexStr.replaceAll('#', '').toUpperCase().trim();
    if (cleanHex.length != 6) return 'Soft Pink'; // Default fallback

    try {
      final r = int.parse(cleanHex.substring(0, 2), radix: 16);
      final g = int.parse(cleanHex.substring(2, 4), radix: 16);
      final b = int.parse(cleanHex.substring(4, 6), radix: 16);

      String closestName = 'Soft Pink';
      double minDistance = double.maxFinite;

      CustomNailMockData.colorPalettes.forEach((category, list) {
        for (final item in list) {
          final Color colorVal = item['color'];
          final dr = r - (colorVal.r * 255).round();
          final dg = g - (colorVal.g * 255).round();
          final db = b - (colorVal.b * 255).round();
          final distance = (dr * dr + dg * dg + db * db).toDouble();
          if (distance < minDistance) {
            minDistance = distance;
            closestName = item['name'];
          }
        }
      });

      return closestName;
    } catch (_) {
      return 'Soft Pink';
    }
  }

  void _prefillRecommendedData() {
    if (widget.recommendedData != null) {
      final data = widget.recommendedData!;

      // Pre-fill shape: Match by name containment (e.g. Almond)
      if (data['nailShape'] != null && data['nailShape']['name'] != null) {
        final shapeName = data['nailShape']['name'].toString().toLowerCase();
        final matched = CustomNailMockData.shapes.firstWhere(
          (s) => s.toLowerCase().contains(shapeName) || shapeName.contains(s.toLowerCase()),
          orElse: () => CustomNailMockData.shapes.first,
        );
        _nailDesign.selectedShape = matched;
      }

      // Pre-fill colors: Map API HEX code to the closest named color in custom_nail_mock_data
      if (data['colors'] != null && (data['colors'] as List).isNotEmpty) {
        final hex = (data['colors'] as List).first.toString();
        final colorName = _findClosestColorName(hex);
        _nailDesign.globalConfig.color = colorName;
        for (final key in _nailDesign.fingerConfigs.keys) {
          _nailDesign.fingerConfigs[key]!.color = colorName;
        }
      }

      // Pre-fill pattern / surface: Match by name containment
      if (data['nailSurface'] != null && data['nailSurface']['name'] != null) {
        final surfaceName = data['nailSurface']['name'].toString().toLowerCase();
        final matchedPattern = CustomNailMockData.patterns.firstWhere(
          (p) => p['name']!.toLowerCase().contains(surfaceName) || surfaceName.contains(p['name']!.toLowerCase()),
          orElse: () => CustomNailMockData.patterns.first,
        );
        final finalPatternName = matchedPattern['name']!;
        _nailDesign.globalConfig.pattern = finalPatternName;
        for (final key in _nailDesign.fingerConfigs.keys) {
          _nailDesign.fingerConfigs[key]!.pattern = finalPatternName;
        }
      }

      // Pre-fill accessories: Match by component name containment
      if (data['components'] != null) {
        final List<String> accNames = [];
        final componentsList = data['components'] as List;
        for (final comp in componentsList) {
          final compName = comp['name']?.toString().toLowerCase() ?? '';
          if (compName.isEmpty) continue;
          
          final matchedAcc = CustomNailMockData.accessories.firstWhere(
            (acc) {
              final accName = acc['name']!.toLowerCase();
              return accName.contains(compName) || compName.contains(accName);
            },
            orElse: () => <String, String>{},
          );
          
          if (matchedAcc.isNotEmpty) {
            final accName = matchedAcc['name']!;
            if (!accNames.contains(accName)) {
              accNames.add(accName);
            }
          }
        }
        
        // If no match succeeded, default to at least one accessory
        if (accNames.isEmpty && CustomNailMockData.accessories.isNotEmpty) {
          accNames.add(CustomNailMockData.accessories.first['name']!);
        }

        _nailDesign.globalConfig.accessories = accNames;
        for (final key in _nailDesign.fingerConfigs.keys) {
          _nailDesign.fingerConfigs[key]!.accessories = List.from(accNames);
        }
      }
    }
  }

  // Biến lưu trữ ngón tay đang được chọn để tùy chỉnh (nếu isApplyAll == false)
  String _selectedFinger = 'Ngón cái';
  final List<String> _fingers = [
    'Ngón cái',
    'Ngón trỏ',
    'Ngón giữa',
    'Ngón áp út',
    'Ngón út',
  ];

  @override
  void dispose() {
    _pageController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  void _handleBackAction() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (context.canPop()) {
        // Mở qua push button (Có lịch sử) -> Lùi về trang trước
        context.pop();
      } else {
        // Mở qua footer (Không có lịch sử) -> Trở về trang chủ, chống Crash đen màn hình
        context.go('/');
      }
    }
  }

  void _handleNextAction() {
    if (_currentStep < 4) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
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
        content: Text(
          'Mẫu thiết kế móng (${_nailDesign.selectedShape}) đã được tạo thành công!',
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.pop();
              context.go('/my-studio');
            },
            child: const Text(
              'Quay về My Studio',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // --- WIDGET CHUYỂN ĐỔI CHẾ ĐỘ (APPLY ALL vs CUSTOM FINGERS) ---
  Widget _buildModeToggle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _nailDesign.isApplyAll = true),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: _nailDesign.isApplyAll
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: _nailDesign.isApplyAll
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              ),
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Áp dụng tất cả',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: _nailDesign.isApplyAll
                            ? AppColors.primary
                            : Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _nailDesign.isApplyAll = false),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: !_nailDesign.isApplyAll
                          ? Colors.white
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: !_nailDesign.isApplyAll
                          ? [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.05),
                                blurRadius: 4,
                              ),
                            ]
                          : [],
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      'Tùy chỉnh từng ngón',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: !_nailDesign.isApplyAll
                            ? AppColors.primary
                            : Colors.grey.shade600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),

        // Nếu chọn tùy chỉnh từng ngón, hiển thị thanh cuộn chọn ngón tay
        if (!_nailDesign.isApplyAll) ...[
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: _fingers.map((finger) {
                bool isSelected = _selectedFinger == finger;
                return Padding(
                  padding: const EdgeInsets.only(right: 8.0),
                  child: ChoiceChip(
                    label: Text(finger),
                    selected: isSelected,
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : Colors.grey.shade600,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : Colors.grey.shade300,
                    ),
                    onSelected: (selected) {
                      if (selected) setState(() => _selectedFinger = finger);
                    },
                  ),
                );
              }).toList(),
            ),
          ),
        ],
        const SizedBox(height: 20),
      ],
    );
  }

  // Tiện ích lấy Cấu hình hiện tại đang active
  FingerConfig get _activeConfig => _nailDesign.isApplyAll
      ? _nailDesign.globalConfig
      : _nailDesign.fingerConfigs[_selectedFinger]!;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // canPop: _currentStep == 0,
      // onPopInvokedWithResult: (didPop, result) { if (didPop) return; _handleBackAction(); },
      canPop: false, // Bắt buộc false để chặn hệ thống tự động thoát
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackAction();
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
              size: 20,
              color: AppColors.textPrimary,
            ),
            onPressed: _handleBackAction,
          ),
          title: const Text(
            'Custom Nail',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
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
                  // BƯỚC 1: SHAPE & LENGTH (Global - Không bị ảnh hưởng bởi Toggle)
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '1. Select Nail Shape',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        ShapeSelectionGrid(
                          selectedShape: _nailDesign.selectedShape,
                          onChanged: (val) =>
                              setState(() => _nailDesign.selectedShape = val),
                        ),
                        const SizedBox(height: 40),
                        const Text(
                          '2. Select Nail Length',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 30),
                        LengthSlider(
                          currentValue: _nailDesign.lengthValue,
                          onChanged: (val) =>
                              setState(() => _nailDesign.lengthValue = val),
                          label: _nailDesign.lengthText,
                        ),
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
                        const Text(
                          '3. Select Nail Color',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildModeToggle(), // Gọi thanh điều hướng
                        ColorSelectionGrid(
                          selectedColor: _activeConfig.color,
                          onChanged: (color) =>
                              setState(() => _activeConfig.color = color),
                        ),
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
                        const Text(
                          '3. Select pattern & design',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildModeToggle(), // Gọi thanh điều hướng
                        PatternSelectionGrid(
                          selectedPattern: _activeConfig.pattern,
                          onChanged: (pattern) =>
                              setState(() => _activeConfig.pattern = pattern),
                        ),
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
                        const Text(
                          '4. Select accessory',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildModeToggle(), // Gọi thanh điều hướng
                        AccessorySelectionGrid(
                          selectedAccessories: _activeConfig.accessories,
                          onToggle: (accessory) {
                            setState(() {
                              if (_activeConfig.accessories.contains(
                                accessory,
                              )) {
                                _activeConfig.accessories.remove(accessory);
                              } else {
                                _activeConfig.accessories.add(accessory);
                              }
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  // BƯỚC 5: SUMMARY & CONFIRMATION
                  SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          '5. Review Your Design',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        const SummaryPreview(),
                        const SizedBox(height: 24),
                        SummaryNotes(controller: _notesController),
                        const SizedBox(height: 24),
                        SummaryDetailsPrice(
                          nailDesign: _nailDesign,
                        ), // Truyền Model mới sang Widget Summary
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
                backgroundColor: isCompleted
                    ? AppColors.primary
                    : Colors.grey.shade300,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              if (index < 4)
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
    String summaryText =
        '${_nailDesign.selectedShape} - ${_nailDesign.lengthText}';
    if (_currentStep >= 1) {
      summaryText += _nailDesign.isApplyAll
          ? ' - ${_nailDesign.globalConfig.color}'
          : ' - (Nhiều màu)';
    }
    if (_currentStep >= 2) {
      summaryText += _nailDesign.isApplyAll
          ? ' - ${_nailDesign.globalConfig.pattern}'
          : ' - (Nhiều họa tiết)';
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Your Design:',
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  summaryText,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              _currentStep == 4 ? 'Tạo' : 'Next Step',
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
