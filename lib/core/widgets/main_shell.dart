// lib/core/widgets/main_shell.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/signalr_events.dart';
import '../network/signalr_service.dart';
import '../utils/auth_guard.dart';
import '../../features/nail_booking/presentation/manager/global_booking_manager.dart';

import '../constants/app_colors.dart';
import '../constants/app_constants.dart';
import '../di/injection.dart';
import '../network/api_client.dart';
import '../../features/quiz/data/datasources/quiz_repository.dart';
import '../../generated/l10n.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  final bool showHeader;
  final String currentLocation;

  const MainShell({
    super.key,
    required this.child,
    required this.currentLocation,
    this.showHeader = true,
  });

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  StreamSubscription<WaitlistPromotedEvent>? _promotedSub;
  StreamSubscription<WaitlistExpiredEvent>? _expiredSub;
  StreamSubscription<BookingCancelledEvent>? _cancelledSub;
  StreamSubscription<BookingRescheduleEvent>? _rescheduleSub;

  bool _hasRecommendations = false;
  String? _lastCheckedToken;
  bool _isCheckingRecommendations = false;
  bool _showNewNotificationTip = false;

  bool _signalRSubscribed = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Chỉ đăng ký 1 lần sau khi Scaffold tree đã sẵn sàng
    if (!_signalRSubscribed) {
      _signalRSubscribed = true;
      _subscribeToSignalR();
    }
  }

  void _triggerNotificationTip() {
    setState(() {
      _showNewNotificationTip = true;
    });
    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          _showNewNotificationTip = false;
        });
      }
    });
  }

  void _checkAuthAndRecommendations() {
    final token = getIt<SharedPreferences>().getString(
      AppConstants.authTokenKey,
    );
    final localQuizCompleted =
        getIt<SharedPreferences>().getBool('has_completed_quiz') ?? false;

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
        final bool hadRecsBefore = _hasRecommendations;
        setState(() {
          _hasRecommendations = data.isNotEmpty;
        });
        if (data.isNotEmpty) {
          getIt<SharedPreferences>().setBool('has_completed_quiz', true);
          if (!hadRecsBefore) {
            _triggerNotificationTip();
          }
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

  String _cleanNotificationMessage(String msg) {
    // 1. Loại bỏ các chuỗi hex 24 ký tự (như MongoDB ObjectId) hoặc UUID 36 ký tự, có hoặc không có dấu '#' phía trước
    final objectIdRegex = RegExp(r'#?[0-9a-fA-F]{24}');
    final uuidRegex = RegExp(
      r'#?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    );

    String cleaned = msg
        .replaceAll(uuidRegex, '')
        .replaceAll(objectIdRegex, '');

    // 2. Loại bỏ các cụm từ đi kèm nếu có (ví dụ: "mã: ", "Mã: ", "ID: ", "id: ", v.v.)
    cleaned = cleaned
        .replaceAll(RegExp(r'\(\s*[Mm]ã\s*:\s*\)'), '')
        .replaceAll(RegExp(r'\(\s*[Mm]ã\s*\)'), '')
        .replaceAll(RegExp(r'\(\s*[Ii][Dd]\s*:\s*\)'), '')
        .replaceAll(RegExp(r'\(\s*[Ii][Dd]\s*\)'), '')
        .replaceAll(RegExp(r'\(\s*\)'), '')
        .replaceAll(RegExp(r'\[\s*\]'), '')
        .replaceAll(RegExp(r'#\s*'), '');

    // 3. Chuẩn hóa khoảng trắng dư thừa
    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    // 4. Nếu kết quả thừa ký tự đặc biệt ở đầu/cuối sau khi xóa ID
    if (cleaned.startsWith(':') ||
        cleaned.startsWith('-') ||
        cleaned.startsWith(',')) {
      cleaned = cleaned.substring(1).trim();
    }

    return cleaned;
  }

  // ─── Helper: SnackBar phong cách đồng nhất, đẹp mắt dành cho phái nữ ─────────────
  void _showStyledSnackBar(
    BuildContext context, {
    required String message,
    required IconData icon,
    required Color color,
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 5),
    bool isTop = false,
  }) {
    final cleanedMessage = _cleanNotificationMessage(message);
    final mediaQuery = MediaQuery.of(context);
    final topPadding = mediaQuery.padding.top;
    final screenHeight = mediaQuery.size.height;

    final margin = isTop
        ? EdgeInsets.only(
            bottom: screenHeight - topPadding - 240,
            left: 16,
            right: 16,
          )
        : const EdgeInsets.fromLTRB(16, 0, 16, 16);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        duration: duration,
        backgroundColor: Colors.transparent,
        margin: margin,
        padding: EdgeInsets.zero,
        content: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: const Color(
              0xFFFFF8FB,
            ), // Hồng ngọc trai nhẹ, siêu nữ tính & sang trọng
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.15),
                blurRadius: 16,
                offset: const Offset(0, 6),
              ),
            ],
            border: Border.all(
              color: color.withValues(alpha: 0.35),
              width: 1.2,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  cleanedMessage,
                  style: const TextStyle(
                    color: Color(
                      0xFF4A3543,
                    ), // Màu mận/nâu sẫm ấm áp, dễ đọc trên nền hồng nhạt
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    backgroundColor: color.withValues(alpha: 0.12),
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(
                    actionLabel,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _subscribeToSignalR() {
    final signalR = getIt<SignalRService>();

    _promotedSub = signalR.onWaitlistPromoted.listen((event) {
      if (!mounted) return;
      _showWaitlistBanner(event);
    });

    _expiredSub = signalR.onWaitlistExpired.listen((event) {
      if (!mounted) return;
      _showStyledSnackBar(
        context,
        message: event.message,
        icon: Icons.hourglass_bottom_rounded,
        color: Colors.orange.shade600,
        duration: const Duration(seconds: 5),
      );
    });

    _cancelledSub = signalR.onBookingCancelled.listen((event) {
      if (!mounted) return;
      _showStyledSnackBar(
        context,
        message: event.message,
        icon: Icons.cancel_outlined,
        color: Colors.red.shade400,
        actionLabel: 'Xem lịch',
        onAction: () => context.go('/my-bookings', extra: {'initialTab': 0}),
        duration: const Duration(seconds: 6),
      );
    });

    _rescheduleSub = signalR.onBookingRescheduled.listen((event) {
      if (!mounted) return;

      Color color = AppColors.primary;
      IconData icon = Icons.edit_calendar_outlined;

      if (event.status == 'Approved') {
        color = Colors.green.shade500;
        icon = Icons.check_circle_outline_rounded;
      } else if (event.status == 'Rejected') {
        color = Colors.red.shade400;
        icon = Icons.cancel_outlined;
      } else if (event.status == 'Suggested') {
        color = Colors.amber.shade600;
        icon = Icons.event_note_rounded;
      }

      // Dùng addPostFrameCallback để chắc chắn Scaffold đã build xong
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showStyledSnackBar(
          context,
          message: event.message,
          icon: icon,
          color: color,
          actionLabel: 'Xem lịch',
          onAction: () {
            final targetTab =
                (event.status == 'Approved' || event.status == 'Rejected')
                ? 0
                : 2;
            context.go('/my-bookings', extra: {'initialTab': targetTab});
          },
          duration: const Duration(seconds: 8),
          isTop: true,
        );
      });
    });
  }

  void _showWaitlistBanner(WaitlistPromotedEvent event) {
    final cleanedMessage = _cleanNotificationMessage(event.message);
    ScaffoldMessenger.of(context).clearMaterialBanners();
    ScaffoldMessenger.of(context).showMaterialBanner(
      MaterialBanner(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        backgroundColor: AppColors.primary.withValues(alpha: 0.95),
        leading: const Icon(Icons.notifications_active, color: Colors.white),
        content: Text(
          cleanedMessage,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              ScaffoldMessenger.of(context).clearMaterialBanners();
              context.go('/my-bookings');
            },
            child: const Text(
              'Xác nhận ngay',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
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
    _rescheduleSub?.cancel();
    super.dispose();
  }

  // Biến kiểm tra trạng thái đăng nhập
  bool get _isLoggedIn {
    final token = getIt<SharedPreferences>().getString(
      AppConstants.authTokenKey,
    );
    return token != null && token.isNotEmpty;
  }

  int _calculateCurrentIndex() {
    final String location = widget.currentLocation;
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
        AuthGuard.check(context, () => context.go('/my-studio'));
        break;
      case 3:
        context.go('/profile');
        break;
    }
  }

  Widget _buildAnimatedBody(BuildContext context, Widget child) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0.015, 0.0),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        );
      },
      child: KeyedSubtree(
        key: ValueKey(GoRouterState.of(context).matchedLocation),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _checkAuthAndRecommendations();
    return Stack(
      children: [
        Scaffold(
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
                        errorBuilder: (context, error, stackTrace) =>
                            const Text(
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
                          IconButton(
                            icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                            tooltip: 'Snapshot Try-on',
                            onPressed: () => context.push('/snapshot-try-on'),
                          ),
                          PopupMenuButton<void>(
                            offset: const Offset(0, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                              side: const BorderSide(
                                color: Color(0xFFFFF0F5),
                                width: 1,
                              ),
                            ),
                            color: Colors.white,
                            elevation: 4,
                            child: Stack(
                              clipBehavior: Clip.none,
                              alignment: Alignment.center,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Icon(
                                    _hasRecommendations
                                        ? Icons.notifications_active_outlined
                                        : Icons.notifications_outlined,
                                    color: AppColors.primaryDark,
                                    size: 26,
                                  ),
                                ),
                                if (_hasRecommendations)
                                  Positioned(
                                    right: 6,
                                    top: 6,
                                    child: Container(
                                      width: 8,
                                      height: 8,
                                      decoration: const BoxDecoration(
                                        color: Colors.red,
                                        shape: BoxShape.circle,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            itemBuilder: (context) => [
                              PopupMenuItem<void>(
                                enabled: false,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      S.of(context).notifications,
                                      style: TextStyle(
                                        fontFamily: 'Georgia',
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primaryDark,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Divider(
                                      height: 1,
                                      color: Color(0xFFFFF0F5),
                                    ),
                                  ],
                                ),
                              ),
                              if (_hasRecommendations)
                                PopupMenuItem<void>(
                                  onTap: () {
                                    Future.delayed(
                                      const Duration(milliseconds: 100),
                                      () {
                                        if (context.mounted) {
                                          context.go('/perfect-match');
                                        }
                                      },
                                    );
                                  },
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(6),
                                        decoration: const BoxDecoration(
                                          color: Color(0xFFFFF5F8),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.auto_awesome_rounded,
                                          size: 16,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              S.of(context).nailRecommendation,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.bold,
                                                fontSize: 12.5,
                                                color: AppColors.textPrimary,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Text(
                                              S.of(context).viewDetail,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                const PopupMenuItem<void>(
                                  enabled: false,
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                      vertical: 8.0,
                                    ),
                                    child: Text(
                                      'Không có thông báo mới.',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: Colors.grey,
                                        fontStyle: FontStyle.italic,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(width: 12),
                        ]
                      : [
                          IconButton(
                            icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primary),
                            tooltip: 'Snapshot Try-on',
                            onPressed: () => context.push('/snapshot-try-on'),
                          ),
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                            ),
                            child: Text(
                              S.of(context).login,
                              style: const TextStyle(
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
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                            ),
                            child: Text(
                              S.of(context).register,
                              style: const TextStyle(
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
          body: ListenableBuilder(
            listenable: GlobalBookingManager.instance,
            builder: (context, _) {
              final manager = GlobalBookingManager.instance;
              return Column(
                children: [
                  if (manager.isHolding)
                    _buildGlobalHoldCountdownBanner(context, manager),
                  Expanded(
                    child: widget.showHeader
                        ? _buildAnimatedBody(context, widget.child)
                        : SafeArea(
                            child: _buildAnimatedBody(context, widget.child),
                          ),
                  ),
                ],
              );
            },
          ),

          bottomNavigationBar: _buildCustomBottomBar(context),
        ),
        if (_showNewNotificationTip)
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF5F8),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFFFFD1E3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      S.of(context).newNotification,
                      style: const TextStyle(
                        color: Color(0xFFC44569),
                        fontSize: 12.5,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCustomBottomBar(BuildContext context) {
    final currentIndex = _calculateCurrentIndex();
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return CustomPaint(
      size: Size(double.infinity, 64 + bottomPadding),
      painter: BottomNavPainter(bottomPadding: bottomPadding),
      child: Container(
        height: 64 + bottomPadding,
        color: Colors.transparent,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              bottom: bottomPadding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildBarItem(
                    context,
                    index: 0,
                    icon: Icons.home_outlined,
                    activeIcon: Icons.home,
                    label: S.of(context).home,
                    isSelected: currentIndex == 0,
                  ),
                  _buildBarItem(
                    context,
                    index: 1,
                    icon: Icons.calendar_month_outlined,
                    activeIcon: Icons.calendar_month,
                    label: S.of(context).myBooking,
                    isSelected: currentIndex == 1,
                  ),
                  const SizedBox(width: 56), // Chừa chỗ cho nút nhô lên
                  _buildBarItem(
                    context,
                    index: 2,
                    icon: Icons.palette_outlined,
                    activeIcon: Icons.palette,
                    label: S.of(context).myStudio,
                    isSelected: currentIndex == 2,
                  ),
                  _buildBarItem(
                    context,
                    index: 3,
                    icon: Icons.person_outline,
                    activeIcon: Icons.person,
                    label: S.of(context).account,
                    isSelected: currentIndex == 3,
                  ),
                ],
              ),
            ),

            // Nút tròn nhô lên ở giữa (Shortcut đi tới màn hình đặt lịch mới /nail-booking)
            Positioned(
              top: -24, // Nhô lên 24px để tạo đường cong nhô lên đẹp mắt
              left: 0,
              right: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () {
                      AuthGuard.check(context, () {
                        context.push('/nail-booking');
                      });
                    },
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.calendar_today_outlined,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                  GestureDetector(
                    onTap: () {
                      AuthGuard.check(context, () {
                        context.push('/nail-booking');
                      });
                    },
                    child: Text(
                      S.of(context).bookAppointment,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(
                          0xFFFF66C4,
                        ), // Luôn hiển thị màu hồng chủ đạo
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBarItem(
    BuildContext context, {
    required int index,
    required IconData icon,
    required IconData activeIcon,
    required String label,
    required bool isSelected,
  }) {
    final color = isSelected ? const Color(0xFFFF66C4) : Colors.grey.shade400;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTabTapped(context, index),
      child: SizedBox(
        width: 60,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(isSelected ? activeIcon : icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGlobalHoldCountdownBanner(
    BuildContext context,
    GlobalBookingManager manager,
  ) {
    final secs = manager.holdRemainingSeconds;
    final min = (secs ~/ 60).toString().padLeft(2, '0');
    final sec = (secs % 60).toString().padLeft(2, '0');
    final isUrgent = secs <= 60;
    return GestureDetector(
      onTap: () {
        final type = manager.activeBookingType;
        if (type == 'service' && manager.serviceBaseService != null) {
          context.push('/service-booking', extra: manager.serviceBaseService);
        } else if (type == 'nail') {
          context.push('/nail-booking', extra: manager.nailData);
        } else if (type == 'custom' && manager.customNail != null) {
          context.push('/custom-nail-booking', extra: manager.customNail);
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        color: isUrgent ? Colors.red.shade600 : Colors.orange.shade700,
        child: Row(
          children: [
            const Icon(Icons.lock_clock, color: Colors.white, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                isUrgent
                    ? 'Chỗ có thể bị hủy sau $min:$sec giây! Nhấp để hoàn tất.'
                    : 'Slot đang được giữ chỗ – còn $min:$sec để hoàn tất. Nhấp để quay lại.',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 12,
            ),
          ],
        ),
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
  State<BlinkingPerfectMatchButton> createState() =>
      _BlinkingPerfectMatchButtonState();
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
    _animation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
                  color: AppColors.primary.withValues(alpha: 0.3),
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

// ────────────────────────────────────────────────
// PAINTER: Vẽ nền và viền cong của thanh Bottom Bar
// ────────────────────────────────────────────────
class BottomNavPainter extends CustomPainter {
  final double bottomPadding;
  BottomNavPainter({required this.bottomPadding});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    final path = Path();
    final width = size.width;
    final height = size.height;

    final cx = width / 2;
    // Điểm cao nhất của đường cong là -20px (hướng lên trên, nằm gọn dưới đỉnh nút đặt lịch ở -24px)
    // Khoảng cách bắt đầu lượn cong từ cx - 36 đến cx + 36 (Clearance 72px bao trùm nút đặt lịch 54px)
    const radiusX = 36.0;
    const radiusY = -20.0;

    path.moveTo(0, 0);
    // Vẽ đường thẳng đến điểm bắt đầu cong
    path.lineTo(cx - radiusX, 0);

    // Tạo đường cong mái vòm hình chữ U ngược (dome) lồi lên bao quanh nút Đặt lịch
    path.cubicTo(
      cx - 20,
      0, // Điểm kiểm soát 1
      cx - 18,
      radiusY, // Điểm kiểm soát 2
      cx,
      radiusY, // Điểm cực đại phía trên cùng
    );
    path.cubicTo(
      cx + 18,
      radiusY, // Điểm kiểm soát 1
      cx + 20,
      0, // Điểm kiểm soát 2
      cx + radiusX,
      0, // Điểm kết thúc cong
    );

    path.lineTo(width, 0);
    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    // Vẽ bóng mờ bên ngoài
    canvas.drawPath(
      path,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.03)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 8),
    );

    // Tô nền màu trắng
    canvas.drawPath(path, paint);

    // Vẽ viền mảnh màu xám nhạt chạy theo đường cong
    final borderPaint = Paint()
      ..color = Colors.grey.shade200
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final borderPath = Path();
    borderPath.moveTo(0, 0);
    borderPath.lineTo(cx - radiusX, 0);
    borderPath.cubicTo(cx - 20, 0, cx - 18, radiusY, cx, radiusY);
    borderPath.cubicTo(cx + 18, radiusY, cx + 20, 0, cx + radiusX, 0);
    borderPath.lineTo(width, 0);
    canvas.drawPath(borderPath, borderPaint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}
