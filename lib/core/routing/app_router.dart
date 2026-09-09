import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/another_design/presentation/pages/another_design_page.dart';
import '../../features/auth/presentation/pages/customer_login_page.dart';
import '../../features/auth/presentation/pages/customer_register_page.dart';
import '../../features/auth/presentation/pages/forgot_password_pages.dart';
import '../../features/auth/presentation/pages/profile_update_pages.dart';
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
import '../../features/nail_booking/presentation/pages/home_booking_page.dart';
import '../../features/nail_booking/presentation/pages/nail_booking_page.dart';
import '../../features/nail_booking/presentation/pages/payment_qr_page.dart';
import '../../features/nail_booking/presentation/pages/payment_result_page.dart';
import '../../features/nail_booking/presentation/pages/refund_bank_info_page.dart';
import '../../features/nail_booking/presentation/pages/service_booking_page.dart';
import '../../features/nail_booking/presentation/pages/transaction_detail_page.dart';
import '../../features/nail_booking/presentation/pages/transaction_list_page.dart';
import '../../features/my_studio/presentation/pages/my_studio_tab_page.dart';
import '../../features/nails/presentation/pages/favorite_nails_page.dart';
import '../../features/nails/presentation/pages/nail_detail_screen.dart';
import '../../features/nails/presentation/pages/nail_list_screen.dart';
import '../../features/nails/presentation/pages/nail_variant_detail_screen.dart';
import '../../features/perfect_match/presentation/pages/perfect_match_page.dart';
import '../../features/perfect_match/presentation/pages/nail_composition_design_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/wallet/data/models/wallet_voucher_model.dart';
import '../../features/wallet/presentation/pages/my_vouchers_page.dart';
import '../../features/wallet/presentation/pages/points_history_page.dart';
import '../../features/wallet/presentation/pages/redeem_voucher_page.dart';
import '../../features/wallet/presentation/pages/voucher_detail_page.dart';
import '../../features/wallet/presentation/pages/wallet_overview_page.dart';
import '../../features/quiz/data/models/quiz_result_model.dart';
import '../../features/quiz/presentation/pages/analyze_page.dart';
import '../../features/quiz/presentation/pages/quiz_page.dart';
import '../../features/services/presentation/pages/service_detail_page.dart';
import '../../features/services/presentation/pages/service_list_page.dart';
import '../../features/salon/presentation/pages/nail_artist_detail_page.dart';
import '../../features/salon/presentation/pages/salon_detail_page.dart';
import '../../features/salon/presentation/pages/salon_list_page.dart';
import '../../features/nails/data/models/customer_nail_models.dart'
    as nails_models;
