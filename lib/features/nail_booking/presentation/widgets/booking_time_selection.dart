import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class BookingTimeSelection extends StatelessWidget {
  final List<dynamic> timeSlots;
  final bool isLoading;
  final String? selectedTime;
  final bool canSelect;
  final DateTime? selectedDate;
  final Function(String) onTimeChanged;

  const BookingTimeSelection({
    super.key,
    required this.timeSlots,
    required this.isLoading,
    required this.selectedTime,
    required this.canSelect,
    required this.selectedDate,
    required this.onTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Khung giờ rảnh',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Georgia',
            color: AppColors.primaryDark,
          ),
        ),
        const SizedBox(height: 12),
        if (!canSelect)
          Container(
            padding: const EdgeInsets.all(16),
            width: double.infinity,
            decoration: BoxDecoration(
              color: const Color(0xFFFDFBF7),
              border: Border.all(color: const Color(0xFFF3EFEA)),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: Colors.grey, size: 20),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Vui lòng chọn Thợ hoặc tự động phân công để xem giờ rảnh.',
                    style: TextStyle(color: Colors.black54, fontSize: 13, fontStyle: FontStyle.italic),
                  ),
                ),
              ],
            ),
          )
        else if (isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
          )
        else if (timeSlots.isEmpty)
          const Text('Thợ không có lịch làm việc vào ngày này.', style: TextStyle(color: Colors.grey))
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.3,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: timeSlots.length,
            itemBuilder: (context, index) {
              final slot = timeSlots[index];
              final String time = slot['startTime'];
              bool isAvail = slot['isAvailable'] == true;
              final bool isSelected = selectedTime == time;

              if (isAvail && selectedDate != null) {
                final now = DateTime.now();
                final bool isToday = selectedDate!.year == now.year &&
                    selectedDate!.month == now.month &&
                    selectedDate!.day == now.day;

                if (isToday) {
                  final List<String> timeParts = time.split(':');
                  final int slotHour = int.tryParse(timeParts[0]) ?? 0;
                  final int slotMinute = int.tryParse(timeParts[1]) ?? 0;

                  if (slotHour < now.hour || (slotHour == now.hour && slotMinute <= now.minute)) {
                    isAvail = false;
                  }
                }
              }

              return GestureDetector(
                onTap: isAvail ? () => onTimeChanged(time) : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : (isAvail ? Colors.white : Colors.grey.shade100),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : (isAvail ? const Color(0xFFF3EFEA) : Colors.transparent),
                      width: 1.2,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: AppColors.primary.withValues(alpha: 0.25),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            )
                          ]
                        : null,
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 13,
                        color: isSelected ? Colors.white : (isAvail ? AppColors.primary : Colors.grey.shade400),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        time.substring(0, 5),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: isSelected ? Colors.white : (isAvail ? AppColors.textPrimary : Colors.grey.shade400),
                          decoration: isAvail ? null : TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          )
      ],
    );
  }
}
