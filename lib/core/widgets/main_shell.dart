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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: const Color(0xFFFFF8FB), // Hồng ngọc trai ngọc lụa
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: 0.18),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
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
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  cleanedMessage,
                  style: const TextStyle(
                    color: Color(0xFF4A3543),
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    height: 1.38,
                  ),
                ),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(width: 10),
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    backgroundColor: color.withValues(alpha: 0.14),
                    foregroundColor: color,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
        backgroundColor: AppColors.primary,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.2),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notifications_active_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        content: Text(
          cleanedMessage,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 13.5,
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              ScaffoldMessenger.of(context).clearMaterialBanners();
              context.go('/my-bookings');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.primary,
              elevation: 0,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            child: const Text(
              'Xác nhận ngay',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12.5,
              ),
            ),
          ),
          TextButton(
            onPressed: () =>
                ScaffoldMessenger.of(context).clearMaterialBanners(),
            child: Text(
              'Đóng',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12.5,
              ),
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
                    ? 'Chỗ có thể bị hủy sau $min:$sec giây! Nhấp để hoàn tất.'
                    : 'Slot đang được giữ chỗ – còn $min:$sec để hoàn tất. Nhấp để quay lại.',
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
