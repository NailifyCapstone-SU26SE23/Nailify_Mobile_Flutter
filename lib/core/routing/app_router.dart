import 'package:go_router/go_router.dart';
import '../widgets/main_shell.dart';
import '../../features/home/presentation/pages/home_page.dart';
import '../../features/auth/presentation/pages/customer_login_page.dart';
import '../../features/auth/presentation/pages/customer_register_page.dart';

import '../../features/catalog/presentation/pages/catalog_page.dart';
import '../../features/catalog/presentation/pages/nail_details_page.dart';
import '../../features/quiz/presentation/pages/quiz_page.dart';
import '../../features/quiz/presentation/pages/analyze_page.dart';
import '../../features/perfect_match/presentation/pages/perfect_match_page.dart';
import '../../features/another_design/presentation/pages/another_design_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/discover/presentation/pages/discover_page.dart';

//custom nail
import '../../features/custom_nail/presentation/pages/custom_nail_stepper_page.dart';


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
          GoRoute(
            path: '/profile',
            builder: (context, state) => const ProfilePage(),
          ),
          // custom nail page
        ],
      ),
    ],
  );
}