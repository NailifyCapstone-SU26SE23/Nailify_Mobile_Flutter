import 'package:dio/dio.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../constants/app_constants.dart';
import '../error/exceptions.dart';

class ApiClient {
  late final Dio _dio;
  final SharedPreferences? _preferences;

  ApiClient({String? baseUrl, SharedPreferences? preferences})
    : _preferences = preferences {
    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? AppConstants.baseUrl + AppConstants.apiVersion,
        connectTimeout: AppConstants.connectTimeout,
        receiveTimeout: AppConstants.receiveTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    _setupInterceptors();
  }

  void _setupInterceptors() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          final token = _preferences?.getString(AppConstants.authTokenKey);
          if (token != null && token.isNotEmpty) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
      ),
    );

    _dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        responseHeader: false,
        error: true,
        compact: true,
        maxWidth: 90,
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          // Khi server trả về 401 (Unauthorized) -> token đã hết hạn hoặc không hợp lệ
          // Tự động xóa token để lần truy cập tiếp theo sẽ yêu cầu đăng nhập lại
          if (error.response?.statusCode == 401) {
            removeAuthToken();
          }
          final exception = _handleDioError(error);
          handler.reject(
            DioException(
              requestOptions: error.requestOptions,
              error: exception,
              type: error.type,
            ),
          );
        },
      ),
    );
  }

  void setAuthToken(String token) {
    _dio.options.headers['Authorization'] = 'Bearer $token';
    _preferences?.setString(AppConstants.authTokenKey, token);
  }

  void removeAuthToken() {
    _dio.options.headers.remove('Authorization');
    _preferences?.remove(AppConstants.authTokenKey);
  }

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<T>> put<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.put<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  AppException _handleDioError(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        final message =
            error.response?.data?['message'] ?? error.response?.data?['error'];
        if (statusCode != null) {
          return ExceptionFactory.fromHttpStatusCode(
            statusCode,
            message: message,
            data: error.response?.data,
          );
        }
        return ServerException(
          message: message ?? 'Lỗi từ Server',
          data: error.response?.data,
        );
      default:
        return AppException(
          message: error.message ?? 'Lỗi không xác định',
          code: 'UNKNOWN_ERROR',
          data: error,
        );
    }
  }

  Dio get dio => _dio;
}