import '../../features/try-on/presentation/nail_snapshot_page.dart';
import '../../features/try-on/presentation/try_on_setup_screen.dart';
import '../widgets/main_shell.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginPage()),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) {
          final extra = state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : const <String, dynamic>{};
          return ForgotPasswordEmailPage(
            initialEmail: extra['email']?.toString() ?? '',
          );
        },
      ),
      GoRoute(
        path: '/forgot-password/code',
        builder: (context, state) {
          final extra = state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : const <String, dynamic>{};
          return ForgotPasswordCodePage(
            email: extra['email']?.toString() ?? '',
          );
        },
      ),
      GoRoute(
        path: '/forgot-password/reset',
        builder: (context, state) {
          final extra = state.extra is Map
              ? Map<String, dynamic>.from(state.extra as Map)
              : const <String, dynamic>{};
          return ForgotPasswordResetPage(
            token: extra['token']?.toString() ?? '',
          );
        },
      ),
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
        path: '/home-booking',
        builder: (context, state) => const HomeBookingPage(),
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
          final extra = state.extra;
          if (extra is Map) {
            final nail = _readCustomerNail(extra['nail']);
            return CustomNailBookingPage(
              nail: nail,
              shapeMethodConfigId: _readNullableInt(
                extra['shapeMethodConfigId'],
              ),
              shapeMethodName: extra['shapeMethodName']?.toString(),
              shapeMethodPrice: _readNullableNum(extra['shapeMethodPrice']),
              shapeMethodDuration: _readNullableInt(
                extra['shapeMethodDuration'],
              ),
            );
          }
          final nail = extra as CustomerNailModel;
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
      GoRoute(
        path: '/refund-bank-info',
        builder: (context, state) {
          final bookingId = state.extra?.toString() ?? '';
          return RefundBankInfoPage(bookingId: bookingId);
        },
      ),
      GoRoute(
        path: '/transaction-detail',
        builder: (context, state) {
          final transaction = state.extra as Map<String, dynamic>? ?? {};
          return TransactionDetailPage(transaction: transaction);
        },
      ),
      GoRoute(
        path: '/booking-transactions',
        builder: (context, state) {
          final bookingId = state.extra?.toString() ?? '';
          return TransactionListPage(bookingId: bookingId);
        },
      ),
      GoRoute(path: '/quiz', builder: (context, state) => const QuizPage()),
      GoRoute(
        path: '/quiz/analyze',
        builder: (context, state) {
          final selectedOptionIds =
              (state.extra as List?)?.map((item) => item.toString()).toList() ??
              const <String>[];
          return AnalyzePage(selectedOptionIds: selectedOptionIds);
        },
      ),
      GoRoute(
        path: '/perfect-match',
        builder: (context, state) {
          final results = state.extra is List
              ? List<QuizResultModel>.from(state.extra as List)
              : const <QuizResultModel>[];
          return PerfectMatchPage(results: results);
        },
      ),
      GoRoute(
        path: '/perfect-match/composition',
        builder: (context, state) {
          final matchedCharacteristics =
              state.extra is List<MatchedCharacteristic>
              ? state.extra as List<MatchedCharacteristic>
              : const <MatchedCharacteristic>[];
          return NailCompositionDesignPage(
            matchedCharacteristics: matchedCharacteristics,
          );
        },
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(
          showHeader: state.matchedLocation == '/',
          currentLocation: state.matchedLocation,
          child: child,
        ),
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
            path: '/salons',
            builder: (context, state) => const SalonListPage(),
          ),
          GoRoute(
            path: '/salons/:id',
            builder: (context, state) {
              final id = state.pathParameters['id'] ?? '';
              return SalonDetailPage(salonId: id);
            },
          ),
          GoRoute(
            path: '/salons/:salonId/artists/:artistId',
            builder: (context, state) {
              final artistId = state.pathParameters['artistId'] ?? '';
              return NailArtistDetailPage(nailArtistId: artistId);
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
          GoRoute(
            path: '/another-design',
            builder: (context, state) => const AnotherDesignPage(),
          ),
          GoRoute(
            path: '/try-on',
            builder: (context, state) {
              final extra = state.extra;
              if (extra is nails_models.CustomerNailModel) {
                return TryOnSetupScreen(customerNail: extra);
              }
              if (extra is Map<String, dynamic>) {
                return TryOnSetupScreen(recommendedData: extra);
              }
              return const TryOnSetupScreen();
            },
          ),
          GoRoute(
            path: '/snapshot-try-on',
            builder: (context, state) => const NailSnapshotPage(),
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
            path: '/profile/transactions',
            builder: (context, state) => const TransactionListPage(),
          ),
          GoRoute(
            path: '/profile/favorite-nails-list',
            builder: (context, state) => const FavoriteNailsPage(),
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
          GoRoute(
            path: '/profile/wallet',
            builder: (context, state) => const WalletOverviewPage(),
            routes: [
              GoRoute(
                path: 'vouchers',
                builder: (context, state) => const MyVouchersPage(),
              ),
              GoRoute(
                path: 'redeem',
                builder: (context, state) => const RedeemVoucherPage(),
              ),
              GoRoute(
                path: 'transactions',
                builder: (context, state) => const PointsHistoryPage(),
              ),
              GoRoute(
                path: 'vouchers/:usageId',
                builder: (context, state) {
                  final id = int.tryParse(
                    state.pathParameters['usageId'] ?? '',
                  );
                  final extra = state.extra;
                  return VoucherDetailPage(
                    userVoucherUsageId: id ?? 0,
                    voucher: extra is Map
                        ? null
                        : (extra as WalletVoucherModel?),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

int? _readNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

num? _readNullableNum(dynamic value) {
  if (value == null) return null;
  if (value is num) return value;
  return num.tryParse(value.toString());
}

CustomerNailModel _readCustomerNail(dynamic value) {
  if (value is CustomerNailModel) return value;
  if (value is Map) {
    return CustomerNailModel.fromJson(Map<String, dynamic>.from(value));
  }
  return value as CustomerNailModel;
}
