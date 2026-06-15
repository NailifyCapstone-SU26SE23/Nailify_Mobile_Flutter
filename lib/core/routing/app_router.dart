import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

// --- Features ---
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/nails/presentation/pages/nail_detail_screen.dart';
import '../../features/nails/presentation/pages/nail_list_screen.dart';
import '../../features/nails/presentation/pages/nail_variant_detail_screen.dart';
import '../../features/catalog/presentation/pages/catalog_page.dart';
import '../../features/catalog/presentation/pages/nail_details_page.dart';
import '../../features/quiz/presentation/pages/quiz_page.dart';
import '../../features/quiz/presentation/pages/analyze_page.dart';
import '../../features/perfect_match/presentation/pages/perfect_match_page.dart';
import '../../features/another_design/presentation/pages/another_design_page.dart';
import '../../features/discover/presentation/pages/discover_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/nail_booking/presentation/pages/nail_booking_page.dart';
import '../../features/custom_nail/presentation/pages/custom_nail_stepper_page.dart';

// --- Auth ---
import '../../features/auth/presentation/pages/customer_login_page.dart';
import '../../features/auth/presentation/pages/customer_register_page.dart';

// --- Widgets ---
import '../widgets/main_shell.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      // 1. Auth Routes
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),

      // 2. Quiz & Discovery Routes (Với Shell)
      GoRoute(
        path: '/quiz',
        builder: (context, state) => const MainShell(child: QuizPage()),
      ),
      GoRoute(
        path: '/quiz/analyze',
        builder: (context, state) {
          final answers = state.extra as List<int>? ?? [];
          return MainShell(child: AnalyzePage(answers: answers));
        },
      ),
      GoRoute(
        path: '/perfect-match',
        builder: (context, state) {
          final answers = state.extra as List<int>? ?? [];
          return MainShell(child: PerfectMatchPage(answers: answers));
        },
      ),
      GoRoute(
        path: '/another-design',
        builder: (context, state) => const MainShell(child: AnotherDesignPage()),
      ),
      GoRoute(
        path: '/discover',
        builder: (context, state) => const MainShell(child: DiscoverPage()),
      ),

      // 3. Custom & Booking Routes (Full-screen)
      GoRoute(
        path: '/custom-nail',
        builder: (context, state) => const CustomNailStepperPage(),
      ),
      GoRoute(
        path: '/nail-booking',
        builder: (context, state) {
          final Map<String, dynamic>? nailData = state.extra as Map<String, dynamic>?;
          return NailBookingPage(nailData: nailData);
        },
      ),

      // 4. ShellRoute (Bottom Navigation)
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
          GoRoute(
            path: '/catalog',
            builder: (context, state) => const CatalogPage(),
          ),
          GoRoute(
            path: '/catalog/details',
            builder: (context, state) {
              final nailData = state.extra as Map<String, dynamic>;
              return NailDetailsPage(nailData: nailData);
            },
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
        ],
      ),
    ],
  );
}