/// Format thoi gian thanh chuoi human-readable.
///
/// Su dung:
/// ```dart
/// DurationFormatter.format(45);           // "45 phut"
/// DurationFormatter.format(90);           // "1 gio 30 phut"
/// DurationFormatter.format(150);          // "2 gio 30 phut"
/// DurationFormatter.format(-419);        // "-419 phut" (loi timezone server)
/// DurationFormatter.formatDiff(duration); // "2 gio 30 phut"
/// ```
class DurationFormatter {
  /// Format mot so phut (int/double/String) thanh chuoi human-readable.
  ///
  /// - Xu ly so am: lay gia tri tuyet doi + prefix "-"
  ///   (vi du: server tra ve -419 phut do loi timezone)
  /// - Tren 24 gio: hien thi "X ngay Y gio Z phut"
  /// - Tren 60 phut: hien thi "X gio Y phut"
  /// - Duoi 60 phut: hien thi "X phut"
  static String format(dynamic minutesRaw) {
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
        return isNegative ? '-$days ngay' : '$days ngay';
      }
      final int hours = remainingMinutes ~/ 60;
      final int mins = remainingMinutes % 60;
      final hoursStr = hours > 0 ? '$hours gio ' : '';
      return isNegative
          ? '-$days ngay $hoursStr$mins phut'
          : '$days ngay $hoursStr$mins phut';
    }

    // Tren 60 phut: hien thi gio + phut
    if (minutes >= 60) {
      final int hours = minutes ~/ 60;
      final int mins = minutes % 60;
      if (mins == 0) {
        return isNegative ? '-$hours gio' : '$hours gio';
      }
      return isNegative ? '-$hours gio $mins phut' : '$hours gio $mins phut';
    }

    // Duoi 60 phut: hien thi phut
    return isNegative ? '-$minutes phut' : '$minutes phut';
  }

  /// Format mot Duration (tu DateTime.difference) thanh chuoi human-readable.
  /// Tu dong xu ly negative (Duration am -> lay tuyet doi).
  static String formatDiff(Duration diff) {
    return format(diff.inMinutes);
  }
}
