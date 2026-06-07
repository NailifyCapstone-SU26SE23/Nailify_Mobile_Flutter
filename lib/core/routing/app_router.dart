import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/main_shell.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/auth/presentation/pages/customer_login_page.dart';
import '../../features/auth/presentation/pages/customer_register_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      // ShellRoute thiết lập cơ chế nạp trang con vào vùng nội dung của lớp vỏ dùng chung
      ShellRoute(
        builder: (context, state, child) {
          return MainShell(child: child); // Khung Activity chứa Header & Footer
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomePage(), // Fragment hiển thị chính
          ),
        ],
      ),
    ],
  );
}