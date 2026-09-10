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
          ...groupedHours.map(
            (dayHours) => _OperatingDayCard(dayHours: dayHours),
          ),
      ],
    );
  }
}

class _OperatingDayCard extends StatelessWidget {
  final _OperatingDayHours dayHours;

  const _OperatingDayCard({required this.dayHours});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.calendar_today_rounded,
                  color: AppColors.primary,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  _localizedDayName(l10n, dayHours.primaryHour),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: dayHours.hours
                .map((hour) => _OperatingSegmentChip(hour: hour))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _OperatingSegmentChip extends StatelessWidget {
  final SalonOperatingHour hour;

  const _OperatingSegmentChip({required this.hour});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final isClosed = hour.isClosed;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: isClosed
            ? AppColors.error.withValues(alpha: 0.08)
            : AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isClosed
              ? AppColors.error.withValues(alpha: 0.12)
              : AppColors.primary.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isClosed ? Icons.event_busy_rounded : Icons.access_time_rounded,
            size: 16,
            color: isClosed ? AppColors.error : AppColors.primary,
          ),
          const SizedBox(width: 6),
          Text(
            isClosed
                ? l10n.salonClosed
                : '${_formatTime(hour.openTime)} - ${_formatTime(hour.closeTime)}',
            style: TextStyle(
              color: isClosed ? AppColors.error : AppColors.primaryDark,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
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

String _formatTime(String value) {
  final parts = value.split(':');
  if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
  return value;
}
