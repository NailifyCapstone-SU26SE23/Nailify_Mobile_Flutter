// lib/router/app_router.dart
import 'package:flutter/cupertino.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/pages/customer_login_page.dart';
import '../../features/auth/presentation/pages/customer_register_page.dart';
import '../../features/auth/presentation/pages/profile_page.dart';
import '../../features/auth/presentation/pages/profile_update_pages.dart';
import '../../features/catalog/presentation/pages/catalog_page.dart';
import '../../features/catalog/presentation/pages/nail_details_page.dart';
import '../../features/quiz/presentation/pages/quiz_page.dart';
import '../../features/quiz/presentation/pages/analyze_page.dart';
import '../../features/perfect_match/presentation/pages/perfect_match_page.dart';
import '../../features/another_design/presentation/pages/another_design_page.dart';
import '../../features/discover/presentation/pages/discover_page.dart';
//booking
import '../../features/nail_booking/presentation/pages/nail_booking_page.dart';

//custom nail
import '../../features/custom_nail/presentation/pages/custom_nail_stepper_page.dart';

import '../../features/home/presentation/pages/home_page.dart';
import '../../features/nails/presentation/pages/customer_studio_page.dart';
import '../../features/nails/presentation/pages/nail_detail_screen.dart';
import '../../features/nails/presentation/pages/nail_list_screen.dart';
import '../../features/nails/presentation/pages/nail_variant_detail_screen.dart';
import '../../features/try-on/presentation/try_on_setup_screen.dart';
import '../widgets/main_shell.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      // Login/Register - NO shell at all (full screen)
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
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
      //------
      // custom nail page, page này có header và footer riêng
      GoRoute(
        path: '/custom-nail',
        builder: (context, state) => const CustomNailStepperPage(),
      ),
      //booking with nail
      GoRoute(
        path: '/nail-booking',
        builder: (context, state) {
          // Nhận dữ liệu truyền sang nếu có
          final Map<String, dynamic>? nailData = state.extra as Map<String, dynamic>?;
          return NailBookingPage(nailData: nailData);
        },
      ),

      // ========== ROUTES WITH BOTTOM NAV BUT NO HEADER ==========
      GoRoute(
        path: '/try-on',
        builder: (context, state) => const MainShell(
          child: TryOnSetupScreen(),
          showHeader: false, // NO header image
        ),
      ),

      GoRoute(
        path: '/profile',
        builder: (context, state) => const MainShell(
          child: ProfilePage(),
          showHeader: false, // NO header image
        ),
      ),

      GoRoute(
        path: '/profile/update-info',
        builder: (context, state) => const MainShell(
          child: UpdateProfilePage(),
          showHeader: false,
        ),
      ),

      GoRoute(
        path: '/profile/update-preferences',
        builder: (context, state) => const MainShell(
          child: UpdatePreferencesPage(),
          showHeader: false,
        ),
      ),

      GoRoute(
        path: '/profile/booking-history',
        builder: (context, state) => MainShell(
          child: const Center(
            child: Text('Lịch sử đặt lịch', style: TextStyle(fontSize: 24)),
          ),
          showHeader: false,
        ),
      ),

      GoRoute(
        path: '/profile/invoices',
        builder: (context, state) => MainShell(
          child: const Center(
            child: Text('Hóa đơn', style: TextStyle(fontSize: 24)),
          ),
          showHeader: false,
        ),
      ),

      GoRoute(
        path: '/profile/favorite-nails',
        builder: (context, state) => MainShell(
          child: const Center(
            child: Text('Móng yêu thích', style: TextStyle(fontSize: 24)),
          ),
          showHeader: false,
        ),
      ),

      GoRoute(
        path: '/profile/my-studio',
        builder: (context, state) => const MainShell(
          child: CustomerStudioPage(),
          showHeader: false,
        ),
      ),

      // ========== ROUTES WITH BOTTOM NAV AND HEADER ==========
      GoRoute(
        path: '/',
        builder: (context, state) => const MainShell(
          child: HomePage(),
          showHeader: true, // SHOW header image
        ),
      ),

      GoRoute(
        path: '/nails',
        builder: (context, state) => const MainShell(
          child: NailListScreen(),
          showHeader: true,
        ),
      ),

      GoRoute(
        path: '/nails/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return MainShell(
            child: NailDetailScreen(nailDesignId: id ?? 0),
            showHeader: true,
          );
        },
      ),

      GoRoute(
        path: '/nail-variants/:id',
        builder: (context, state) {
          final id = int.tryParse(state.pathParameters['id'] ?? '');
          return MainShell(
            child: NailVariantDetailScreen(nailVariantId: id ?? 0),
            showHeader: true,
          );
        },
      ),

      GoRoute(
        path: '/catalog',
        builder: (context, state) => const MainShell(
          child: CatalogPage(),
          showHeader: true,
        ),
      ),

      GoRoute(
        path: '/catalog/details',
        builder: (context, state) {
          final nailData = state.extra as Map<String, dynamic>;
          return MainShell(
            child: NailDetailsPage(nailData: nailData),
            showHeader: true,
          );
        },
      ),
    ],
  );
}
