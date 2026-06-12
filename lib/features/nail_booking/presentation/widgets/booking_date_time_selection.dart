// lib/features/booking/presentation/widgets/booking_date_time_selection.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/booking_mock_data.dart';

class BookingDateTimeSelection extends StatefulWidget {
  final DateTime? selectedDate;
  final String? selectedTime;
  final Function(DateTime) onDateChanged;
  final Function(String) onTimeChanged;

  const BookingDateTimeSelection({
    super.key,
    required this.selectedDate,
    required this.selectedTime,
    required this.onDateChanged,
    required this.onTimeChanged,
  });

  @override
  State<BookingDateTimeSelection> createState() => _BookingDateTimeSelectionState();
}

class _BookingDateTimeSelectionState extends State<BookingDateTimeSelection> {
  late DateTime _currentMonth;
  late DateTime _today;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    // Khởi tạo ngày hôm nay ở mốc thời gian gốc để so sánh chuẩn xác theo ngày ngày/tháng/năm
    _today = DateTime(now.year, now.month, now.day);
    // Tự động khởi tạo lịch ở tháng hiện tại của hệ thống thay vì gán cứng
    _currentMonth = DateTime(now.year, now.month, 1);
  }

  void _previousMonth() {
    final targetMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    // CHỐT CHẶN 1: Không cho phép lùi về trước tháng hiện tại của hệ thống
    final currentSystemMonth = DateTime(_today.year, _today.month, 1);
    if (targetMonth.isBefore(currentSystemMonth)) return;

    setState(() {
      _currentMonth = targetMonth;
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
    });
  }

  final List<String> _weekDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    final timeSlots = BookingMockData.timeSlots;

    int daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;
    int firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday;

    // Kiểm tra trạng thái để vô hiệu hóa UI của nút lùi tháng nếu đã chạm mốc tháng hiện tại
    final currentSystemMonth = DateTime(_today.year, _today.month, 1);
    final targetPrevMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
    bool canGoToPreviousMonth = !targetPrevMonth.isBefore(currentSystemMonth);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ==========================================
        // 1. HEADER CHỌN THÁNG VÀ NÚT ĐIỀU HƯỚNG
        // ==========================================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Tháng ${_currentMonth.month} ${_currentMonth.year}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: canGoToPreviousMonth ? _previousMonth : null,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: canGoToPreviousMonth ? AppColors.borderLight : Colors.grey.shade200,
                      ),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.chevron_left,
                      size: 20,
                      color: canGoToPreviousMonth ? AppColors.textPrimary : Colors.grey.shade300,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: _nextMonth,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.borderLight),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.chevron_right, size: 20, color: AppColors.textPrimary),
                  ),
                ),
              ],
            )
          ],
        ),
        const SizedBox(height: 24),

        // ==========================================
        // 2. LỊCH CHỌN NGÀY TRONG THÁNG
        // ==========================================
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _weekDays.map((day) {
            return Expanded(
              child: Center(
                child: Text(
                  day,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),

        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisSpacing: 12,
            crossAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: daysInMonth + firstWeekday - 1,
          itemBuilder: (context, index) {
            if (index < firstWeekday - 1) {
              return const SizedBox.shrink();
            }

            int day = index - firstWeekday + 2;
            DateTime thisDay = DateTime(_currentMonth.year, _currentMonth.month, day);

            bool isSelected = widget.selectedDate?.year == thisDay.year &&
                widget.selectedDate?.month == thisDay.month &&
                widget.selectedDate?.day == thisDay.day;

            // CHỐT CHẶN 2: Nếu ngày này nằm trước ngày hôm nay của hệ thống -> Xem như ngày cũ (Quá khứ)
            bool isPastDate = thisDay.isBefore(_today);

            return GestureDetector(
              onTap: isPastDate ? null : () => widget.onDateChanged(thisDay), // Khóa hoàn toàn click hành động nếu thuộc về quá khứ
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  border: isSelected
                      ? null
                      : Border.all(color: isPastDate ? Colors.grey.shade100 : AppColors.borderLight),
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      // Đổi màu xám mờ (disable style) nếu là ngày cũ
                      color: isSelected
                          ? Colors.white
                          : (isPastDate ? Colors.grey.shade300 : AppColors.textPrimary),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 32),

        // ==========================================
        // 3. CUỘN NGANG KHUNG GIỜ
        // ==========================================
        const Text(
          'Khung giờ trống',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: timeSlots.map((time) {
              bool isSelected = widget.selectedTime == time;
              return GestureDetector(
                onTap: () => widget.onTimeChanged(time),
                child: Container(
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.borderLight,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Text(
                    time,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}