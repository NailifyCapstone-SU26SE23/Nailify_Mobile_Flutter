class AppException implements Exception {
  final String message;
  final String code;
  final dynamic data;
  const AppException({required this.message, this.code = '', this.data});

  @override
  String toString() => message;
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