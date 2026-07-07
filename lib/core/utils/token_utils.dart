import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';

/// Tiện ích xử lý JWT Token: giải mã payload, kiểm tra hết hạn, và tự động
/// xóa token không còn khả dụng.
class TokenUtils {
  /// Giải mã payload của JWT token (phần giữa, Base64Url-encoded).
  /// Trả về `null` nếu token không hợp lệ.
  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      // Chuẩn hóa Base64Url -> Base64
      String payload = parts[1];
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }

      final decoded = utf8.decode(base64Url.decode(payload));
      return jsonDecode(decoded) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  /// Kiểm tra token đã hết hạn hay chưa.
  /// Trả về `true` nếu token đã hết hạn hoặc không hợp lệ.
  static bool isTokenExpired(String token) {
    final payload = decodePayload(token);
    if (payload == null) return true;

    final exp = payload['exp'];
    if (exp == null || exp is! int) return true;

    // 'exp' trong JWT là Unix timestamp (giây)
    final expiryDate = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
    return DateTime.now().isAfter(expiryDate);
  }

  /// Kiểm tra token trong SharedPreferences.
  /// Nếu token đã hết hạn hoặc không hợp lệ -> tự động xóa và trả về `false`.
  /// Nếu token còn sống -> trả về `true`.
  static bool validateAndCleanToken(SharedPreferences prefs) {
    final token = prefs.getString(AppConstants.authTokenKey);
    if (token == null || token.isEmpty) return false;

    if (isTokenExpired(token)) {
      // Token hết hạn -> xóa sạch
      prefs.remove(AppConstants.authTokenKey);
      return false;
    }

    return true;
  }
}
