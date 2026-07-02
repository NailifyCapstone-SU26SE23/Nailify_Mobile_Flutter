import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../features/another_design/presentation/pages/another_design_page.dart';
import '../../features/auth/presentation/pages/customer_login_page.dart';
import '../../features/auth/presentation/pages/customer_register_page.dart';
import '../../features/auth/presentation/pages/profile_update_pages.dart';
import '../../features/catalog/presentation/pages/catalog_page.dart';
import '../../features/catalog/presentation/pages/nail_details_page.dart';
import '../../features/custom_nail/presentation/pages/custom_nail_stepper_page.dart';
import '../../features/discover/presentation/pages/discover_page.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/my_booking/presentation/pages/my_booking_detail_page.dart';
import '../../features/my_booking/presentation/pages/my_booking_list_page.dart';
import '../../features/my_booking/presentation/pages/booking_rating_page.dart';
import '../../features/my_studio/data/models/customer_nail_model.dart';
import '../../features/my_studio/presentation/pages/customer_nail_detail_page.dart';
import '../../features/nail_booking/presentation/pages/booking_success_page.dart';
import '../../features/nail_booking/presentation/pages/custom_nail_booking_page.dart';
import '../../features/nail_booking/presentation/pages/nail_booking_page.dart';
import '../../features/nail_booking/presentation/pages/payment_qr_page.dart';
import '../../features/nail_booking/presentation/pages/payment_result_page.dart';
import '../../features/nail_booking/presentation/pages/service_booking_page.dart';
import '../../features/my_studio/presentation/pages/my_studio_tab_page.dart';
import '../../features/nails/presentation/pages/nail_detail_screen.dart';
import '../../features/nails/presentation/pages/nail_list_screen.dart';
import '../../features/nails/presentation/pages/nail_variant_detail_screen.dart';
import '../../features/perfect_match/presentation/pages/perfect_match_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/quiz/presentation/pages/analyze_page.dart';
import '../../features/quiz/presentation/pages/quiz_page.dart';
import '../../features/services/presentation/pages/service_detail_page.dart';
import '../../features/services/presentation/pages/service_list_page.dart';
import '../../features/try-on/presentation/try_on_setup_screen.dart';
import '../widgets/main_shell.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/nail-booking',
        builder: (context, state) {
          final nailData = state.extra as Map<String, dynamic>?;
          return NailBookingPage(nailData: nailData);
        },
      ),
      GoRoute(
        path: '/service-booking',
        builder: (context, state) {
          final serviceData = state.extra as Map<String, dynamic>;
          return ServiceBookingPage(baseService: serviceData);
        },
      ),
      GoRoute(
        path: '/custom-nail-booking',
        builder: (context, state) {
          final nail = state.extra as CustomerNailModel;
          return CustomNailBookingPage(nail: nail);
        },
      ),
      GoRoute(
        path: '/booking-success',
        builder: (context, state) {
          final details = state.extra as Map<String, dynamic>? ?? {};
          return BookingSuccessPage(bookingDetails: details);
        },
      ),
      GoRoute(
        path: '/payment-qr',
        builder: (context, state) {
          final paymentData = state.extra as Map<String, dynamic>? ?? {};
          return PaymentQrPage(paymentData: paymentData);
        },
      ),
      GoRoute(
        path: '/payment-success',
        builder: (context, state) {
          final paymentData = state.extra as Map<String, dynamic>? ?? {};
          return PaymentSuccessPage(paymentData: paymentData);
        },
      ),
      GoRoute(
        path: '/payment-cancelled',
        builder: (context, state) {
          final paymentData = state.extra as Map<String, dynamic>? ?? {};
          return PaymentCancelledPage(paymentData: paymentData);
        },
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/discover',
            builder: (context, state) => const DiscoverPage(),
          ),
          GoRoute(
            path: '/custom-nail',
            builder: (context, state) => const CustomNailStepperPage(),
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
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
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
            path: '/services',
            builder: (context, state) => const ServiceListPage(),
          ),
          GoRoute(
            path: '/services/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return ServiceDetailPage(serviceId: id);
            },
          ),
          GoRoute(
            path: '/my-bookings',
            builder: (context, state) => const MyBookingListPage(),
          ),
          GoRoute(
            path: '/my-bookings/detail',
            builder: (context, state) {
              final bookingId = state.extra?.toString() ?? '';
              return MyBookingDetailPage(bookingId: bookingId);
            },
          ),
          GoRoute(
            path: '/my-bookings/rate',
            builder: (context, state) {
              final bookingId = state.extra?.toString() ?? '';
              return BookingRatingPage(bookingId: bookingId);
            },
          ),
          GoRoute(
            path: '/my-studio',
            builder: (context, state) => const MyStudioTabPage(),
          ),
          GoRoute(
            path: '/my-studio/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return CustomerNailDetailPage(id: id);
            },
          ),
          GoRoute(path: '/quiz', builder: (context, state) => const QuizPage()),
          GoRoute(
            path: '/quiz/analyze',
            builder: (context, state) {
              final answers = state.extra as List<int>? ?? [];
              return AnalyzePage(answers: answers);
            },
          ),
          GoRoute(
            path: '/perfect-match',
            builder: (context, state) {
              final answers = state.extra as List<int>? ?? [];
              return PerfectMatchPage(answers: answers);
            },
          ),
          GoRoute(
            path: '/another-design',
            builder: (context, state) => const AnotherDesignPage(),
          ),
          GoRoute(
            path: '/try-on',
            builder: (context, state) => const TryOnSetupScreen(),
          ),
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
          GoRoute(
            path: '/profile/update-info',
            builder: (context, state) => const UpdateProfilePage(),
          ),
          GoRoute(
            path: '/profile/update-preferences',
            builder: (context, state) => const UpdatePreferencesPage(),
          ),
          GoRoute(
            path: '/profile/booking-history',
            builder: (context, state) => const Center(
              child: Text('Lịch sử đặt lịch', style: TextStyle(fontSize: 24)),
            ),
          ),
          GoRoute(
            path: '/profile/invoices',
            builder: (context, state) => const Center(
              child: Text('Hóa đơn', style: TextStyle(fontSize: 24)),
            ),
          ),
          GoRoute(
            path: '/profile/favorite-nails',
            builder: (context, state) => const Center(
              child: Text('Móng yêu thích', style: TextStyle(fontSize: 24)),
            ),
          ),
          GoRoute(
            path: '/profile/my-studio',
            builder: (context, state) => const MyStudioTabPage(),
          ),
        ],
      ),
    ],
  );
}
