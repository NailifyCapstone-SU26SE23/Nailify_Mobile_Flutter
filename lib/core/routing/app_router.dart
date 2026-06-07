import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/nails/presentation/pages/nail_detail_screen.dart';
import '../../features/nails/presentation/pages/nail_list_screen.dart';
import '../../features/nails/presentation/pages/nail_variant_detail_screen.dart';
import '../widgets/main_shell.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
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
        ],
      ),
    ],
  );
}
