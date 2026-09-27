class AppException implements Exception {
  final String message;
  final String code;
  final dynamic data;
  const AppException({required this.message, this.code = '', this.data});

  @override
  String toString() => message;
}

/// Phân loại lỗi trả về khi giữ chỗ (hold-slot) trong các luồng booking.
///
/// Backend .NET hiện tại trả 400 Bad Request cho case
/// "thợ đã đầy lịch / slot vừa bị giữ". Trước đây code Flutter chỉ
/// nhận diện HTTP 409 → không phân biệt được → hiển thị sai message
/// "Hệ thống đang gặp sự cố" thay vì "vui lòng chọn giờ khác".
enum HoldErrorKind {
  /// Slot vừa bị người khác giữ (HTTP 409/410/423). Nên reload slots.
  slotTakenByOther,

  /// Thợ đã đầy lịch trong khoảng user chọn (HTTP 400 + message cụ thể).
  /// KHÔNG phải lỗi hệ thống — user chọn giờ không còn khả dụng.
  artistFullyBooked,

  /// Lỗi hệ thống thực sự (network, 500, timeout...).
  systemError,
}

/// Keyword để nhận diện message conflict từ backend .NET (VN + EN).
/// Đặt ngoài class để cả 2 cubit (nail_booking + warranty_booking) có thể
/// dùng chung.
const List<String> _holdConflictKeywords = [
  'đã đầy lịch',
  'đã được giữ',
  'đã có người chọn',
  'vừa được giữ',
  'slot',
  'kín lịch',
  'đã đặt',
  'fully booked',
  'not available',
  'already held',
];

/// Phân loại exception trả về từ API hold-slot để UI hiển thị message
/// đúng cho từng trường hợp:
///  - slotTakenByOther   → "vừa có người chọn, chọn giờ khác"
///  - artistFullyBooked  → "thợ đã đầy lịch" (server message, có thể tiếng Việt)
///  - systemError        → "hệ thống đang gặp sự cố"
HoldErrorKind classifyHoldError(Object error) {
  if (error is! AppException) return HoldErrorKind.systemError;

  final code = error.code;
  final msg = error.message.toLowerCase();
  final isHttp400 = code == 'HTTP_400';

  final hasConflictKeyword = _holdConflictKeywords.any(msg.contains);
  if (isHttp400 && hasConflictKeyword) {
    return HoldErrorKind.artistFullyBooked;
  }
  if (code == 'HTTP_409' || code == 'HTTP_410' || code == 'HTTP_423') {
    return HoldErrorKind.slotTakenByOther;
  }

  // Backend trả 400 với isSucceeded=false (nhưng message generic) → vẫn
  // coi là lỗi nghiệp vụ, không phải hệ thống.
  final data = error.data;
  if (data is Map && isHttp400 && data['isSucceeded'] == false) {
    return HoldErrorKind.artistFullyBooked;
  }
  return HoldErrorKind.systemError;
}

class TimeoutException extends AppException {
  const TimeoutException()
    : super(message: 'Kết nối quá thời gian quy định', code: 'TIMEOUT');
}

class NetworkException extends AppException {
  const NetworkException()
    : super(message: 'Không có kết nối mạng', code: 'NO_INTERNET');
}

class ServerException extends AppException {
  const ServerException({
    super.message = 'Hệ thống đang gặp sự cố. Vui lòng thử lại sau.',
    super.data,
  }) : super(code: 'SERVER_ERROR');
}

class ExceptionFactory {
  static AppException fromHttpStatusCode(
    int statusCode, {
    String? message,
    dynamic data,
  }) {
    String friendlyMessage = message ?? '';

    // Check if message is generic or indicates server error
    if (friendlyMessage.isEmpty ||
        friendlyMessage == 'Lỗi không xác định: $statusCode' ||
        friendlyMessage.contains('Lỗi từ Server') ||
        friendlyMessage.contains('Server Error')) {
      if (statusCode == 400) {
        friendlyMessage =
            'Yêu cầu không hợp lệ. Vui lòng kiểm tra lại thông tin.';
      } else if (statusCode == 401) {
        friendlyMessage =
            'Phiên làm việc đã hết hạn hoặc không có quyền truy cập. Vui lòng đăng nhập lại.';
      } else if (statusCode == 403) {
        friendlyMessage = 'Bạn không có quyền thực hiện hành động này.';
      } else if (statusCode == 404) {
        friendlyMessage = 'Không tìm thấy dữ liệu yêu cầu.';
      } else if (statusCode >= 500) {
        friendlyMessage = 'Hệ thống đang gặp sự cố. Vui lòng thử lại sau.';
      } else {
        friendlyMessage = 'Lỗi kết nối hệ thống ($statusCode)';
      }
    }
    return AppException(
      message: friendlyMessage,
      code: 'HTTP_$statusCode',
      data: data,
    );
  }
}
