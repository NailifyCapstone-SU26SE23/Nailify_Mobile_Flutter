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
  final _bookingConfirmedCtrl =
      StreamController<BookingConfirmedEvent>.broadcast();
  final _bookingRejectedCtrl =
      StreamController<BookingRejectedEvent>.broadcast();
  final _rescheduleCtrl = StreamController<BookingRescheduleEvent>.broadcast();
  final _walletPointsCtrl =
      StreamController<WalletPointsChangedEvent>.broadcast();
  final _voucherReceivedCtrl =
      StreamController<VoucherReceivedEvent>.broadcast();
  final _delayWarningCtrl =
      StreamController<DelayWarningWithAutonomyEvent>.broadcast();
  final _delayEtaCtrl = StreamController<DelayETAEvent>.broadcast();
  final _customNailQuotedCtrl =
      StreamController<CustomNailQuotedEvent>.broadcast();
  final _customNailRejectedCtrl =
      StreamController<CustomNailRejectedEvent>.broadcast();
  final _slotStatusChangedCtrl = StreamController<SlotStatusChangedEvent>.broadcast();
  final _artistReassignedCtrl =
      StreamController<ArtistReassignedEvent>.broadcast();

  Stream<WaitlistPromotedEvent> get onWaitlistPromoted => _promotedCtrl.stream;
  Stream<WaitlistExpiredEvent> get onWaitlistExpired => _expiredCtrl.stream;
  Stream<BookingCancelledEvent> get onBookingCancelled => _cancelledCtrl.stream;
  Stream<BookingConfirmedEvent> get onBookingConfirmed =>
      _bookingConfirmedCtrl.stream;
  Stream<BookingRejectedEvent> get onBookingRejected =>
      _bookingRejectedCtrl.stream;
  Stream<BookingRescheduleEvent> get onBookingRescheduled =>
      _rescheduleCtrl.stream;
  Stream<WalletPointsChangedEvent> get onWalletPointsChanged =>
      _walletPointsCtrl.stream;
  Stream<VoucherReceivedEvent> get onVoucherReceived =>
      _voucherReceivedCtrl.stream;
  Stream<DelayWarningWithAutonomyEvent> get onDelayWarningWithAutonomy =>
      _delayWarningCtrl.stream;
  Stream<DelayETAEvent> get onDelayETA => _delayEtaCtrl.stream;
  Stream<CustomNailQuotedEvent> get onCustomNailQuoted =>
      _customNailQuotedCtrl.stream;
  Stream<CustomNailRejectedEvent> get onCustomNailRejected =>
      _customNailRejectedCtrl.stream;
  Stream<SlotStatusChangedEvent> get onSlotStatusChanged => _slotStatusChangedCtrl.stream;
  Stream<ArtistReassignedEvent> get onArtistReassigned =>
      _artistReassignedCtrl.stream;

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

    final cleanBaseUrl = AppConstants.baseUrl.endsWith('/')
        ? AppConstants.baseUrl.substring(0, AppConstants.baseUrl.length - 1)
        : AppConstants.baseUrl;
    final hubUrl = '$cleanBaseUrl$_hubPath';
    debugPrint('[SignalR] Đang kết nối tới hub: $hubUrl...');

    _hub = HubConnectionBuilder()
        .withUrl(
          hubUrl,
          options: HttpConnectionOptions(
            accessTokenFactory: () async => authToken,
            requestTimeout: 30000,
            // Không ép cứng WebSockets để tự động fallback khi host trên Render.com
            logMessageContent: kDebugMode,
          ),
        )
        .withAutomaticReconnect(retryDelays: [0, 2000, 5000, 10000, 30000])
        .configureLogging(Logger('SignalR'))
        .build();

    // ─── Lắng nghe DUY NHẤT method chung mà backend gọi: "ReceiveNotification" ───
    // Backend gửi theo dạng: Clients.User(id).SendAsync("ReceiveNotification", eventName, payload)
    // Hoặc SendAsync("ReceiveNotification", payload)
    _hub!.on('ReceiveNotification', (args) {
      try {
        if (args == null || args.isEmpty) return;

        String messageType = '';
        dynamic rawPayload;
        Map<String, dynamic>? payloadMap;

        if (args.length == 1) {
          if (args[0] is Map) {
            payloadMap = Map<String, dynamic>.from(args[0] as Map);
            messageType = (payloadMap['type'] ??
                    payloadMap['Type'] ??
                    payloadMap['title'] ??
                    payloadMap['Title'] ??
                    payloadMap['eventName'] ??
                    payloadMap['EventName'] ??
                    '')
                .toString();
            rawPayload = payloadMap;
          } else {
            messageType = args[0]?.toString() ?? '';
            rawPayload = args[0];
          }
        } else {
          messageType = args[0]?.toString() ?? '';
          rawPayload = args[1];
          if (rawPayload is Map) {
            payloadMap = Map<String, dynamic>.from(rawPayload);
          }
        }

        if (kDebugMode) {
          debugPrint('[SignalR] Nhận event: type="$messageType", rawPayload=$rawPayload');
        }

        final lowerType = messageType.toLowerCase().trim();
        final isArtistReassigned = lowerType.contains('đổi thợ') ||
            lowerType.contains('doi tho') ||
            lowerType.contains('chuyển thợ') ||
            lowerType.contains('chuyen tho') ||
            lowerType.contains('reassign') ||
            lowerType.contains('artistreassigned');

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

          case 'Thông báo Hủy lịch hẹn':
          case 'BookingCancelled':
          case 'BOOKING_CANCELLED':
          case 'booking_cancelled':
          case 'BookingCancelledEvent':
          case 'BookingAutoCancelled':
            final messageText = (payloadMap?['message'] ??
                    payloadMap?['Message'] ??
                    rawPayload?.toString())
                ?.toString();
            final payload = payloadMap != null
                ? BookingCancelledEvent.fromJson(payloadMap)
                : BookingCancelledEvent(
                    bookingId: payloadMap?['bookingId']?.toString() ??
                        payloadMap?['BookingId']?.toString() ??
                        '',
                    bookingCode: payloadMap?['bookingCode']?.toString() ??
                        payloadMap?['BookingCode']?.toString(),
                    salonName: payloadMap?['salonName']?.toString() ??
                        payloadMap?['SalonName']?.toString(),
                    customerName: payloadMap?['customerName']?.toString() ??
                        payloadMap?['CustomerName']?.toString(),
                    reason: payloadMap?['reason']?.toString() ??
                        payloadMap?['Reason']?.toString(),
                    message: (messageText != null && messageText.isNotEmpty)
                        ? messageText
                        : 'Lịch hẹn đã bị hủy.',
                  );
            debugPrint('[SignalR] 🔴 Phá sóng Hủy lịch: ${payload.message}');
            _cancelledCtrl.add(payload);
            break;

          case 'BookingConfirmed':
          case 'BOOKING_CONFIRMED':
          case 'booking_confirmed':
          case 'BookingConfirmedEvent':
            final messageText = (payloadMap?['message'] ??
                    payloadMap?['Message'] ??
                    rawPayload?.toString())
                ?.toString();
            final payload = payloadMap != null
                ? BookingConfirmedEvent.fromJson(payloadMap)
                : BookingConfirmedEvent(
                    bookingId: payloadMap?['bookingId']?.toString() ??
                        payloadMap?['BookingId']?.toString() ??
                        '',
                    message: (messageText != null && messageText.isNotEmpty)
                        ? messageText
                        : 'Đơn đặt lịch của bạn đã được Salon xác nhận.',
                  );
            debugPrint(
                '[SignalR] 🟢 Phá sóng BookingConfirmed: ${payload.message}');
            _bookingConfirmedCtrl.add(payload);
            break;

          case 'BookingRejected':
          case 'BOOKING_REJECTED':
          case 'booking_rejected':
          case 'BookingRejectedEvent':
            final messageText = (payloadMap?['message'] ??
                    payloadMap?['Message'] ??
                    rawPayload?.toString())
                ?.toString();
            final payload = payloadMap != null
                ? BookingRejectedEvent.fromJson(payloadMap)
                : BookingRejectedEvent(
                    bookingId: payloadMap?['bookingId']?.toString() ??
                        payloadMap?['BookingId']?.toString() ??
                        '',
                    bookingCode: payloadMap?['bookingCode']?.toString() ??
                        payloadMap?['BookingCode']?.toString(),
                    salonName: payloadMap?['salonName']?.toString() ??
                        payloadMap?['SalonName']?.toString(),
                    customerName: payloadMap?['customerName']?.toString() ??
                        payloadMap?['CustomerName']?.toString(),
                    reason: payloadMap?['reason']?.toString() ??
                        payloadMap?['Reason']?.toString(),
                    message: (messageText != null && messageText.isNotEmpty)
                        ? messageText
                        : 'Đơn đặt lịch của bạn đã bị Salon từ chối.',
                  );
            debugPrint(
                '[SignalR] 🔴 Phá sóng BookingRejected: ${payload.message}');
            _bookingRejectedCtrl.add(payload);
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

          case 'Đề xuất thay đổi giờ hẹn':
          case 'BookingRescheduleSuggested':
            final messageText = (payloadMap?['message'] ??
                    payloadMap?['Message'] ??
                    rawPayload?.toString())
                ?.toString();
            final payload = payloadMap != null
                ? BookingRescheduleEvent.fromJson(payloadMap, 'Suggested')
                : BookingRescheduleEvent(
                    bookingId: payloadMap?['bookingId']?.toString() ??
                        payloadMap?['BookingId']?.toString() ??
                        '',
                    status: 'Suggested',
                    message: (messageText != null && messageText.isNotEmpty)
                        ? messageText
                        : 'Salon đề xuất dời lịch của bạn.',
                  );
            debugPrint('[SignalR] 🟠 Phá sóng Đề xuất dời lịch: ${payload.message}');
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

          case 'DelayWarningWithAutonomy':
            final payload = payloadMap != null
                ? DelayWarningWithAutonomyEvent.fromJson(payloadMap)
                : DelayWarningWithAutonomyEvent(
                    bookingId: '',
                    message:
                        rawPayload?.toString() ??
                        'Lịch hẹn của bạn có thể bị trễ. Vui lòng chọn hướng xử lý.',
                    options: const ['WAIT', 'REASSIGN', 'RESCHEDULE'],
                  );
            _delayWarningCtrl.add(payload);
            break;

          case 'DelayETA':
            final payload = payloadMap != null
                ? DelayETAEvent.fromJson(payloadMap)
                : DelayETAEvent(
                    message:
                        rawPayload?.toString() ?? 'Thông báo trễ lịch hẹn.',
                  );
            _delayEtaCtrl.add(payload);
            break;

          case 'CUSTOM_NAIL_QUOTED':
            final payload = payloadMap != null
                ? CustomNailQuotedEvent.fromJson(payloadMap)
                : CustomNailQuotedEvent(
                    customerNailRequestId: '',
                    customerNailId: '',
                    price: 0,
                    duration: 0,
                    message:
                        rawPayload?.toString() ??
                        'Salon đã gửi báo giá cho mẫu nail custom của bạn!',
                  );
            _customNailQuotedCtrl.add(payload);
            break;

          case 'CUSTOM_NAIL_REJECTED':
            final payload = payloadMap != null
                ? CustomNailRejectedEvent.fromJson(payloadMap)
                : CustomNailRejectedEvent(
                    customerNailRequestId: '',
                    reason: '',
                    message:
                        rawPayload?.toString() ??
                        'Mẫu nail custom của bạn đã bị salon từ chối.',
                  );
            _customNailRejectedCtrl.add(payload);
            break;

          case 'Thông báo đổi thợ phụ trách':
          case 'Thông báo thay đổi thợ phụ trách':
          case 'ArtistReassigned':
          case 'ARTIST_REASSIGNED':
          case 'artist_reassigned':
          case 'ArtistReassignedEvent':
            final messageText = (payloadMap?['message'] ??
                    payloadMap?['Message'] ??
                    rawPayload?.toString())
                ?.toString();
            final payload = payloadMap != null
                ? ArtistReassignedEvent.fromJson(payloadMap)
                : ArtistReassignedEvent(
                    bookingId: payloadMap?['bookingId']?.toString() ??
                        payloadMap?['BookingId']?.toString() ??
                        '',
                    newArtistName: payloadMap?['newArtistName']?.toString() ??
                        payloadMap?['NewArtistName']?.toString() ??
                        'Thợ mới',
                    message: (messageText != null && messageText.isNotEmpty)
                        ? messageText
                        : 'Lịch hẹn của bạn đã được chuyển sang thợ làm móng mới.',
                  );
            debugPrint(
                '[SignalR] 🔵 Phá sóng ArtistReassigned: ${payload.message}');
            _artistReassignedCtrl.add(payload);
            break;

          case 'SlotStatusChanged':
            if (payloadMap != null) {
              _slotStatusChangedCtrl.add(SlotStatusChangedEvent.fromJson(payloadMap));
            }
            break;

          default:
            if (isArtistReassigned) {
              final messageText = (payloadMap?['message'] ??
                      payloadMap?['Message'] ??
                      rawPayload?.toString())
                  ?.toString();
              final payload = payloadMap != null
                  ? ArtistReassignedEvent.fromJson(payloadMap)
                  : ArtistReassignedEvent(
                      bookingId: payloadMap?['bookingId']?.toString() ??
                          payloadMap?['BookingId']?.toString() ??
                          '',
                      newArtistName: payloadMap?['newArtistName']?.toString() ??
                          payloadMap?['NewArtistName']?.toString() ??
                          'Thợ mới',
                      message: (messageText != null && messageText.isNotEmpty)
                          ? messageText
                          : 'Lịch hẹn của bạn đã được chuyển sang thợ làm móng mới.',
                    );
              debugPrint(
                  '[SignalR] 🔵 Phá sóng ArtistReassigned (Pattern match): ${payload.message}');
              _artistReassignedCtrl.add(payload);
            } else if (kDebugMode) {
              debugPrint('[SignalR] messageType không xác định: $messageType');
            }
        }
      } catch (e) {
        debugPrint('[SignalR] Lỗi xử lý ReceiveNotification: $e');
      }
    });

    // Lắng nghe trực tiếp method "ArtistReassigned" hoặc "Thông báo đổi thợ phụ trách" nếu backend bắn trực tiếp
    void handleDirectArtistReassigned(List<Object?>? args, String eventTag) {
      try {
        if (args == null || args.isEmpty) return;
        final rawData = args[0];
        final Map<String, dynamic>? payloadMap = rawData is Map
            ? Map<String, dynamic>.from(rawData)
            : null;
        final messageText = payloadMap?['message']?.toString() ??
            payloadMap?['Message'] ??
            rawData?.toString() ??
            'Lịch hẹn của bạn đã được chuyển sang thợ làm móng mới.';
        final payload = payloadMap != null
            ? ArtistReassignedEvent.fromJson(payloadMap)
            : ArtistReassignedEvent(
                bookingId: '',
                newArtistName: 'Thợ mới',
                message: messageText.toString(),
              );
        debugPrint(
            '[SignalR] 🔵 Phá sóng $eventTag (Direct): ${payload.message}');
        _artistReassignedCtrl.add(payload);
      } catch (e) {
        debugPrint('[SignalR] Lỗi xử lý $eventTag direct: $e');
      }
    }

    _hub!.on('ArtistReassigned', (args) => handleDirectArtistReassigned(args, 'ArtistReassigned'));
    _hub!.on('Thông báo đổi thợ phụ trách', (args) => handleDirectArtistReassigned(args, 'Thông báo đổi thợ phụ trách'));
    _hub!.on('Thông báo thay đổi thợ phụ trách', (args) => handleDirectArtistReassigned(args, 'Thông báo thay đổi thợ phụ trách'));
    _hub!.on('ARTIST_REASSIGNED', (args) => handleDirectArtistReassigned(args, 'ARTIST_REASSIGNED'));
    _hub!.on('artist_reassigned', (args) => handleDirectArtistReassigned(args, 'artist_reassigned'));

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
        debugPrint('[SignalR] ❌ Thử kết nối thất bại (lần $attempts): $e');
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
    _bookingConfirmedCtrl.close();
    _bookingRejectedCtrl.close();
    _rescheduleCtrl.close();
    _walletPointsCtrl.close();
    _voucherReceivedCtrl.close();
    _delayWarningCtrl.close();
    _delayEtaCtrl.close();
    _customNailQuotedCtrl.close();
    _customNailRejectedCtrl.close();
    _slotStatusChangedCtrl.close();
    _artistReassignedCtrl.close();
  }
}
