import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class BookingDateSelection extends StatefulWidget {
  final DateTime? selectedDate;
  final Function(DateTime) onDateChanged;

  const BookingDateSelection({
    super.key,
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  State<BookingDateSelection> createState() => _BookingDateSelectionState();
}

class _BookingDateSelectionState extends State<BookingDateSelection> {
  final DateTime _today = DateTime(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );
  late DateTime _currentMonth;

  @override
  void initState() {
    super.initState();
    _currentMonth = DateTime(_today.year, _today.month, 1);
  }

  List<DateTime> _getUpcomingMonths() {
    return List.generate(
      12,
      (index) => DateTime(_today.year, _today.month + index, 1),
    );
  }

  final List<String> _weekDays = ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN'];

  @override
  Widget build(BuildContext context) {
    int daysInMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month + 1,
      0,
    ).day;
    int firstWeekday = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    ).weekday;
    final upcomingMonths = _getUpcomingMonths();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn ngày hẹn',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<DateTime>(
              value: _currentMonth,
              isExpanded: true,
              icon: const Icon(Icons.calendar_month, color: AppColors.primary),
              items: upcomingMonths
                  .map(
                    (monthDate) => DropdownMenuItem(
                      value: monthDate,
                      child: Text(
                        'Tháng ${monthDate.month} năm ${monthDate.year}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                  .toList(),
              onChanged: (newMonth) {
                if (newMonth != null) setState(() => _currentMonth = newMonth);
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: _weekDays
              .map(
                (day) => Expanded(
                  child: Center(
                    child: Text(
                      day,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              )
              .toList(),
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
            if (index < firstWeekday - 1) return const SizedBox.shrink();
            int day = index - firstWeekday + 2;
            DateTime thisDay = DateTime(
              _currentMonth.year,
              _currentMonth.month,
              day,
            );
            bool isSelected =
                widget.selectedDate?.year == thisDay.year &&
                widget.selectedDate?.month == thisDay.month &&
                widget.selectedDate?.day == thisDay.day;
            bool isPastDate = thisDay.isBefore(_today);

            return GestureDetector(
              onTap: isPastDate ? null : () => widget.onDateChanged(thisDay),
              child: Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  border: isSelected
                      ? null
                      : Border.all(
                          color: isPastDate
                              ? Colors.grey.shade100
                              : AppColors.borderLight,
                        ),
                ),
                child: Center(
                  child: Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : (isPastDate
                                ? Colors.grey.shade300
                                : AppColors.textPrimary),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
