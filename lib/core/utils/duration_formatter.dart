import 'package:flutter_gen/gen_l10n.dart';

class DurationFormatter {
  /// Format mot so phut (int/double/String) thanh chuoi human-readable.
  /// - Ho tro so am (dang ky tuong lai / loi timezone) -> hien thi gia tri tuyet doi.
  /// - Tren 24 gio -> format ngay.
  /// - Duoi 24 gio -> format gio + phut.
  /// - Duoi 60 phut -> format phut.
  static String format(dynamic minutesRaw, {bool useLocalization = false}) {
    if (minutesRaw == null) return '0 phut';

    int minutes = 0;
    if (minutesRaw is int) {
      minutes = minutesRaw;
    } else if (minutesRaw is String) {
      minutes = int.tryParse(minutesRaw) ?? 0;
    } else if (minutesRaw is double) {
      minutes = minutesRaw.toInt();
    }

    // Handle negative: lay gia tri tuyet doi
    final bool isNegative = minutes < 0;
    if (isNegative) minutes = minutes.abs();

    // Tren 24 gio: hien thi ngay
    if (minutes >= 1440) {
      final int days = minutes ~/ 1440;
      final int remainingMinutes = minutes % 1440;
      if (remainingMinutes == 0) {
        final String base = useLocalization
            ? S.current.durationDays(days)
            : '$days ngay';
        return isNegative ? '-$base' : base;
      }
      final int hours = remainingMinutes ~/ 60;
      final int mins = remainingMinutes % 60;
      if (useLocalization) {
        return isNegative
            ? '-${S.current.durationDaysHours(days, hours)}'
            : S.current.durationDaysHours(days, hours);
      }
      final hoursStr = hours > 0 ? '$hours gio ' : '';
      return isNegative ? '-$days ngay $hoursStr$mins phut' : '$days ngay $hoursStr$mins phut';
    }

    // Duoi 24 gio: hien thi gio + phut
    if (minutes >= 60) {
      final int hours = minutes ~/ 60;
      final int mins = minutes % 60;
      if (mins == 0) {
        final String base =
            useLocalization ? S.current.durationHours(hours) : '$hours gio';
        return isNegative ? '-$base' : base;
      }
      final String base = useLocalization
          ? S.current.durationHoursMinutes(hours, mins)
          : '$hours gio $mins phut';
      return isNegative ? '-$base' : base;
    }

    // Duoi 60 phut: hien thi phut
    final String base =
        useLocalization ? S.current.durationMinutes(minutes) : '$minutes phut';
    return isNegative ? '-$base' : base;
  }

  /// Format mot Duration (tu DateTime.difference) thanh chuoi human-readable.
  /// Tu dong xu ly negative (Duration am -> lay tuyet doi).
  static String formatDiff(Duration diff, {bool useLocalization = false}) {
    final int totalMinutes = diff.inMinutes;
    return format(totalMinutes, useLocalization: useLocalization);
  }
}
