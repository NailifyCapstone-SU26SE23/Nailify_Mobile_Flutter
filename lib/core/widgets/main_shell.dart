// lib/core/widgets/main_shell.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  bool _hasRecommendations = false;
  String? _lastCheckedToken;
  bool _isCheckingRecommendations = false;
  bool _showNewNotificationTip = false;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
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

  bool get _hideBottomNav {
    final loc = widget.currentLocation;
    return loc.startsWith('/nails/') || loc.startsWith('/nail-variants/');
  }

  Widget _buildShellBody(Widget child) {
    return child;
  }

  @override
  Widget build(BuildContext context) {
    _checkAuthAndRecommendations();
    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppColors.background,
          appBar: widget.showHeader ? _buildHeaderAppBar(context) : null,
          body: ListenableBuilder(
            listenable: GlobalBookingManager.instance,
            builder: (context, _) {
              final manager = GlobalBookingManager.instance;
              return Column(
                children: [
                  if (manager.isHolding)
                    _buildGlobalHoldCountdownBanner(context, manager),
                  Expanded(
                    child: (widget.showHeader || _hideBottomNav)
                        ? _buildShellBody(widget.child)
                        : SafeArea(child: _buildShellBody(widget.child)),
                  ),
                ],
              );
            },
          ),
          bottomNavigationBar: _hideBottomNav ? null : _buildCustomBottomBar(context),
        ),
        if (_showNewNotificationTip)
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            right: 16,
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFFF5F8), Color(0xFFFFEBF3)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: Colors.redAccent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      S.of(context).newNotification,
                      style: const TextStyle(
                        color: AppColors.primaryDark,
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

  PreferredSizeWidget _buildHeaderAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      toolbarHeight: 52,
      titleSpacing: 16,
      flexibleSpace: Container(
        decoration: BoxDecoration(
          color: AppColors.background,
          border: Border(
            bottom: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.06),
              width: 1.0,
            ),
          ),
        ),
      ),
      title: GestureDetector(
        onTap: () => context.go('/'),
        child: Image.asset(
          'assets/images/pink.png',
          height: 28,
          fit: BoxFit.contain,
          errorBuilder: (context, error, stackTrace) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, AppColors.secondary],
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.style_rounded,
                  color: Colors.white,
                  size: 16,
                ),
              ),
              const SizedBox(width: 6),
              const Text(
                'Nailify',
                style: TextStyle(
                  fontFamily: 'Georgia',
                  color: AppColors.primaryDark,
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.3,
                ),
              ),
            ],
          ),
        ),
      ),
      actions: _isLoggedIn ? _buildLoggedInActions(context) : _buildLoggedOutActions(context),
    );
  }

  List<Widget> _buildLoggedInActions(BuildContext context) {
    return [
      Container(
        margin: const EdgeInsets.only(right: 8),
        decoration: BoxDecoration(
          color: AppColors.primarySurface.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: IconButton(
          icon: const Icon(
            Icons.camera_alt_outlined,
            color: AppColors.primary,
            size: 22,
          ),
          tooltip: 'Snapshot Try-on',
          onPressed: () => context.push('/snapshot-try-on'),
        ),
      ),
      Container(
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: AppColors.primarySurface.withValues(alpha: 0.6),
          shape: BoxShape.circle,
        ),
        child: PopupMenuButton<void>(
          offset: const Offset(0, 50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: AppColors.primary.withValues(alpha: 0.15),
              width: 1,
            ),
          ),
          color: Colors.white,
          elevation: 8,
          shadowColor: AppColors.primary.withValues(alpha: 0.2),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: Icon(
                  _hasRecommendations
                      ? Icons.notifications_active_rounded
                      : Icons.notifications_outlined,
                  color: _hasRecommendations
                      ? AppColors.primary
                      : AppColors.primaryDark,
                  size: 24,
                ),
              ),
              if (_hasRecommendations)
                Positioned(
                  right: 8,
                  top: 8,
                  child: Container(
                    width: 9,
                    height: 9,
                    decoration: BoxDecoration(
                      color: Colors.redAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
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
                  Row(
                    children: [
                      const Icon(
                        Icons.notifications_rounded,
                        color: AppColors.primary,
                        size: 18,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        S.of(context).notifications,
                        style: const TextStyle(
                          fontFamily: 'Georgia',
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Divider(
                    height: 1,
                    color: AppColors.primary.withValues(alpha: 0.12),
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
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF5F8),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.auto_awesome_rounded,
                          size: 18,
                          color: AppColors.primary,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              S.of(context).nailRecommendation,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 12.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              S.of(context).viewDetail,
                              style: const TextStyle(
                                fontSize: 11.5,
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              )
            else
              const PopupMenuItem<void>(
                enabled: false,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12.0),
                  child: Center(
                    child: Text(
                      'Không có thông báo mới.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ];
  }

  List<Widget> _buildLoggedOutActions(BuildContext context) {
    return [
      IconButton(
        icon: const Icon(
          Icons.camera_alt_outlined,
          color: AppColors.primary,
        ),
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
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: Text(
          S.of(context).login,
          style: const TextStyle(
            color: AppColors.primary,
            fontWeight: FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
      const SizedBox(width: 8),
      Container(
        decoration: BoxDecoration(
          gradient: AppColors.quizGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () => context.push('/register'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 8,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            S.of(context).register,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ),
      ),
      const SizedBox(width: 14),
    ];
  }

  Widget _buildCustomBottomBar(BuildContext context) {
    final currentIndex = _calculateCurrentIndex();
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return CustomPaint(
      size: Size(double.infinity, 66 + bottomPadding),
      painter: BottomNavPainter(bottomPadding: bottomPadding),
      child: Container(
        height: 66 + bottomPadding,
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
                    activeIcon: Icons.home_rounded,
                    label: S.of(context).home,
                    isSelected: currentIndex == 0,
                  ),
                  _buildBarItem(
                    context,
                    index: 1,
                    icon: Icons.calendar_month_outlined,
                    activeIcon: Icons.calendar_month_rounded,
                    label: S.of(context).myBooking,
                    isSelected: currentIndex == 1,
                  ),
                  const SizedBox(width: 58), // Chừa chỗ cho nút nhô lên ở giữa
                  _buildBarItem(
                    context,
                    index: 2,
                    icon: Icons.palette_outlined,
                    activeIcon: Icons.palette_rounded,
                    label: S.of(context).myStudio,
                    isSelected: currentIndex == 2,
                  ),
                  _buildBarItem(
                    context,
                    index: 3,
                    icon: Icons.person_outline_rounded,
                    activeIcon: Icons.person_rounded,
                    label: S.of(context).account,
                    isSelected: currentIndex == 3,
                  ),
                ],
              ),
            ),

            // Nút tròn nhô lên ở giữa (Shortcut đi tới màn hình đặt lịch mới /nail-booking)
            Positioned(
              top: -26,
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
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.secondary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withValues(alpha: 0.45),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                          BoxShadow(
                            color: AppColors.secondary.withValues(alpha: 0.25),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(
                          color: Colors.white,
                          width: 2.5,
                        ),
                      ),
                      child: const Icon(
                        Icons.calendar_today_rounded,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 3),
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
                        color: AppColors.primary,
                        letterSpacing: -0.2,
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
    final color = isSelected ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.7);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _onTabTapped(context, index),
      child: SizedBox(
        width: 64,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: EdgeInsets.symmetric(
                horizontal: isSelected ? 12 : 0,
                vertical: isSelected ? 4 : 0,
              ),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primarySurface.withValues(alpha: 0.8)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                isSelected ? activeIcon : icon,
                color: color,
                size: 24,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 11),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isUrgent
                ? [const Color(0xFFE53935), const Color(0xFFC62828)]
                : [const Color(0xFFF57C00), const Color(0xFFE65100)],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: (isUrgent ? Colors.red : Colors.orange).withValues(alpha: 0.3),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.25),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.timer_outlined, color: Colors.white, size: 16),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isUrgent
                    ? S.of(context).reservationMayExpireInClickToComplete(min, sec)
                    : S.of(context).slotHeldRemainingClickToReturn(min, sec),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(
              Icons.arrow_forward_ios_rounded,
              color: Colors.white,
              size: 13,
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
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, AppColors.secondary],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.auto_awesome_rounded, size: 14, color: Colors.white),
                SizedBox(width: 5),
                Text(
                  'Perfect Match',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11.5,
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
    const radiusX = 38.0;
    const radiusY = -22.0;

    path.moveTo(0, 0);
    path.lineTo(cx - radiusX, 0);

    // Tạo đường cong mái vòm hình chữ U ngược (dome) lồi lên bao quanh nút Đặt lịch
    path.cubicTo(
      cx - 20,
      0,
      cx - 18,
      radiusY,
      cx,
      radiusY,
    );
    path.cubicTo(
      cx + 18,
      radiusY,
      cx + 20,
      0,
      cx + radiusX,
      0,
    );

    path.lineTo(width, 0);
    path.lineTo(width, height);
    path.lineTo(0, height);
    path.close();

    // Vẽ bóng mờ bên ngoài
    canvas.drawPath(
      path,
      Paint()
        ..color = AppColors.primary.withValues(alpha: 0.08)
        ..maskFilter = const MaskFilter.blur(BlurStyle.outer, 10),
    );

    // Tô nền màu trắng
    canvas.drawPath(path, paint);

    // Vẽ viền mảnh màu xám nhạt chạy theo đường cong
    final borderPaint = Paint()
      ..color = AppColors.primary.withValues(alpha: 0.12)
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
