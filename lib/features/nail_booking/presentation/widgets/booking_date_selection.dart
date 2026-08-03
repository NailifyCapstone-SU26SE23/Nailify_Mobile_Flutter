import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n.dart';

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
  late int _selectedMonth;
  late int _selectedYear;

  @override
  void initState() {
    super.initState();
    _selectedMonth = _today.month;
    _selectedYear = _today.year;
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  List<String> get _weekDays => Localizations.localeOf(context).languageCode == 'vi'
      ? ['T2', 'T3', 'T4', 'T5', 'T6', 'T7', 'CN']
      : ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context) {
    DateTime currentMonthDate = DateTime(_selectedYear, _selectedMonth, 1);

    int daysInMonth = DateTime(
      currentMonthDate.year,
      currentMonthDate.month + 1,
      0,
    ).day;
    int firstWeekday = DateTime(
      currentMonthDate.year,
      currentMonthDate.month,
      1,
    ).weekday;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context).bookingSelectDateTitle,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            // Dropdown chọn Tháng
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).monthHint,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedMonth,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(16), // Bo góc cho menu popup
                        dropdownColor: Colors.white, // Màu nền trắng đồng bộ
                        elevation: 4, // Độ bóng mịn màng hơn
                        menuMaxHeight: 250, // Giới hạn chiều cao menu để có thể kéo lên xuống mượt mà
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 22),
                        items: List.generate(
                          12 - (_selectedYear == _today.year ? _today.month - 1 : 0),
                          (index) {
                            final month = (_selectedYear == _today.year ? _today.month : 1) + index;
                            return DropdownMenuItem<int>(
                              value: month,
                              child: Text(
                                '$month',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            );
                          },
                        ),
                        onChanged: (newMonth) {
                          if (newMonth != null) {
                            setState(() {
                              _selectedMonth = newMonth;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Dropdown chọn Năm
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).yearHint,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.borderLight),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _selectedYear,
                        isExpanded: true,
                        borderRadius: BorderRadius.circular(16), // Bo góc cho menu popup
                        dropdownColor: Colors.white, // Màu nền trắng đồng bộ
                        elevation: 4, // Độ bóng mịn màng hơn
                        menuMaxHeight: 250, // Giới hạn chiều cao menu để có thể kéo lên xuống mượt mà
                        icon: const Icon(Icons.keyboard_arrow_down_rounded, color: AppColors.primary, size: 22),
                        items: [2026, 2027, 2028, 2029, 2030].map((year) {
                          return DropdownMenuItem<int>(
                            value: year,
                            child: Text(
                              '$year',
                              style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                            ),
                          );
                        }).toList(),
                        onChanged: (newYear) {
                          if (newYear != null && newYear != _selectedYear) {
                            setState(() {
                              _selectedYear = newYear;
                              if (_selectedYear == _today.year) {
                                if (_selectedMonth < _today.month) {
                                  _selectedMonth = _today.month;
                                }
                              } else {
                                _selectedMonth = 1;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
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
              currentMonthDate.year,
              currentMonthDate.month,
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
