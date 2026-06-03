class AppException implements Exception {
  final String message;
  final String code;
  final dynamic data;
  const AppException({required this.message, this.code = '', this.data});
}

class TimeoutException extends AppException {
  const TimeoutException() : super(message: 'Kết nối quá thời gian quy định', code: 'TIMEOUT');
}

class NetworkException extends AppException {
  const NetworkException() : super(message: 'Không có kết nối mạng', code: 'NO_INTERNET');
}

class ServerException extends AppException {
  const ServerException({super.message = 'Lỗi hệ thống từ máy chủ', super.data}) : super(code: 'SERVER_ERROR');
}

class ExceptionFactory {
  static AppException fromHttpStatusCode(int statusCode, {String? message, dynamic data}) {
    return AppException(message: message ?? 'Lỗi không xác định: $statusCode', code: 'HTTP_$statusCode', data: data);
  }
}