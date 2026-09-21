import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
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
    final path = error.requestOptions.path;
    final statusCode = error.response?.statusCode;

    // Ưu tiên 1: Nếu server trả body có `message`/`error` (kể cả khi
    // status code là 200/400/401), trả message gốc để UI hiển thị.
    // Đặc biệt fix cho backend .NET dùng ApiResponse wrapper:
    // `{ "isSucceeded": false, "message": "...", "data": null }`
    // trả về HTTP 200 với DioExceptionType.badResponse.
    final responseData = _coerceBodyMap(error.response?.data);
    if (responseData != null) {
      final isSucceeded =
          responseData['isSucceeded'] ?? responseData['IsSucceeded'];
      final serverMessage =
          responseData['message'] ??
          responseData['Message'] ??
          responseData['error'] ??
          responseData['Error'];
      if (isSucceeded == false && serverMessage != null) {
        final msg = serverMessage.toString().trim();
        if (msg.isNotEmpty) {
          // Phân loại lỗi INVALID_CREDENTIALS cho endpoint login
          if (path.contains('/Auth/login') &&
              (statusCode == 400 || statusCode == 401 ||
                  msg.toLowerCase().contains('không chính xác') ||
                  msg.toLowerCase().contains('invalid') ||
                  msg.toLowerCase().contains('credentials'))) {
            return AppException(
              message:
                  'Email hoặc mật khẩu không chính xác, vui lòng kiểm tra lại',
              code: 'INVALID_CREDENTIALS',
              data: responseData,
            );
          }
          // Trả message gốc từ server để UI hiển thị cho user
          return AppException(
            message: msg,
            code: statusCode != null ? 'HTTP_$statusCode' : 'SERVER_MESSAGE',
            data: responseData,
          );
        }
      }
    }

    // Ưu tiên 2: Endpoint login với status 400/401 không có body message
    if (path.contains('/Auth/login') &&
        (statusCode == 400 || statusCode == 401)) {
      return const AppException(
        message: 'Email hoặc mật khẩu không chính xác, vui lòng kiểm tra lại',
        code: 'INVALID_CREDENTIALS',
      );
    }

    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const TimeoutException();
      case DioExceptionType.connectionError:
        return const NetworkException();
      case DioExceptionType.badResponse:
        final statusCode = error.response?.statusCode;
        // Ưu tiên lấy message gốc từ server trước, bất kể status code.
        // Backend .NET có thể trả 400 với body là String chưa parse hoặc
        // Map không có `isSucceeded` flag. Cover cả 2 trường hợp.
        final rawData = error.response?.data;
        final Map<String, dynamic>? bodyMap = _coerceBodyMap(rawData);
        if (kDebugMode) {
          debugPrint(
            '[ApiClient] badResponse path=$path status=$statusCode '
            'rawType=${rawData.runtimeType} bodyMap=$bodyMap',
          );
        }
        if (bodyMap != null) {
          final serverMsg = (bodyMap['message'] ??
                  bodyMap['Message'] ??
                  bodyMap['error'] ??
                  bodyMap['Error'] ??
                  bodyMap['title'] ??
                  bodyMap['detail'])
              ?.toString()
              .trim();
          if (serverMsg != null && serverMsg.isNotEmpty) {
            return AppException(
              message: serverMsg,
              code:
                  statusCode != null ? 'HTTP_$statusCode' : 'SERVER_MESSAGE',
              data: bodyMap,
            );
          }
        }
        if (statusCode != null) {
          return ExceptionFactory.fromHttpStatusCode(
            statusCode,
            message: null,
            data: bodyMap,
          );
        }
        return ServerException(data: bodyMap);
      default:
        return AppException(
          message: error.message ?? 'Lỗi không xác định',
          code: 'UNKNOWN_ERROR',
          data: error,
        );
    }
  }

  Dio get dio => _dio;

  /// Chuyển `data` trong DioException.response về `Map<String, dynamic>`
  /// (nếu có thể) để truy xuất `message` chuẩn xác. Dio đôi khi để
  /// `data` ở dạng String chưa parse, đặc biệt khi `responseType` không
  /// phải JSON hoặc Content-Type bị sai.
  Map<String, dynamic>? _coerceBodyMap(dynamic raw) {
    if (raw == null) return null;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) {
      return raw.map((k, v) => MapEntry(k.toString(), v));
    }
    if (raw is String && raw.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) {
          return decoded.map((k, v) => MapEntry(k.toString(), v));
        }
      } catch (_) {
        // Không parse được → trả về String nguyên bản để caller còn biết
        return {'message': raw};
      }
    }
    return null;
  }
}
