import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../constants/app_colors.dart';
import '../di/injection.dart';
import '../network/signalr_events.dart';
import '../network/signalr_service.dart';
import '../routing/app_router.dart';
import '../utils/price_formatter.dart';
import '../services/in_app_notification_store.dart';
import '../../features/my_booking/data/datasources/my_booking_api_service.dart';

class GlobalSignalRListener extends StatefulWidget {
  final Widget child;

  const GlobalSignalRListener({super.key, required this.child});

  @override
  State<GlobalSignalRListener> createState() => _GlobalSignalRListenerState();
}

class _GlobalSignalRListenerState extends State<GlobalSignalRListener> {
  StreamSubscription<WaitlistPromotedEvent>? _promotedSub;
  StreamSubscription<WaitlistExpiredEvent>? _expiredSub;
  StreamSubscription<BookingCancelledEvent>? _cancelledSub;
  StreamSubscription<BookingConfirmedEvent>? _confirmedSub;
  StreamSubscription<BookingRejectedEvent>? _rejectedSub;
  StreamSubscription<BookingRescheduleEvent>? _rescheduleSub;
  StreamSubscription<DelayWarningWithAutonomyEvent>? _delayWarningSub;
  StreamSubscription<DelayETAEvent>? _delayEtaSub;
  StreamSubscription<CustomNailQuotedEvent>? _customNailQuotedSub;
  StreamSubscription<CustomNailRejectedEvent>? _customNailRejectedSub;

  @override
  void initState() {
    super.initState();
    _subscribeToSignalR();
  }

  @override
  void dispose() {
    _promotedSub?.cancel();
    _expiredSub?.cancel();
    _cancelledSub?.cancel();
    _confirmedSub?.cancel();
    _rejectedSub?.cancel();
    _rescheduleSub?.cancel();
    _delayWarningSub?.cancel();
    _delayEtaSub?.cancel();
    _customNailQuotedSub?.cancel();
    _customNailRejectedSub?.cancel();
    super.dispose();
  }

  void _subscribeToSignalR() {
    final signalR = getIt<SignalRService>();
    final notificationStore = getIt<InAppNotificationStore>();

    _promotedSub = signalR.onWaitlistPromoted.listen((event) {
      notificationStore.addNotification(
        title: 'Hàng chờ có slot trống!',
        message: event.message,
        icon: Icons.notifications_active_rounded,
        color: Colors.amber.shade700,
        route: '/my-bookings',
        extra: {'initialTab': 1},
      );
    });

    _confirmedSub = signalR.onBookingConfirmed.listen((event) {
      debugPrint('[GlobalSignalRListener] 🟢 Nhận event BookingConfirmed: ${event.message}');
      notificationStore.addNotification(
        title: 'Đơn đặt lịch được duyệt',
        message: event.message,
        icon: Icons.check_circle_outline_rounded,
        color: Colors.green.shade600,
        route: '/my-bookings',
        extra: {'initialTab': 0},
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentCtx = rootNavigatorKey.currentContext ?? context;
        if (!currentCtx.mounted) return;
        _showStyledSnackBar(
          currentCtx,
          message: event.message,
          icon: Icons.check_circle_outline_rounded,
          color: Colors.green.shade600,
          actionLabel: 'Xem lịch',
          onAction: () {
            final navCtx = rootNavigatorKey.currentContext ?? context;
            if (navCtx.mounted) {
              navCtx.go('/my-bookings', extra: {'initialTab': 0});
            }
          },
          duration: const Duration(seconds: 8),
          isTop: true,
        );
      });
    });

