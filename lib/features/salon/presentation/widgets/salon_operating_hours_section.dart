import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n.dart';
import '../../data/models/salon_model.dart';
import 'salon_ui.dart';

class SalonOperatingHoursSection extends StatelessWidget {
  final List<SalonOperatingHour> operatingHours;

  const SalonOperatingHoursSection({super.key, required this.operatingHours});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final groupedHours = _groupByDay(operatingHours);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SalonSectionHeader(
          title: l10n.salonOperatingHoursTitle,
          icon: Icons.schedule_rounded,
        ),
        if (groupedHours.isEmpty)
          SalonEmptyState(
            icon: Icons.schedule_rounded,
            title: l10n.noOperatingHours,
          )
        else
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFF0EAE1), width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                for (int i = 0; i < groupedHours.length; i++) ...[
                  _OperatingDayRow(
                    dayHours: groupedHours[i],
                    isLast: i == groupedHours.length - 1,
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _OperatingDayRow extends StatelessWidget {
  final _OperatingDayHours dayHours;
  final bool isLast;

  const _OperatingDayRow({required this.dayHours, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final primary = dayHours.primaryHour;
    final dayName = _localizedDayName(l10n, primary);
    final todayWeekday = DateTime.now().weekday;
    final isToday = _daySortIndex(dayHours.dayOfWeek) == todayWeekday;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isToday
                ? AppColors.primary.withValues(alpha: 0.05)
                : Colors.transparent,
            borderRadius: isToday ? BorderRadius.circular(12) : null,
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: isToday
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.grey.shade100,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isToday ? Icons.stars_rounded : Icons.calendar_today_rounded,
                  size: 14,
                  color: isToday ? AppColors.primary : Colors.grey.shade600,
                ),
              ),
              const SizedBox(width: 10),
              Text(
                dayName,
                style: TextStyle(
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  color: isToday ? AppColors.primary : AppColors.textPrimary,
                  fontSize: 14,
                ),
              ),
              if (isToday) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Text(
                    'Hôm nay',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: dayHours.hours.map((hour) {
                  final isClosed = hour.isClosed;
                  return Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: isClosed
                          ? AppColors.error.withValues(alpha: 0.08)
                          : isToday
                          ? AppColors.primary.withValues(alpha: 0.1)
                          : const Color(0xFFF7F5F2),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isClosed
                            ? AppColors.error.withValues(alpha: 0.2)
                            : isToday
                            ? AppColors.primary.withValues(alpha: 0.3)
                            : const Color(0xFFEFEBE4),
                      ),
                    ),
                    child: Text(
                      isClosed
                          ? l10n.salonClosed
                          : '${_formatTime(hour.openTime)} - ${_formatTime(hour.closeTime)}',
                      style: TextStyle(
                        color: isClosed
                            ? AppColors.error
                            : isToday
                            ? AppColors.primary
                            : AppColors.textPrimary,
                        fontSize: 12,
                        fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            indent: 16,
            endIndent: 16,
            color: Colors.grey.shade100,
          ),
      ],
    );
  }
}

class _OperatingDayHours {
  final int dayOfWeek;
  final List<SalonOperatingHour> hours;

  const _OperatingDayHours({required this.dayOfWeek, required this.hours});

  SalonOperatingHour get primaryHour => hours.first;
}

List<_OperatingDayHours> _groupByDay(List<SalonOperatingHour> hours) {
  final grouped = <int, List<SalonOperatingHour>>{};

  for (final hour in hours) {
    grouped.putIfAbsent(hour.dayOfWeek, () => []).add(hour);
  }

  final days = grouped.entries
      .map(
        (entry) => _OperatingDayHours(
          dayOfWeek: entry.key,
          hours: entry.value..sort((a, b) => a.openTime.compareTo(b.openTime)),
        ),
      )
      .toList();

  days.sort(
    (a, b) => _daySortIndex(a.dayOfWeek).compareTo(_daySortIndex(b.dayOfWeek)),
  );
  return days;
}

int _daySortIndex(int dayOfWeek) => dayOfWeek == 0 ? 7 : dayOfWeek;

String _localizedDayName(S l10n, SalonOperatingHour hour) {
  switch (hour.dayName.trim().toLowerCase()) {
    case 'monday':
      return l10n.weekdayMonday;
    case 'tuesday':
      return l10n.weekdayTuesday;
    case 'wednesday':
      return l10n.weekdayWednesday;
    case 'thursday':
      return l10n.weekdayThursday;
    case 'friday':
      return l10n.weekdayFriday;
    case 'saturday':
      return l10n.weekdaySaturday;
    case 'sunday':
      return l10n.weekdaySunday;
  }

  switch (hour.dayOfWeek) {
    case 1:
      return l10n.weekdayMonday;
    case 2:
      return l10n.weekdayTuesday;
    case 3:
      return l10n.weekdayWednesday;
    case 4:
      return l10n.weekdayThursday;
    case 5:
      return l10n.weekdayFriday;
    case 6:
      return l10n.weekdaySaturday;
    case 0:
    case 7:
      return l10n.weekdaySunday;
    default:
      return hour.dayName;
  }
}

String _formatTime(String rawTime) {
  final parts = rawTime.split(':');
  if (parts.length >= 2) {
    final hour = parts[0].padLeft(2, '0');
    final minute = parts[1].padLeft(2, '0');
    return '$hour:$minute';
  }
  return rawTime;
}
