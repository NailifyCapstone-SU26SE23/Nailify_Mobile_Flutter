class DurationFormatter {
    static String format(dynamic minutesRaw) {
    if (minutesRaw == null) return '0 phút';

    int minutes = 0;
    if (minutesRaw is int) {
      minutes = minutesRaw;
    } else if (minutesRaw is String) {
      minutes = int.tryParse(minutesRaw) ?? 0;
    } else if (minutesRaw is double) {
      minutes = minutesRaw.toInt();
    }

    if (minutes < 60) {
      return '$minutes phút';
    }

    final int hours = minutes ~/ 60; // lấy phần nguyên
    final int remainingMinutes = minutes % 60; // lấy  dư

    if (remainingMinutes == 0) {
      return '$hours giờ';
    }

    return '$hours giờ $remainingMinutes phút';
  }
}