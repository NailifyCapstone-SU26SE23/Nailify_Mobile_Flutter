// lib/core/widgets/main_shell.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/auth_guard.dart';
import '../../features/nails/presentation/pages/nail_list_screen.dart';
import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../di/injection.dart';
import '../../features/quiz/data/datasources/quiz_repository.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  final bool showHeader; // Add this parameter

  const MainShell({
    super.key,
    required this.child,
    this.showHeader = true, // Default to true
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // Biến kiểm tra trạng thái đăng nhập
  bool get _isLoggedIn {
    final token = getIt<SharedPreferences>().getString(AppConstants.authTokenKey);
    return token != null && token.isNotEmpty;
  }

  bool get _showMatchButton {
    return _isLoggedIn && getIt<SharedPreferences>().getBool('has_completed_quiz') == true;
  }

  @override
  void initState() {
    super.initState();
    _checkQuizCompletionInBackground();
  }

  Future<void> _checkQuizCompletionInBackground() async {
    final prefs = getIt<SharedPreferences>();
    final token = prefs.getString(AppConstants.authTokenKey);
    if (token == null || token.isEmpty) return;

    // If it's already checked and cached as true, no need to query again
    final cachedVal = prefs.getBool('has_completed_quiz');
    if (cachedVal == true) return;

    try {
      final repo = getIt<QuizRepository>();
      final data = await repo.getPersonalizedRecommendations();
      if (data.isNotEmpty) {
        await prefs.setBool('has_completed_quiz', true);
        if (mounted) {
          setState(() {}); // Rebuild to show the pulsing button
        }
      }
    } catch (_) {}
  }

  // Hàm xử lý Đăng xuất
  Future<void> _logout() async {
    final prefs = getIt<SharedPreferences>();
    await prefs.remove(AppConstants.authTokenKey);
    await prefs.remove('has_completed_quiz');
    NailListScreen.clearMatchedResults();
    if (mounted) {
      setState(() {}); // Làm mới UI để thanh AppBar vẽ lại nút
      context.go('/'); // Đưa người dùng về trang chủ
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Đã đăng xuất thành công!')),
      );
    }
  }

  int _calculateCurrentIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/my-bookings')) return 1;
    if (location.startsWith('/my-studio')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0; // Mặc định về trang chủ
  }

  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        break;
      case 1:
        AuthGuard.check(context, () => context.go('/my-bookings'));
        break;
      case 2:
        //_showPopupNotification(context, 'Chatbot');
        AuthGuard.check(context, () => context.go('/my-studio'));
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,

      // Conditional AppBar - only show header if showHeader is true
      appBar: widget.showHeader ? AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        title: GestureDetector(
          onTap: () => context.go('/'),
          child: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Image.asset(
              'assets/images/pink.png',
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Text(
                'Nailify',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        actions: _isLoggedIn
            ? [
          // NÚT PHÙ HỢP CÁ NHÂN HÓA NHẤP NHÁY (Chỉ hiện nếu đã làm quiz)
          if (_showMatchButton) ...[
            const _PulsingMatchButton(),
            const SizedBox(width: 12),
          ],
          // HIỂN THỊ NÚT ĐĂNG XUẤT KHI ĐÃ CÓ TOKEN
          OutlinedButton.icon(
            onPressed: _logout,
            icon: const Icon(Icons.logout, size: 18, color: AppColors.primary),
            label: const Text('Đăng xuất', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500, fontSize: 14)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 16),
            ),
          ),
          const SizedBox(width: 16),
        ]
            : [
          // HIỂN THỊ NÚT ĐĂNG NHẬP/ĐĂNG KÝ KHI CHƯA CÓ TOKEN
          OutlinedButton(
            onPressed: () => context.push('/login'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary, width: 1.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Sign in', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w500, fontSize: 14)),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => context.push('/register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 20),
            ),
            child: const Text('Register', style: TextStyle(fontWeight: FontWeight.w500, fontSize: 14)),
          ),
          const SizedBox(width: 16),
        ],
      ) : null, // No AppBar when showHeader is false

      // Wrap the body with SafeArea when header is hidden
      body: widget.showHeader
          ? widget.child
          : SafeArea(
        child: widget.child,
      ),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateCurrentIndex(context),
        onTap: (index) => _onTabTapped(context, index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: AppColors.background,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Lịch hẹn'),
          BottomNavigationBarItem(icon: Icon(Icons.palette_outlined), label: 'My Studio'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Tài khoản'),
        ],
      ),
    );
  }
}

class _PulsingMatchButton extends StatefulWidget {
  const _PulsingMatchButton();

  @override
  State<_PulsingMatchButton> createState() => _PulsingMatchButtonState();
}

class _PulsingMatchButtonState extends State<_PulsingMatchButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Stack(
          alignment: Alignment.center,
          children: [
            // Breathing Glow Circle Button
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(color: const Color(0xFFFFD1E1), width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFF4081).withValues(alpha: 0.12 + (0.12 * _controller.value)),
                    blurRadius: 6 + (6 * _controller.value),
                    spreadRadius: 1 + (2 * _controller.value),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () {
                    HapticFeedback.mediumImpact();
                    context.push('/perfect-match');
                  },
                  child: const Center(
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: Color(0xFFFF4081),
                      size: 18,
                    ),
                  ),
                ),
              ),
            ),
            // Tiny Notification Dot on top right corner
            Positioned(
              top: 2,
              right: 2,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: Color(0xFFFF4081),
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
