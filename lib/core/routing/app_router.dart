import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const Scaffold(
          body: Center(
            child: Text('Nền tảng ứng dụng Core của App Nailify đã thiết lập thành công!'),
          ),
        ),
      ),
    ],
  );
}