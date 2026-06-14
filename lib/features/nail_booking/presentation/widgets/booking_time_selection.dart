import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/booking_mock_data.dart';

class BookingTimeSelection extends StatefulWidget {
  final DateTime? selectedDate;
  final String? selectedTime;
  final Map<String, dynamic>? selectedStylist;
  final Function(String) onTimeChanged;

  const BookingTimeSelection({
    super.key,
    required this.selectedDate,
    required this.selectedTime,
    required this.selectedStylist,
    required this.onTimeChanged,
  });

  @override
  State<BookingTimeSelection> createState() => _BookingTimeSelectionState();
}

class _BookingTimeSelectionState extends State<BookingTimeSelection> {
  bool _isTimeExpanded = false;

  @override
  Widget build(BuildContext context) {
    final timeSlots = BookingMockData.timeSlots;
    // check xem đã đủ điều kiện mở Giờ chưa
    final bool canSelectTime = widget.selectedDate != null && widget.selectedStylist != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () {
            if (!canSelectTime) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Vui lòng chọn Ngày và Kỹ thuật viên trước!')));
              return;
            }
            setState(() => _isTimeExpanded = !_isTimeExpanded);
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            decoration: BoxDecoration(
              color: canSelectTime ? Colors.grey.shade50 : Colors.grey.shade200,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.borderLight),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.access_time, size: 20, color: canSelectTime ? AppColors.primary : Colors.grey),
                    const SizedBox(width: 8),
                    Text(
                      'Khung giờ trống',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: canSelectTime ? AppColors.textPrimary : Colors.grey),
                    ),
                    if (widget.selectedTime != null) ...[
                      const SizedBox(width: 8),
                      Text('(${widget.selectedTime})', style: const TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.bold))
                    ]
                  ],
                ),
                Icon(_isTimeExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: canSelectTime ? AppColors.primary : Colors.grey, size: 24),
              ],
            ),
          ),
        ),

        if (_isTimeExpanded && canSelectTime) ...[
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 2.5,
            ),
            itemCount: timeSlots.length,
            itemBuilder: (context, index) {
              final time = timeSlots[index];
              bool isSelected = widget.selectedTime == time;
              bool isBusy = false;

              final busySchedules = widget.selectedStylist!['busySchedules'] as Map<int, List<String>>?;
              if (busySchedules != null && busySchedules.containsKey(widget.selectedDate!.day)) {
                if (busySchedules[widget.selectedDate!.day]!.contains(time) || busySchedules[widget.selectedDate!.day]!.contains('all')) {
                  isBusy = true;
                }
              }

              return GestureDetector(
                onTap: isBusy ? null : () {
                  widget.onTimeChanged(time);
                  setState(() => _isTimeExpanded = false); // false: tự đóng tab sau khi chọn, true: giữ nguyên tab
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : (isBusy ? Colors.grey.shade50 : Colors.white),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: isSelected ? AppColors.primary : (isBusy ? Colors.grey.shade200 : AppColors.borderLight), width: isSelected ? 1.5 : 1),
                    boxShadow: isSelected ? [BoxShadow(color: AppColors.primary.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))] : null,
                  ),
                  child: Center(
                    child: Text(
                      time,
                      style: TextStyle(fontSize: 14, fontWeight: isSelected ? FontWeight.bold : FontWeight.w500, color: isSelected ? Colors.white : (isBusy ? Colors.grey.shade400 : AppColors.textPrimary), decoration: isBusy ? TextDecoration.lineThrough : null),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ],
    );
  }
}