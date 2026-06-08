import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../widgets/main_shell.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/auth/presentation/pages/customer_login_page.dart';
import '../../features/auth/presentation/pages/customer_register_page.dart';

import '../../features/catalog/presentation/pages/catalog_page.dart';
import '../../features/catalog/presentation/pages/nail_details_page.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      //---login-register
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      //------

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
          //catalog
          GoRoute(
            path: '/catalog',
            builder: (context, state) => const CatalogPage(),
          ),
          GoRoute(
            path: '/catalog/details',
            builder: (context, state) {
              // Trích xuất dữ liệu móng được truyền sang thông qua thuộc tính extra
              final nailData = state.extra as Map<String, dynamic>;
              return NailDetailsPage(nailData: nailData);
            },
          ),
        ],
      ),
    ],
  );
}