// lib/core/widgets/main_shell.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/signalr_events.dart';
import '../network/signalr_service.dart';
import '../utils/auth_guard.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../di/injection.dart';
import '../network/api_client.dart';
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
  StreamSubscription<WaitlistPromotedEvent>? _promotedSub;
  StreamSubscription<WaitlistExpiredEvent>? _expiredSub;
  StreamSubscription<BookingCancelledEvent>? _cancelledSub;

  bool _hasRecommendations = false;
  String? _lastCheckedToken;
  bool _isCheckingRecommendations = false;

  @override
  void initState() {
    super.initState();
    _subscribeToSignalR();
  }

  void _checkAuthAndRecommendations() {
    final token = getIt<SharedPreferences>().getString(AppConstants.authTokenKey);
    final localQuizCompleted = getIt<SharedPreferences>().getBool('has_completed_quiz') ?? false;

    if (token != _lastCheckedToken) {
      _lastCheckedToken = token;
      _checkRecommendations();
    } else if (localQuizCompleted != _hasRecommendations) {
      setState(() {
        _hasRecommendations = localQuizCompleted;
      });
    }
  }

  Future<void> _checkRecommendations() async {
    if (!_isLoggedIn) {
      if (mounted) {
        setState(() {
          _hasRecommendations = false;
        });
      }
      return;
    }
    if (_isCheckingRecommendations) return;
    _isCheckingRecommendations = true;
    try {
      final repo = QuizRepository(getIt<ApiClient>());
      final data = await repo.getPersonalizedRecommendations();
      if (mounted) {
        setState(() {
          _hasRecommendations = data.isNotEmpty;
        });
        if (data.isNotEmpty) {
          getIt<SharedPreferences>().setBool('has_completed_quiz', true);
        } else {
          getIt<SharedPreferences>().setBool('has_completed_quiz', false);
        }
      }
    } catch (_) {
      // Bỏ qua lỗi check ngầm
    } finally {
      _isCheckingRecommendations = false;
    }
  }

  void _subscribeToSignalR() {
    final signalR = getIt<SignalRService>();

    _promotedSub = signalR.onWaitlistPromoted.listen((event) {
      if (!mounted) return;
      _showWaitlistBanner(event);
    });

    _expiredSub = signalR.onWaitlistExpired.listen((event) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(event.message),
          backgroundColor: Colors.orange.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    });

    _cancelledSub = signalR.onBookingCancelled.listen((event) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.cancel_outlined, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(child: Text(event.message)),
            ],
          ),
          backgroundColor: Colors.red.shade700,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 6),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          action: SnackBarAction(
            label: 'Xem lịch',
            textColor: Colors.white,
            onPressed: () => context.go('/my-bookings'),
          ),
        ),
      );
    });
  }

  void _showWaitlistBanner(WaitlistPromotedEvent event) {
    ScaffoldMessenger.of(context).clearMaterialBanners();
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: AppColors.primary.withValues(alpha: 0.95),
        leading: const Icon(Icons.notifications_active, color: Colors.white),
        content: Text(
          event.message,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).clearMaterialBanners();
              context.go('/my-bookings');
            },
            child: const Text(
              'Xác nhận ngay',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            ),
          ),
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context).clearMaterialBanners(),
            child: Text(
              'Đóng',
              style: TextStyle(color: Colors.white.withValues(alpha: 0.7)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _promotedSub?.cancel();
    _expiredSub?.cancel();
    _cancelledSub?.cancel();
    super.dispose();
  }

  // Biến kiểm tra trạng thái đăng nhập
  bool get _isLoggedIn {
    final token = getIt<SharedPreferences>().getString(
      AppConstants.authTokenKey,
    );
    return token != null && token.isNotEmpty;
  }

  // Hàm xử lý Đăng xuất
  Future<void> _logout() async {
    await getIt<SharedPreferences>().remove(AppConstants.authTokenKey);
    await getIt<SharedPreferences>().remove('has_completed_quiz');
    if (mounted) {
      setState(() {
        _hasRecommendations = false;
      }); // Làm mới UI để thanh AppBar vẽ lại nút
      context.go('/'); // Đưa người dùng về trang chủ
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Đã đăng xuất thành công!')));
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

  void _showPopupNotification(BuildContext context, String actionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.construction, color: Colors.amber),
            SizedBox(width: 8),
            Text('Thông báo'),
          ],
        ),
        content: Text(
          'Tính năng "$actionName" đang được xử lý. Trang mục tiêu hiện tại chưa được khởi tạo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text(
              'Đóng',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _checkAuthAndRecommendations();
    return Scaffold(
      backgroundColor: AppColors.background,

      // Conditional AppBar - only show header if showHeader is true
      appBar: widget.showHeader
          ? AppBar(
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
                      if (_hasRecommendations) ...[
                        const BlinkingPerfectMatchButton(),
                        const SizedBox(width: 12),
                      ],
                    ]
                  : [
                      // HIỂN THỊ NÚT ĐĂNG NHẬP/ĐĂNG KÝ KHI CHƯA CÓ TOKEN
                      OutlinedButton(
                        onPressed: () => context.push('/login'),
                        style: OutlinedButton.styleFrom(
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: const Text(
                          'Sign in',
                          style: TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () => context.push('/register'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(24),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                        ),
                        child: const Text(
                          'Register',
                          style: TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                    ],
            )
          : null, // No AppBar when showHeader is false
      // Wrap the body with SafeArea when header is hidden
      body: widget.showHeader ? widget.child : SafeArea(child: widget.child),

      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateCurrentIndex(context),
        onTap: (index) => _onTabTapped(context, index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: AppColors.background,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Lịch hẹn',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.palette_outlined),
            label: 'My Studio',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Tài khoản',
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
// WIDGET: Nút Perfect Match Nhấp Nháy
// ────────────────────────────────────────────────
class BlinkingPerfectMatchButton extends StatefulWidget {
  const BlinkingPerfectMatchButton({super.key});

  @override
  State<BlinkingPerfectMatchButton> createState() => _BlinkingPerfectMatchButtonState();
}

class _BlinkingPerfectMatchButtonState extends State<BlinkingPerfectMatchButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Center(
        child: GestureDetector(
          onTap: () => context.push('/perfect-match'),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome, size: 13, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'Perfect Match',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
