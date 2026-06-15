// lib/core/widgets/main_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../di/injection.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  bool get _isLoggedIn {
    final token =
        getIt<SharedPreferences>().getString(AppConstants.authTokenKey);
    return token != null && token.isNotEmpty;
  }

  int _calculateCurrentIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/appointments')) return 1;
    if (location.startsWith('/chatbot')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        _showPopupNotification(context, 'Lịch hẹn');
        break;
      case 2:
        _showPopupNotification(context, 'Chatbot');
        break;
      case 3:
        context.go('/profile');
        break;
    }
    if (index == 2) {
      _showPopupNotification(context, 'Chatbot');
      return;
    }
    context.go('/profile');
  }

  void _showPopupNotification(BuildContext context, String actionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.construction, color: Colors.amber),
            SizedBox(width: 8),
            Text('Thông báo'),
          ],
        ),
        content: Text('Tính năng "$actionName" đang được xử lý. Trang mục tiêu hiện tại chưa được khởi tạo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        title: GestureDetector(
          onTap: () => context.go('/'),
          child: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Image.asset(
              'assets/images/pink.png',
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Text(
                'Nailify',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        actions: _isLoggedIn
            ? const [SizedBox(width: 16)]
            : [
          OutlinedButton(
            onPressed: () => context.push('/login'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Sign in', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => context.push('/register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary, // Sử dụng constant
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Register', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          ),
          const SizedBox(width: 16),
        ],
      ),

      body: widget.child,

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateCurrentIndex(context),
        onTap: (index) => _onTabTapped(context, index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary, // Màu hồng khi chọn tab
        unselectedItemColor: AppColors.textSecondary, // Màu xám khi chưa chọn tab
        backgroundColor: AppColors.background,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Lịch hẹn'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chatbot'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Tài khoản'),
        ],
      ),
    );
  }
}
