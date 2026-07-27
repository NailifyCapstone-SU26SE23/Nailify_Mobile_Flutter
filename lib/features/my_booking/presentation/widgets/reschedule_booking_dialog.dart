import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class RescheduleBookingDialog extends StatefulWidget {
  final String bookingId;
  final Future<bool> Function(String newDate, String newTime, String reason) onConfirm;

  const RescheduleBookingDialog({
    super.key,
    required this.bookingId,
    required this.onConfirm,
  });

  @override
  State<RescheduleBookingDialog> createState() => _RescheduleBookingDialogState();
}

class _RescheduleBookingDialogState extends State<RescheduleBookingDialog> {
  DateTime? _selectedDate;
  String? _selectedTimeStr;
  String _selectedPeriod = 'Sáng'; // 'Sáng', 'Chiều', 'Tối'
  final TextEditingController _reasonController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isSubmitting = false;

  List<String> _getSlotsForPeriod(String period) {
    if (period == 'Sáng') {
      return ["08:00", "08:30", "09:00", "09:30", "10:00", "10:30", "11:00", "11:30"];
    } else if (period == 'Chiều') {
      return ["13:00", "13:30", "14:00", "14:30", "15:00", "15:30", "16:00", "16:30", "17:00", "17:30"];
    } else {
      return ["18:00", "18:30", "19:00", "19:30", "20:00"];
    }
  }

  void _setPeriod(String period) {
    setState(() {
      _selectedPeriod = period;
      // Reset if selected slot is not in the new period
      final newSlots = _getSlotsForPeriod(period);
      if (_selectedTimeStr != null && !newSlots.contains(_selectedTimeStr)) {
        _selectedTimeStr = null;
      }
    });
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  int _countWords(String text) {
    if (text.trim().isEmpty) return 0;
    return text.trim().split(RegExp(r'\s+')).length;
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now().add(const Duration(days: 1)),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 30)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Widget _buildPeriodTab(String label, IconData icon) {
    final isSelected = _selectedPeriod == label;
    return Expanded(
      child: InkWell(
        onTap: () => _setPeriod(label),
        borderRadius: BorderRadius.circular(30),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : const Color(0xFFF5F5F7),
            borderRadius: BorderRadius.circular(30),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: isSelected ? Colors.white : AppColors.textSecondary,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateText = _selectedDate == null
        ? 'Chọn ngày hẹn'
        : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}';

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Yêu cầu dời lịch hẹn',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: AppColors.textSecondary),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Text(
                  'Vui lòng chọn ngày và khung giờ hẹn mới cùng lý do để chúng tôi sắp xếp lại lịch của bạn.',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Picker Ngày
                const Text(
                  'Ngày hẹn mới',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => _selectDate(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Ink(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.calendar_today_rounded, color: AppColors.primary, size: 20),
                        const SizedBox(width: 12),
                        Text(
                          dateText,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: _selectedDate == null ? FontWeight.normal : FontWeight.bold,
                            color: _selectedDate == null ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                        ),
                        const Spacer(),
                        const Icon(Icons.arrow_forward_ios_rounded, color: Colors.grey, size: 14),
                      ],
                    ),
                  ),
                ),

                // Chỉ hiển thị chọn khung giờ sau khi đã chọn ngày
                if (_selectedDate != null) ...[
                  const SizedBox(height: 20),
                  const Text(
                    'Chọn khung giờ mới',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 12),
                  
                  // Tabs chọn buổi: Sáng / Chiều / Tối
                  Row(
                    children: [
                      _buildPeriodTab('Sáng', Icons.wb_sunny_rounded),
                      const SizedBox(width: 8),
                      _buildPeriodTab('Chiều', Icons.wb_twilight_rounded),
                      const SizedBox(width: 8),
                      _buildPeriodTab('Tối', Icons.nightlight_round),
                    ],
                  ),
                  const SizedBox(height: 14),
                  
                  // Slots giờ theo buổi
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final itemWidth = (constraints.maxWidth - 24) / 4; // 4 cột, 3 khoảng cách 8px
                      final slots = _getSlotsForPeriod(_selectedPeriod);
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: slots.map((slot) {
                          final isSelected = _selectedTimeStr == slot;
                          return InkWell(
                            onTap: () {
                              setState(() {
                                _selectedTimeStr = slot;
                              });
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Ink(
                              width: itemWidth,
                              height: 40,
                              decoration: BoxDecoration(
                                color: isSelected ? AppColors.primary.withValues(alpha: 0.12) : const Color(0xFFF5F5F7),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.transparent,
                                  width: 1.2,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  slot,
                                  style: TextStyle(
                                    color: isSelected ? AppColors.primary : AppColors.textPrimary,
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 20),

                // Lý do dời lịch
                const Text(
                  'Lý do dời lịch',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _reasonController,
                  maxLines: 3,
                  style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                  decoration: InputDecoration(
                    hintText: 'Nhập lý do dời lịch (ví dụ: bận việc đột xuất, tối đa 50 từ)...',
                    hintStyle: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFFF5F5F7),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Vui lòng nhập lý do';
                    }
                    if (_countWords(value) > 50) {
                      return 'Lý do không được vượt quá 50 từ';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 24),

                // Actions
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.2),
                        ),
                        onPressed: _isSubmitting ? null : () => Navigator.of(context).pop(),
                        child: const Text(
                          'Hủy bỏ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          elevation: 0,
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () async {
                                if (_selectedDate == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Vui lòng chọn ngày hẹn mới')),
                                  );
                                  return;
                                }
                                if (_selectedTimeStr == null) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Vui lòng chọn khung giờ hẹn mới')),
                                  );
                                  return;
                                }
                                if (_formKey.currentState!.validate()) {
                                  setState(() {
                                    _isSubmitting = true;
                                  });
                                  try {
                                    final formattedDate = DateTime.utc(
                                      _selectedDate!.year,
                                      _selectedDate!.month,
                                      _selectedDate!.day,
                                      12,
                                      0,
                                      0,
                                    ).toIso8601String();
                                    final success = await widget.onConfirm(
                                      formattedDate,
                                      _selectedTimeStr!,
                                      _reasonController.text.trim(),
                                    );
                                    if (!context.mounted) return;
                                    if (success) {
                                      Navigator.of(context).pop();
                                    }
                                  } finally {
                                    if (mounted) {
                                      setState(() {
                                        _isSubmitting = false;
                                      });
                                    }
                                  }
                                }
                              },
                        child: _isSubmitting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text(
                                'Gửi yêu cầu',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
