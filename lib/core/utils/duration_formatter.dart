import 'package:flutter/widgets.dart';

/// Format thời gian thành chuỗi human-readable.
///
/// Tiếng Việt (mặc định):
/// - 45   -> "45 phút"
/// - 60   -> "1 giờ"
/// - 75   -> "1 giờ 15 phút"
/// - 85   -> "1 giờ 25 phút"
/// - 90   -> "1 giờ 30 phút"
/// - 100  -> "1 giờ 40 phút"
/// - 120  -> "2 giờ"
/// - 200  -> "3 giờ 20 phút"
/// - 1440 -> "1 ngày"
///
/// Tiếng Anh (khi isEnglish: true hoặc BuildContext có locale 'en'):
/// - 45   -> "45 mins"
/// - 60   -> "1 hour"
/// - 75   -> "1 hour 15 mins"
/// - 85   -> "1 hour 25 mins"
/// - 90   -> "1 hour 30 mins"
/// - 100  -> "1 hour 40 mins"
/// - 120  -> "2 hours"
/// - 200  -> "3 hours 20 mins"
class DurationFormatter {
  static String format(
    dynamic minutesRaw, {
    bool isEnglish = false,
    BuildContext? context,
  }) {
    final bool useEn =
        isEnglish ||
        (context != null &&
            Localizations.localeOf(context).languageCode == 'en');

    if (minutesRaw == null) return useEn ? '0 mins' : '0 phút';

    int minutes = 0;
    if (minutesRaw is int) {
      minutes = minutesRaw;
    } else if (minutesRaw is String) {
      minutes = int.tryParse(minutesRaw) ?? 0;
    } else if (minutesRaw is double) {
      minutes = minutesRaw.toInt();
    }

    final bool isNegative = minutes < 0;
    if (isNegative) minutes = minutes.abs();
    final String sign = isNegative ? '-' : '';

    // Trên 24 giờ: hiển thị ngày
    if (minutes >= 1440) {
      final int days = minutes ~/ 1440;
      final int remainingMinutes = minutes % 1440;
      final String dayUnit = useEn ? (days > 1 ? 'days' : 'day') : 'ngày';
      if (remainingMinutes == 0) {
        return '$sign$days $dayUnit';
      }
      final int hours = remainingMinutes ~/ 60;
      final int mins = remainingMinutes % 60;
      if (useEn) {
        final hoursUnit = hours > 1 ? 'hours' : 'hour';
        final minsUnit = mins > 1 ? 'mins' : 'min';
        final hoursStr = hours > 0 ? '$hours $hoursUnit ' : '';
        final minsStr = mins > 0 ? '$mins $minsUnit' : '';
        return '$sign$days $dayUnit $hoursStr$minsStr'.trim();
      } else {
        final hoursStr = hours > 0 ? '$hours giờ ' : '';
        final minsStr = mins > 0 ? '$mins phút' : '';
        return '$sign$days $dayUnit $hoursStr$minsStr'.trim();
      }
    }

    // Trên 60 phút: hiển thị giờ + phút
    if (minutes >= 60) {
      final int hours = minutes ~/ 60;
      final int mins = minutes % 60;
      if (useEn) {
        final String hourUnit = hours > 1 ? 'hours' : 'hour';
        if (mins == 0) {
          return '$sign$hours $hourUnit';
        }
        final String minUnit = mins > 1 ? 'mins' : 'min';
        return '$sign$hours $hourUnit $mins $minUnit';
      } else {
        if (mins == 0) {
          return '$sign$hours giờ';
        }
        return '$sign$hours giờ $mins phút';
      }
    }

    // Dưới 60 phút: hiển thị phút
    if (useEn) {
      final String minUnit = minutes == 1 ? 'min' : 'mins';
      return '$sign$minutes $minUnit';
    } else {
      return '$sign$minutes phút';
    }
  }

  /// Format một Duration (từ DateTime.difference) thành chuỗi human-readable.
  static String formatDiff(
    Duration diff, {
    bool isEnglish = false,
    BuildContext? context,
  }) {
    return format(diff.inMinutes, isEnglish: isEnglish, context: context);
  }
}
