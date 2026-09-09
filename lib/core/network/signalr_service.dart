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
const String _hubPath = '/notifications';

class SignalRService {
  HubConnection? _hub;
  bool _isConnected = false;

  // ─── Broadcast Streams ─────────────────────────────────────────
  final _promotedCtrl = StreamController<WaitlistPromotedEvent>.broadcast();
  final _expiredCtrl = StreamController<WaitlistExpiredEvent>.broadcast();
  final _cancelledCtrl = StreamController<BookingCancelledEvent>.broadcast();
  final _rescheduleCtrl = StreamController<BookingRescheduleEvent>.broadcast();
  final _walletPointsCtrl =
      StreamController<WalletPointsChangedEvent>.broadcast();
  final _voucherReceivedCtrl =
      StreamController<VoucherReceivedEvent>.broadcast();

  Stream<WaitlistPromotedEvent> get onWaitlistPromoted => _promotedCtrl.stream;
  Stream<WaitlistExpiredEvent> get onWaitlistExpired => _expiredCtrl.stream;
  Stream<BookingCancelledEvent> get onBookingCancelled => _cancelledCtrl.stream;
  Stream<BookingRescheduleEvent> get onBookingRescheduled =>
      _rescheduleCtrl.stream;
  Stream<WalletPointsChangedEvent> get onWalletPointsChanged =>
      _walletPointsCtrl.stream;
  Stream<VoucherReceivedEvent> get onVoucherReceived =>
      _voucherReceivedCtrl.stream;

  bool get isConnected => _isConnected;

