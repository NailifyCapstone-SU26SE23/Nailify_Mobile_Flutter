import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class BookingTimeSelection extends StatelessWidget {
  final List<dynamic> timeSlots;
  final bool isLoading;
  final String? selectedTime;
  final bool canSelect;
  final Function(String) onTimeChanged;

  const BookingTimeSelection({
    super.key,
    required this.timeSlots,
    required this.isLoading,
    required this.selectedTime,
    required this.canSelect,
    required this.onTimeChanged
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Khung giờ rảnh', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        if (!canSelect)
          const Text('Vui lòng chọn Thợ để xem giờ rảnh.', style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic))
        else if (isLoading)
          const CircularProgressIndicator()
        else if (timeSlots.isEmpty)
            const Text('Thợ không có lịch làm việc vào ngày này.')
          else
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3, childAspectRatio: 2.5, crossAxisSpacing: 10, mainAxisSpacing: 10
              ),
              itemCount: timeSlots.length,
              itemBuilder: (context, index) {
                final slot = timeSlots[index];
                final String time = slot['startTime'];
                final bool isAvail = slot['isAvailable'] == true;
                final bool isSelected = selectedTime == time;

                return GestureDetector(
                  // TRẠNG THÁI BẬN (isAvail == false)
                  onTap: isAvail ? () => onTimeChanged(time) : null,
                  child: Container(
                    decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : (isAvail ? Colors.white : Colors.grey.shade100),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: isSelected ? AppColors.primary : (isAvail ? Colors.grey.shade300 : Colors.transparent)
                        )
                    ),
                    alignment: Alignment.center,
                    child: Text(
                        time.substring(0, 5),
                        style: TextStyle(
                          fontWeight: isAvail ? FontWeight.bold : FontWeight.normal,
                          color: isSelected ? Colors.white : (isAvail ? Colors.black : Colors.grey.shade400),
                          decoration: isAvail ? null : TextDecoration.lineThrough,
                        )
                    ),
                  ),
                );
              },
            )
      ],
    );
  }
}