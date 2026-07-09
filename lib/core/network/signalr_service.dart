// ====================================================================
// FILE: lib/core/network/signalr_service.dart
// Mô tả: Service quản lý kết nối SignalR Hub, phát sự kiện real-time
//        ra toàn ứng dụng qua broadcast Streams.
//        Đăng ký là Singleton trong get_it.
// ====================================================================

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:signalr_netcore/signalr_client.dart';

import '../constants/app_constants.dart';
import 'signalr_events.dart';

// Hub URL ví dụ: https://nailify.onrender.com/hubs/notifications
// Backend cần xác nhận endpoint chính xác
const String _hubPath = '/notifications';

class SignalRService {
  HubConnection? _hub;
  bool _isConnected = false;

  // ─── Broadcast Streams ─────────────────────────────────────────
  final _promotedCtrl =
      StreamController<WaitlistPromotedEvent>.broadcast();
  final _expiredCtrl =
      StreamController<WaitlistExpiredEvent>.broadcast();
  final _cancelledCtrl =
      StreamController<BookingCancelledEvent>.broadcast();

  Stream<WaitlistPromotedEvent> get onWaitlistPromoted =>
      _promotedCtrl.stream;
  Stream<WaitlistExpiredEvent> get onWaitlistExpired =>
      _expiredCtrl.stream;
  Stream<BookingCancelledEvent> get onBookingCancelled =>
      _cancelledCtrl.stream;

  bool get isConnected => _isConnected;

  // ─── Kết nối Hub ─────────────────────────────────────────────
  Future<void> connect(String authToken) async {
    if (_isConnected) return;

    final hubUrl =
        AppConstants.baseUrl + _hubPath;

    _hub = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            // Bearer token được gửi qua query string (cách phổ biến với SignalR)
            accessTokenFactory: () async => authToken,
            // Sử dụng WebSockets, fallback sang SSE nếu không được
            transport: HttpTransportType.WebSockets,
            logMessageContent: kDebugMode,
          ),
        )
        .withAutomaticReconnect(
          retryDelays: [0, 2000, 5000, 10000, 30000],
        )
        .configureLogging(Logger('SignalR'))
        .build();

    // Lắng nghe sự kiện từ Hub
    _hub!.on('WaitlistPromoted', (args) {
      try {
        final payload = args?.isNotEmpty == true && args![0] is Map
            ? WaitlistPromotedEvent.fromJson(
                Map<String, dynamic>.from(args[0] as Map))
            : WaitlistPromotedEvent(
                waitlistId: '',
                message: args?.firstOrNull?.toString() ??
                    'Đã có slot trống!');
        _promotedCtrl.add(payload);
        debugPrint('[SignalR] WaitlistPromoted: ${payload.waitlistId}');
      } catch (e) {
        debugPrint('[SignalR] Lỗi parse WaitlistPromoted: $e');
      }
    });

    _hub!.on('WaitlistExpired', (args) {
      try {
        final payload = args?.isNotEmpty == true && args![0] is Map
            ? WaitlistExpiredEvent.fromJson(
                Map<String, dynamic>.from(args[0] as Map))
            : WaitlistExpiredEvent(
                message: args?.firstOrNull?.toString() ??
                    'Hàng chờ đã hết hạn.');
        _expiredCtrl.add(payload);
        debugPrint('[SignalR] WaitlistExpired');
      } catch (e) {
        debugPrint('[SignalR] Lỗi parse WaitlistExpired: $e');
      }
    });

    _hub!.on('BookingAutoCancelled', (args) {
      try {
        final payload = args?.isNotEmpty == true && args![0] is Map
            ? BookingCancelledEvent.fromJson(
                Map<String, dynamic>.from(args[0] as Map))
            : BookingCancelledEvent(
                bookingId: '',
                message: args?.firstOrNull?.toString() ??
                    'Lịch hẹn đã bị hủy tự động.');
        _cancelledCtrl.add(payload);
        debugPrint('[SignalR] BookingAutoCancelled: ${payload.bookingId}');
      } catch (e) {
        debugPrint('[SignalR] Lỗi parse BookingAutoCancelled: $e');
      }
    });

    // Sự kiện vòng đời kết nối
    _hub!.onclose(({error}) {
      _isConnected = false;
      debugPrint('[SignalR] Mất kết nối: $error');
    });

    _hub!.onreconnecting(({error}) {
      _isConnected = false;
      debugPrint('[SignalR] Đang kết nối lại...');
    });

    _hub!.onreconnected(({connectionId}) {
      _isConnected = true;
      debugPrint('[SignalR] Đã kết nối lại: $connectionId');
    });

    try {
      await _hub!.start();
      _isConnected = true;
      debugPrint('[SignalR] ✅ Đã kết nối Hub tại $hubUrl');
    } catch (e) {
      _isConnected = false;
      debugPrint('[SignalR] ❌ Lỗi kết nối Hub: $e');
    }
  }

  // ─── Ngắt kết nối Hub ──────────────────────────────────────────
  Future<void> disconnect() async {
    if (_hub != null && _isConnected) {
      await _hub!.stop();
      _isConnected = false;
      debugPrint('[SignalR] Đã ngắt kết nối Hub.');
    }
  }

  // ─── Dọn dẹp ──────────────────────────────────────────────────
  void dispose() {
    disconnect();
    _promotedCtrl.close();
    _expiredCtrl.close();
    _cancelledCtrl.close();
  }
}