  // ─── Kết nối Hub ─────────────────────────────────────────────
  Future<void> connect(String authToken) async {
    if (_isConnected && _hub != null) {
      debugPrint('[SignalR] Đã kết nối rồi, bỏ qua.');
      return;
    }

    if (_hub != null) {
      try {
        await _hub!.stop();
      } catch (_) {}
      _hub = null;
      _isConnected = false;
    }

    final hubUrl = AppConstants.baseUrl + _hubPath;
    debugPrint('[SignalR] Đang kết nối tới hub...');

    _hub = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => authToken,
            transport: HttpTransportType.WebSockets,
            // Chỉ log nội dung message chi tiết khi debug, không log trong release
            logMessageContent: kDebugMode,
          ),
        )
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 30000])
        .configureLogging(Logger('SignalR'))
        .build();

    // ─── Lắng nghe DUY NHẤT method chung mà backend gọi: "ReceiveNotification" ───
    // Backend gửi theo dạng: Clients.User(id).SendAsync("ReceiveNotification", eventName, payload)
    // args[0] = tên loại event (string), args[1] = payload (Map)
    _hub!.on('ReceiveNotification', (args) {
      try {
        if (args == null || args.isEmpty) return;

        final messageType = args[0]?.toString() ?? '';
        final rawPayload = args.length > 1 ? args[1] : null;
        final Map<String, dynamic>? payloadMap = rawPayload is Map
            ? Map<String, dynamic>.from(rawPayload)
            : null;

        if (kDebugMode) {
          debugPrint('[SignalR] Nhận event: $messageType');
        }

        switch (messageType) {
          case 'WaitlistPromoted':
            final payload = payloadMap != null
                ? WaitlistPromotedEvent.fromJson(payloadMap)
                : WaitlistPromotedEvent(
                    waitlistId: '',
                    message:
                        rawPayload?.toString() ??
                        'Đã có slot trống! Bạn có 15 phút để xác nhận.',
                  );
            _promotedCtrl.add(payload);
            break;

          case 'WaitlistExpired':
            final payload = payloadMap != null
                ? WaitlistExpiredEvent.fromJson(payloadMap)
                : WaitlistExpiredEvent(
                    message:
                        rawPayload?.toString() ??
                        'Thời gian xác nhận lịch hẹn từ hàng chờ (15 phút) đã hết hạn.',
                  );
            _expiredCtrl.add(payload);
            break;

          case 'BookingAutoCancelled':
            final payload = payloadMap != null
                ? BookingCancelledEvent.fromJson(payloadMap)
                : BookingCancelledEvent(
                    bookingId: '',
                    message:
                        rawPayload?.toString() ??
                        'Lịch hẹn của bạn đã tự động hủy do trễ quá 15 phút.',
                  );
            _cancelledCtrl.add(payload);
            break;

          case 'BookingRescheduleApproved':
            final payload = payloadMap != null
                ? BookingRescheduleEvent.fromJson(payloadMap, 'Approved')
                : BookingRescheduleEvent(
                    bookingId: '',
                    status: 'Approved',
                    message:
                        rawPayload?.toString() ??
                        'Yêu cầu dời lịch của bạn đã được salon xác nhận.',
                  );
            _rescheduleCtrl.add(payload);
            break;

          case 'BookingRescheduleSuggested':
            final payload = payloadMap != null
                ? BookingRescheduleEvent.fromJson(payloadMap, 'Suggested')
                : BookingRescheduleEvent(
                    bookingId: '',
                    status: 'Suggested',
                    message:
                        rawPayload?.toString() ??
                        'Salon đề xuất khung giờ hẹn mới cho bạn.',
                  );
            _rescheduleCtrl.add(payload);
            break;

          case 'BookingRescheduleRejected':
            final payload = payloadMap != null
                ? BookingRescheduleEvent.fromJson(payloadMap, 'Rejected')
                : BookingRescheduleEvent(
                    bookingId: '',
                    status: 'Rejected',
                    message:
                        rawPayload?.toString() ??
                        'Yêu cầu dời lịch của bạn không được salon chấp nhận.',
                  );
            _rescheduleCtrl.add(payload);
            break;

          case 'WalletPointsChanged':
          case 'LoyaltyPointsChanged':
            final payload = payloadMap != null
                ? WalletPointsChangedEvent.fromJson(payloadMap)
                : WalletPointsChangedEvent(
                    message:
                        rawPayload?.toString() ??
                        'Điểm của bạn đã được cập nhật.',
                  );
            _walletPointsCtrl.add(payload);
            break;

          case 'VoucherReceived':
          case 'VoucherRedeemed':
            final payload = payloadMap != null
                ? VoucherReceivedEvent.fromJson(payloadMap)
                : VoucherReceivedEvent(
                    message:
                        rawPayload?.toString() ?? 'Bạn vừa nhận một voucher.',
                  );
            _voucherReceivedCtrl.add(payload);
            break;

          default:
            if (kDebugMode) {
              debugPrint('[SignalR] messageType không xác định: $messageType');
            }
        }
      } catch (e) {
        debugPrint('[SignalR] Lỗi xử lý ReceiveNotification: $e');
      }
    });

    // Sự kiện vòng đời kết nối
    _hub!.onclose(({error}) {
      _isConnected = false;
      debugPrint('[SignalR] Mất kết nối.');
    });

    _hub!.onreconnecting(({error}) {
      _isConnected = false;
      debugPrint('[SignalR] Đang kết nối lại...');
    });

    _hub!.onreconnected(({connectionId}) {
      _isConnected = true;
      debugPrint('[SignalR] Đã kết nối lại.');
    });

    _attemptConnection();
  }

  Future<void> _attemptConnection() async {
    int attempts = 0;
    const maxAttempts = 5;

    while (!_isConnected && attempts < maxAttempts) {
      if (_hub == null) return;
      try {
        attempts++;
        await _hub!.start();
        _isConnected = true;
        debugPrint('[SignalR] ✅ Đã kết nối Hub thành công');
        return;
      } catch (e) {
        _isConnected = false;
        debugPrint('[SignalR] ❌ Thử kết nối thất bại (lần $attempts)');
        if (attempts < maxAttempts) {
          await Future.delayed(const Duration(seconds: 10));
        }
      }
    }
    debugPrint('[SignalR] ❌ Đã thử kết nối $maxAttempts lần nhưng thất bại.');
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
    _rescheduleCtrl.close();
  }
}
