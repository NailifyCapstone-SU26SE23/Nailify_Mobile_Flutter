import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n.dart';
import '../../data/models/nail_artist_model.dart';
import 'salon_ui.dart';

class ArtistScheduleSection extends StatefulWidget {
  final List<NailArtistSchedule> schedules;

  const ArtistScheduleSection({super.key, required this.schedules});

  @override
  State<ArtistScheduleSection> createState() => _ArtistScheduleSectionState();
}

class _ArtistScheduleSectionState extends State<ArtistScheduleSection> {
  int _weekOffset = 0;

  DateTime get _currentWeekStart => _startOfWeek(DateTime.now());
  DateTime get _visibleWeekStart =>
      _currentWeekStart.add(Duration(days: _weekOffset * 7));

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final visibleSchedules = _schedulesForWeek(
      widget.schedules,
      _visibleWeekStart,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SalonSectionHeader(
          title: l10n.artistSchedulesTitle,
          icon: Icons.calendar_month_rounded,
        ),
        _WeekPager(
          weekStart: _visibleWeekStart,
          canGoPrevious: _weekOffset > 0,
          canGoNext: _weekOffset < 1,
          onPrevious: () => setState(() => _weekOffset -= 1),
          onNext: () => setState(() => _weekOffset += 1),
        ),
        const SizedBox(height: 10),
        if (visibleSchedules.isEmpty)
          SalonEmptyState(
            icon: Icons.event_busy_rounded,
            title: l10n.noSchedules,
          )
        else
          ...visibleSchedules.map(
            (schedule) => _ScheduleTile(schedule: schedule),
          ),
      ],
    );
  }
}

class _WeekPager extends StatelessWidget {
  final DateTime weekStart;
  final bool canGoPrevious;
  final bool canGoNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _WeekPager({
    required this.weekStart,
    required this.canGoPrevious,
    required this.canGoNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final weekEnd = weekStart.add(const Duration(days: 6));

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: canGoPrevious ? onPrevious : null,
            icon: const Icon(Icons.chevron_left_rounded),
            tooltip: 'Previous week',
          ),
          Expanded(
            child: Text(
              '${_formatDate(weekStart)} - ${_formatDate(weekEnd)}',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          IconButton(
            onPressed: canGoNext ? onNext : null,
            icon: const Icon(Icons.chevron_right_rounded),
            tooltip: 'Next week',
          ),
        ],
      ),
    );
  }
}

class _ScheduleTile extends StatelessWidget {
  final NailArtistSchedule schedule;

  const _ScheduleTile({required this.schedule});

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final date = DateTime.tryParse(schedule.workDate);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.10)),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.calendar_today_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  date == null
                      ? schedule.workDate
                      : '${_weekdayName(l10n, date.weekday)}, ${_formatDate(date)}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  '${_formatTime(schedule.shiftStart)} - ${_formatTime(schedule.shiftEnd)}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

List<NailArtistSchedule> _schedulesForWeek(
  List<NailArtistSchedule> schedules,
  DateTime weekStart,
) {
  final weekEndExclusive = weekStart.add(const Duration(days: 7));
  final visible = schedules.where((schedule) {
    final date = DateTime.tryParse(schedule.workDate);
    if (date == null) return false;
    return !date.isBefore(weekStart) && date.isBefore(weekEndExclusive);
  }).toList();

  visible.sort((a, b) {
    final aDate = DateTime.tryParse(a.workDate);
    final bDate = DateTime.tryParse(b.workDate);
    final dateCompare = (aDate ?? DateTime(0)).compareTo(bDate ?? DateTime(0));
    if (dateCompare != 0) return dateCompare;
    return a.shiftStart.compareTo(b.shiftStart);
  });

  return visible;
}

DateTime _startOfWeek(DateTime date) {
  final normalized = DateTime(date.year, date.month, date.day);
  return normalized.subtract(Duration(days: normalized.weekday - 1));
}

String _weekdayName(S l10n, int weekday) {
  switch (weekday) {
    case DateTime.monday:
      return l10n.weekdayMonday;
    case DateTime.tuesday:
      return l10n.weekdayTuesday;
    case DateTime.wednesday:
      return l10n.weekdayWednesday;
    case DateTime.thursday:
      return l10n.weekdayThursday;
    case DateTime.friday:
      return l10n.weekdayFriday;
    case DateTime.saturday:
      return l10n.weekdaySaturday;
    case DateTime.sunday:
      return l10n.weekdaySunday;
    default:
      return '';
  }
}

String _formatDate(DateTime date) => '${date.day}/${date.month}/${date.year}';

String _formatTime(String value) {
  final parts = value.split(':');
  if (parts.length >= 2) return '${parts[0]}:${parts[1]}';
  return value;
}
