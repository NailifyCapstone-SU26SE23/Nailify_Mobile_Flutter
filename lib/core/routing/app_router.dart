import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/nails/presentation/pages/nail_detail_screen.dart';
import '../../features/nails/presentation/pages/nail_list_screen.dart';
import '../../features/nails/presentation/pages/nail_variant_detail_screen.dart';
import '../widgets/main_shell.dart';
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
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomePage(),
          ),
          GoRoute(
            path: '/nails',
            builder: (context, state) => const NailListScreen(),
          ),
          GoRoute(
            path: '/nails/:id',
            builder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              return NailDetailScreen(nailDesignId: id ?? 0);
            },
          ),
          GoRoute(
            path: '/nail-variants/:id',
            pageBuilder: (context, state) {
              final id = int.tryParse(state.pathParameters['id'] ?? '');
              return CustomTransitionPage<void>(
                key: state.pageKey,
                child: NailVariantDetailScreen(nailVariantId: id ?? 0),
                transitionsBuilder: (context, animation, secondaryAnimation, child) {
                  final offset = Tween<Offset>(
                    begin: const Offset(0, 1),
                    end: Offset.zero,
                  ).chain(CurveTween(curve: Curves.easeOutCubic));
                  return SlideTransition(
                    position: animation.drive(offset),
                    child: child,
                  );
                },
              );
            },
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
