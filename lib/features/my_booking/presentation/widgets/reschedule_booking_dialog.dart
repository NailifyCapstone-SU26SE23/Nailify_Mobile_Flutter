import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class RescheduleBookingDialog extends StatefulWidget {
  final String bookingId;
  final Future<bool> Function(String newDate, String newTime, String reason)
  onConfirm;

  const RescheduleBookingDialog({
    super.key,
    required this.bookingId,
    required this.onConfirm,
  });

  /// Phương thức hiển thị Modal với hiệu ứng Pop-up (Scale & Fade) siêu mượt mà
  static Future<bool?> show({
    required BuildContext context,
    required String bookingId,
    required Future<bool> Function(
      String newDate,
      String newTime,
      String reason,
    )
    onConfirm,
  }) {
    return showGeneralDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'RescheduleBookingDialog',
      barrierColor: Colors.black.withValues(alpha: 0.54),
      transitionDuration: const Duration(milliseconds: 280),
      pageBuilder: (ctx, anim1, anim2) =>
          RescheduleBookingDialog(bookingId: bookingId, onConfirm: onConfirm),
      transitionBuilder: (ctx, anim1, anim2, child) {
        final curve = CurvedAnimation(
          parent: anim1,
          curve: Curves.easeOutCubic,
        );
        return ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(curve),
          child: FadeTransition(opacity: anim1, child: child),
        );
      },
    );
  }

  @override
  State<RescheduleBookingDialog> createState() =>
      _RescheduleBookingDialogState();
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
      return [
        "08:00",
        "08:30",
        "09:00",
        "09:30",
        "10:00",
        "10:30",
        "11:00",
        "11:30",
      ];
    } else if (period == 'Chiều') {
      return [
        "13:00",
        "13:30",
        "14:00",
        "14:30",
        "15:00",
        "15:30",
        "16:00",
        "16:30",
        "17:00",
        "17:30",
      ];
    } else {
      return ["18:00", "18:30", "19:00", "19:30", "20:00"];
    }
  }

  void _setPeriod(String period) {
    setState(() {
      _selectedPeriod = period;
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
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            gradient: isSelected ? AppColors.quizGradient : null,
            color: isSelected ? null : const Color(0xFFF2F2F7),
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
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
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
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
        ? 'Chọn ngày hẹn mới'
        : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}';

    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.85;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header (Cố định ở trên với thiết kế hiện đại)
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: AppColors.quizGradient,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit_calendar_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text(
                            'Yêu cầu dời lịch hẹn',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryDark,
                              letterSpacing: -0.3,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Thay đổi thời gian tiện hơn cho bạn',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF2F2F7),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close_rounded,
                          color: AppColors.textSecondary,
                          size: 18,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF0F0F3)),
                const SizedBox(height: 16),

                // Nội dung cuộn linh hoạt
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Picker Ngày
                        Row(
                          children: const [
                            Icon(
                              Icons.calendar_month_rounded,
                              size: 16,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Ngày hẹn mới',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () => _selectDate(context),
                          borderRadius: BorderRadius.circular(16),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            decoration: BoxDecoration(
                              color: _selectedDate != null
                                  ? AppColors.primarySurface
                                  : const Color(0xFFF7F7FA),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _selectedDate != null
                                    ? AppColors.primary.withValues(alpha: 0.4)
                                    : const Color(0xFFE5E5EA),
                                width: _selectedDate != null ? 1.5 : 1.0,
                              ),
                              boxShadow: _selectedDate != null
                                  ? [
                                      BoxShadow(
                                        color: AppColors.primary.withValues(
                                          alpha: 0.08,
                                        ),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.event_available_rounded,
                                  color: _selectedDate != null
                                      ? AppColors.primary
                                      : AppColors.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Text(
                                  dateText,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: _selectedDate == null
                                        ? FontWeight.normal
                                        : FontWeight.bold,
                                    color: _selectedDate == null
                                        ? AppColors.textSecondary
                                        : AppColors.primaryDark,
                                  ),
                                ),
                                const Spacer(),
                                if (_selectedDate != null)
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.primary.withValues(
                                        alpha: 0.15,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      'Đã chọn',
                                      style: TextStyle(
                                        color: AppColors.primaryDark,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.arrow_forward_ios_rounded,
                                    color: AppColors.textSecondary,
                                    size: 14,
                                  ),
                              ],
                            ),
                          ),
                        ),

                        // Mở rộng mượt mà khi chọn ngày hẹn mới
                        AnimatedSize(
                          duration: const Duration(milliseconds: 300),
                          curve: Curves.easeOutCubic,
                          child: _selectedDate == null
                              ? const SizedBox.shrink()
                              : Column(
                                  key: const ValueKey('time_slots_section'),
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 20),
                                    Row(
                                      children: const [
                                        Icon(
                                          Icons.access_time_filled_rounded,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                        SizedBox(width: 6),
                                        Text(
                                          'Chọn khung giờ mới',
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: AppColors.textPrimary,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 10),

                                    // Tabs chọn buổi: Sáng / Chiều / Tối
                                    Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF2F2F7),
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                      child: Row(
                                        children: [
                                          _buildPeriodTab(
                                            'Sáng',
                                            Icons.wb_sunny_rounded,
                                          ),
                                          const SizedBox(width: 4),
                                          _buildPeriodTab(
                                            'Chiều',
                                            Icons.wb_twilight_rounded,
                                          ),
                                          const SizedBox(width: 4),
                                          _buildPeriodTab(
                                            'Tối',
                                            Icons.nightlight_round,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 12),

                                    // Slots giờ (Chuyển tab mượt mà với AnimatedSwitcher)
                                    AnimatedSwitcher(
                                      duration: const Duration(
                                        milliseconds: 220,
                                      ),
                                      switchInCurve: Curves.easeOutCubic,
                                      switchOutCurve: Curves.easeInCubic,
                                      transitionBuilder: (child, animation) {
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: Tween<Offset>(
                                              begin: const Offset(0, 0.04),
                                              end: Offset.zero,
                                            ).animate(animation),
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: LayoutBuilder(
                                        key: ValueKey(_selectedPeriod),
                                        builder: (context, constraints) {
                                          final itemWidth =
                                              (constraints.maxWidth - 24) / 4;
                                          final slots = _getSlotsForPeriod(
                                            _selectedPeriod,
                                          );
                                          return Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: slots.map((slot) {
                                              final isSelected =
                                                  _selectedTimeStr == slot;
                                              return InkWell(
                                                onTap: () {
                                                  setState(() {
                                                    _selectedTimeStr = slot;
                                                  });
                                                },
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                                child: AnimatedScale(
                                                  scale: isSelected
                                                      ? 1.02
                                                      : 1.0,
                                                  duration: const Duration(
                                                    milliseconds: 150,
                                                  ),
                                                  curve: Curves.easeOutBack,
                                                  child: AnimatedContainer(
                                                    duration: const Duration(
                                                      milliseconds: 180,
                                                    ),
                                                    width: itemWidth,
                                                    height: 42,
                                                    decoration: BoxDecoration(
                                                      gradient: isSelected
                                                          ? AppColors
                                                                .quizGradient
                                                          : null,
                                                      color: isSelected
                                                          ? null
                                                          : const Color(
                                                              0xFFF7F7FA,
                                                            ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            12,
                                                          ),
                                                      border: Border.all(
                                                        color: isSelected
                                                            ? Colors.transparent
                                                            : const Color(
                                                                0xFFE5E5EA,
                                                              ),
                                                        width: 1.0,
                                                      ),
                                                      boxShadow: isSelected
                                                          ? [
                                                              BoxShadow(
                                                                color: AppColors
                                                                    .primary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.35,
                                                                    ),
                                                                blurRadius: 8,
                                                                offset:
                                                                    const Offset(
                                                                      0,
                                                                      3,
                                                                    ),
                                                              ),
                                                            ]
                                                          : null,
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        slot,
                                                        style: TextStyle(
                                                          color: isSelected
                                                              ? Colors.white
                                                              : AppColors
                                                                    .textPrimary,
                                                          fontWeight: isSelected
                                                              ? FontWeight.bold
                                                              : FontWeight.w500,
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                              );
                                            }).toList(),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 20),

                        // Lý do dời lịch
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: const [
                                Icon(
                                  Icons.edit_note_rounded,
                                  size: 18,
                                  color: AppColors.primary,
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Lý do dời lịch',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                            ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _reasonController,
                              builder: (context, value, child) {
                                final count = _countWords(value.text);
                                return Text(
                                  '$count/50 từ',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                    color: count > 50
                                        ? AppColors.error
                                        : AppColors.textSecondary,
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _reasonController,
                          maxLines: 3,
                          scrollPadding: EdgeInsets.only(
                            bottom: mediaQuery.viewInsets.bottom + 80,
                          ),
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppColors.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText:
                                'Nhập lý do dời lịch (ví dụ: bận việc đột xuất)...',
                            hintStyle: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            filled: true,
                            fillColor: const Color(0xFFF7F7FA),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E5EA),
                              ),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: Color(0xFFE5E5EA),
                              ),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(16),
                              borderSide: const BorderSide(
                                color: AppColors.primary,
                                width: 1.5,
                              ),
                            ),
                            contentPadding: const EdgeInsets.all(14),
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
                        const SizedBox(height: 16),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                const Divider(height: 1, color: Color(0xFFF0F0F3)),
                const SizedBox(height: 14),

                // Nút hành động cố định ở đáy Dialog
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: const BorderSide(
                            color: Color(0xFFE0E0E0),
                            width: 1.2,
                          ),
                        ),
                        onPressed: _isSubmitting
                            ? null
                            : () => Navigator.of(context).pop(),
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
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: AppColors.quizGradient,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.35),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.transparent,
                            shadowColor: Colors.transparent,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                          onPressed: _isSubmitting
                              ? null
                              : () async {
                                  if (_selectedDate == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Vui lòng chọn ngày hẹn mới',
                                        ),
                                      ),
                                    );
                                    return;
                                  }
                                  if (_selectedTimeStr == null) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Vui lòng chọn khung giờ hẹn mới',
                                        ),
                                      ),
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
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: _isSubmitting
                                ? const SizedBox(
                                    key: ValueKey('loading'),
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : Row(
                                    key: const ValueKey('submit_text'),
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: const [
                                      Text(
                                        'Gửi yêu cầu',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                      SizedBox(width: 6),
                                      Icon(
                                        Icons.send_rounded,
                                        color: Colors.white,
                                        size: 16,
                                      ),
                                    ],
                                  ),
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
