import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../di/injection.dart';
import 'token_utils.dart';

class AuthGuard {
  /// Kiểm tra đăng nhập trước khi thực thi một hành động.
  /// [onProceed] là hàm sẽ chạy nếu người dùng ĐÃ có Token hợp lệ (chưa hết hạn).
  static void check(BuildContext context, VoidCallback onProceed) {
    final prefs = getIt<SharedPreferences>();
    final isValid = TokenUtils.validateAndCleanToken(prefs);

    if (isValid) {
      onProceed();
    } else {
      // Chưa đăng nhập hoặc token đã hết hạn
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại!'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      context.push('/login');
    }
  }
}