    _rejectedSub = signalR.onBookingRejected.listen((event) {
      debugPrint('[GlobalSignalRListener] 🔴 Nhận event BookingRejected: ${event.message}');
      notificationStore.addNotification(
        title: 'Đơn đặt lịch bị từ chối',
        message: event.message,
        icon: Icons.cancel_outlined,
        color: Colors.red.shade400,
        route: '/my-bookings',
        extra: {'initialTab': 0},
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentCtx = rootNavigatorKey.currentContext ?? context;
        if (!currentCtx.mounted) return;
        _showStyledSnackBar(
          currentCtx,
          message: event.message,
          icon: Icons.cancel_outlined,
          color: Colors.red.shade400,
          actionLabel: 'Xem lịch',
          onAction: () {
            final navCtx = rootNavigatorKey.currentContext ?? context;
            if (navCtx.mounted) {
              navCtx.go('/my-bookings', extra: {'initialTab': 0});
            }
          },
          duration: const Duration(seconds: 8),
          isTop: true,
        );
      });
    });

    _expiredSub = signalR.onWaitlistExpired.listen((event) {
      notificationStore.addNotification(
        title: 'Lịch hàng chờ hết hạn',
        message: event.message,
        icon: Icons.hourglass_bottom_rounded,
        color: Colors.orange.shade600,
        route: '/my-bookings',
        extra: {'initialTab': 1},
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentCtx = rootNavigatorKey.currentContext;
        if (currentCtx == null) return;
        _showStyledSnackBar(
          currentCtx,
          message: event.message,
          icon: Icons.hourglass_bottom_rounded,
          color: Colors.orange.shade600,
          duration: const Duration(seconds: 5),
        );
      });
    });

    _cancelledSub = signalR.onBookingCancelled.listen((event) {
      notificationStore.addNotification(
        title: 'Lịch hẹn bị hủy',
        message: event.message,
        icon: Icons.cancel_outlined,
        color: Colors.red.shade400,
        route: '/my-bookings',
        extra: {'initialTab': 0},
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentCtx = rootNavigatorKey.currentContext;
        if (currentCtx == null) return;
        _showStyledSnackBar(
          currentCtx,
          message: event.message,
          icon: Icons.cancel_outlined,
          color: Colors.red.shade400,
          actionLabel: 'Xem lịch',
          onAction: () {
            final navCtx = rootNavigatorKey.currentContext;
            if (navCtx != null) {
              navCtx.go('/my-bookings', extra: {'initialTab': 0});
            }
          },
          duration: const Duration(seconds: 6),
        );
      });
    });

    _rescheduleSub = signalR.onBookingRescheduled.listen((event) {
      Color color = AppColors.primary;
      IconData icon = Icons.edit_calendar_outlined;
      String title = 'Cập nhật dời lịch hẹn';

      if (event.status == 'Approved') {
        color = Colors.green.shade500;
        icon = Icons.check_circle_outline_rounded;
        title = 'Chấp nhận dời lịch';
      } else if (event.status == 'Rejected') {
        color = Colors.red.shade400;
        icon = Icons.cancel_outlined;
        title = 'Từ chối dời lịch';
      } else if (event.status == 'Suggested') {
        color = Colors.amber.shade600;
        icon = Icons.event_note_rounded;
        title = 'Đề xuất dời lịch mới';
      }

      final targetTab =
          (event.status == 'Approved' || event.status == 'Rejected') ? 0 : 2;

      notificationStore.addNotification(
        title: title,
        message: event.message,
        icon: icon,
        color: color,
        route: '/my-bookings',
        extra: {'initialTab': targetTab},
      );

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final currentCtx = rootNavigatorKey.currentContext;
        if (currentCtx == null) return;
        _showStyledSnackBar(
          currentCtx,
          message: event.message,
          icon: icon,
          color: color,
          actionLabel: 'Xem lịch',
          onAction: () {
            currentCtx.go('/my-bookings', extra: {'initialTab': targetTab});
          },
          duration: const Duration(seconds: 8),
          isTop: true,
        );
      });
    });

    _delayEtaSub = signalR.onDelayETA.listen((event) {
      notificationStore.addNotification(
        title: 'Cập nhật thời gian dự kiến',
        message: event.message,
        icon: Icons.access_time_filled_rounded,
        color: Colors.amber.shade700,
        route: '/my-bookings',
        extra: {'initialTab': 0},
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = rootNavigatorKey.currentContext;
        if (context == null) return;
        _showStyledSnackBar(
          context,
          message: event.message,
          icon: Icons.access_time_filled_rounded,
          color: Colors.amber.shade700,
          duration: const Duration(seconds: 8),
          isTop: true,
        );
      });
    });

    _delayWarningSub = signalR.onDelayWarningWithAutonomy.listen((event) {
      notificationStore.addNotification(
        title: 'Cảnh báo trễ ca lịch hẹn',
        message: event.message,
        icon: Icons.warning_amber_rounded,
        color: Colors.amber.shade800,
        route: '/my-bookings',
        extra: {'initialTab': 0},
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = rootNavigatorKey.currentContext;
        if (context == null) return;
        _showDelayWarningBottomSheet(context, event);
      });
    });

    _customNailQuotedSub = signalR.onCustomNailQuoted.listen((event) {
      final route = event.customerNailRequestId.isNotEmpty
          ? '/my-studio/${event.customerNailRequestId}'
          : '/my-studio';
      notificationStore.addNotification(
        title: 'Báo giá mẫu Nail Custom',
        message: event.message,
        icon: Icons.monetization_on_rounded,
        color: Colors.amber.shade800,
        route: route,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = rootNavigatorKey.currentContext;
        if (context == null) return;
        _showCustomNailQuotedDialog(context, event);
      });
    });

    _customNailRejectedSub = signalR.onCustomNailRejected.listen((event) {
      final route = event.customerNailRequestId.isNotEmpty
          ? '/my-studio/${event.customerNailRequestId}'
          : '/my-studio';
      notificationStore.addNotification(
        title: 'Mẫu Nail Custom bị từ chối',
        message: event.message,
        icon: Icons.cancel_outlined,
        color: Colors.red.shade600,
        route: route,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final context = rootNavigatorKey.currentContext;
        if (context == null) return;
        _showCustomNailRejectedDialog(context, event);
      });
    });
  }

  String _cleanNotificationMessage(String msg) {
    final objectIdRegex = RegExp(r'#?[0-9a-fA-F]{24}');
    final uuidRegex = RegExp(
      r'#?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    );

    String cleaned = msg
        .replaceAll(uuidRegex, '')
        .replaceAll(objectIdRegex, '');

    cleaned = cleaned
        .replaceAll(RegExp(r'\(\s*[Mm]ã\s*:\s*\)'), '')
        .replaceAll(RegExp(r'\(\s*[Mm]ã\s*\)'), '')
        .replaceAll(RegExp(r'\(\s*[Ii][Dd]\s*:\s*\)'), '')
        .replaceAll(RegExp(r'\(\s*[Ii][Dd]\s*\)'), '')
        .replaceAll(RegExp(r'\(\s*\)'), '')
        .replaceAll(RegExp(r'\[\s*\]'), '');

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ').trim();

    if (cleaned.startsWith(':') ||
        cleaned.startsWith('-') ||
        cleaned.startsWith(',')) {
      cleaned = cleaned.substring(1).trim();
    }

    return cleaned;
  }

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
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) {
      debugPrint('[GlobalSignalRListener] ❌ ScaffoldMessenger not found in context!');
      return;
    }

    final mediaQuery = MediaQuery.maybeOf(context);
    final topPadding = mediaQuery?.padding.top ?? 24.0;
    final screenHeight = mediaQuery?.size.height ?? 800.0;

    final double bottomMargin = isTop
        ? (screenHeight - topPadding - 220).clamp(50.0, (screenHeight - 140).clamp(50.0, 1000.0))
        : 16.0;

    final margin = isTop
        ? EdgeInsets.only(
            bottom: bottomMargin,
            left: 16,
            right: 16,
          )
        : const EdgeInsets.fromLTRB(16, 0, 16, 16);

    try {
      messenger.showSnackBar(
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
            color: const Color(0xFFFFF8FB),
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
    } catch (e) {
      debugPrint('[GlobalSignalRListener] ❌ Hiển thị SnackBar bị lỗi: $e');
    }
  }

  void _showCustomNailQuotedDialog(
    BuildContext context,
    CustomNailQuotedEvent event,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.monetization_on_rounded,
              color: Colors.amber.shade800,
              size: 36,
            ),
          ),
          title: const Text(
            'Salon đã gửi Báo Giá!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A3543),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _cleanNotificationMessage(event.message),
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, color: Colors.black87),
              ),
              if (event.price > 0 || event.duration > 0) ...[
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.amber.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.amber.shade200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      if (event.price > 0)
                        Column(
                          children: [
                            const Text(
                              'Giá đề xuất',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              PriceFormatter.format(event.price),
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.amber.shade900,
                              ),
                            ),
                          ],
                        ),
                      if (event.duration > 0)
                        Column(
                          children: [
                            const Text(
                              'Thời gian dự kiến',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${event.duration} phút',
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF4A3543),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Text(
                'Bạn có muốn Đồng ý hoặc Từ chối mức giá này không?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey.shade700,
                ),
              ),
            ],
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Để sau', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (event.customerNailRequestId.isNotEmpty) {
                  context.push('/my-studio/${event.customerNailRequestId}');
                } else {
                  context.go('/my-studio');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Xem & Phản hồi giá'),
            ),
          ],
        );
      },
    );
  }

  void _showCustomNailRejectedDialog(
    BuildContext context,
    CustomNailRejectedEvent event,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          icon: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.cancel_outlined,
              color: Colors.red.shade600,
              size: 36,
            ),
          ),
          title: const Text(
            'Mẫu nail custom bị từ chối',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Color(0xFF4A3543),
            ),
          ),
          content: Text(
            _cleanNotificationMessage(event.message),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: Colors.black87),
          ),
          actionsAlignment: MainAxisAlignment.spaceEvenly,
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Đóng', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                if (event.customerNailRequestId.isNotEmpty) {
                  context.push('/my-studio/${event.customerNailRequestId}');
                } else {
                  context.go('/my-studio');
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Xem chi tiết'),
            ),
          ],
        );
      },
    );
  }

  void _showDelayWarningBottomSheet(
    BuildContext context,
    DelayWarningWithAutonomyEvent event,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (modalContext) {
        bool isLoading = false;

        return StatefulBuilder(
          builder: (builderCtx, setModalState) {
            Future<void> handleDecision(
              int decision, {
              String? newDate,
              String? newTime,
            }) async {
              setModalState(() => isLoading = true);
              final api = getIt<MyBookingApiService>();
              final res = await api.respondToDelay(
                event.bookingId,
                customerDecision: decision,
                newDate: newDate,
                newTime: newTime,
              );
              setModalState(() => isLoading = false);

              final currentCtx = rootNavigatorKey.currentContext;
              if (builderCtx.mounted && currentCtx != null) {
                Navigator.of(builderCtx).pop();
                final isOk = res['success'] == true;
                _showStyledSnackBar(
                  currentCtx,
                  message: res['message']?.toString() ?? '',
                  icon: isOk
                      ? Icons.check_circle_rounded
                      : Icons.error_outline_rounded,
                  color: isOk ? Colors.green.shade600 : Colors.red.shade400,
                  duration: const Duration(seconds: 6),
                  isTop: true,
                );
              }
            }

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade50,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.warning_amber_rounded,
                            color: Colors.amber.shade800,
                            size: 28,
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Text(
                            'Thông Báo Trễ Ca Lịch Hẹn',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _cleanNotificationMessage(event.message),
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade700,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (isLoading)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: CircularProgressIndicator(),
                      )
                    else ...[
                      if (event.options.contains('WAIT'))
                        ElevatedButton.icon(
                          onPressed: () => handleDecision(1),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          icon: const Icon(Icons.check_circle_outline),
                          label: const Text('Tôi đồng ý chờ thêm'),
                        ),
                    ],
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
