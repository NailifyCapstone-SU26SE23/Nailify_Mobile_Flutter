// ====================================================================
// FILE: lib/core/network/signalr_events.dart
// Mô tả: Models cho các sự kiện real-time từ SignalR Hub
// ====================================================================

String? _cleanSignalRReason(String? rawReason) {
  if (rawReason == null) return null;
  final trimmed = rawReason.trim();
  if (trimmed.isEmpty) return trimmed;
  final lower = trimmed.toLowerCase();
  if (lower == 'no_response' || lower == 'noresponse') {
    return 'Khách hàng không phản hồi';
  }
  if (lower == 'no_artist' || lower == 'no_artist_available') {
    return 'Không tìm thấy thợ phù hợp';
  }
  var cleaned = trimmed
      .replaceAll(RegExp(r'\b(salon)(\s+salon)+\b', caseSensitive: false), 'Salon')
      .replaceAll(RegExp(r'\b(tiệm)(\s+tiệm)+\b', caseSensitive: false), 'Tiệm')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return cleaned;
}

String _cleanSignalRMessage(String? rawMsg, String fallback) {
  if (rawMsg == null || rawMsg.trim().isEmpty) return fallback;
  var msg = rawMsg.trim();

  final objectIdRegex = RegExp(r'#?[0-9a-fA-F]{24}');
  final uuidRegex = RegExp(
    r'#?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
  );

  msg = msg.replaceAll(uuidRegex, '').replaceAll(objectIdRegex, '');

  msg = msg
      .replaceAll(RegExp(r'\bno_response\b', caseSensitive: false), 'Khách hàng không phản hồi')
      .replaceAll(RegExp(r'\bNO_RESPONSE\b', caseSensitive: false), 'Khách hàng không phản hồi')
      .replaceAll(RegExp(r'\bnoresponse\b', caseSensitive: false), 'Khách hàng không phản hồi')
      .replaceAll(RegExp(r'\bno_artist\b', caseSensitive: false), 'Không có thợ phù hợp')
      .replaceAll(RegExp(r'\bno_artist_available\b', caseSensitive: false), 'Không có thợ phù hợp');

  // Xóa lặp từ: "Salon salon", "Salon Salon", "salon salon", "Tiệm tiệm"
  msg = msg
      .replaceAll(RegExp(r'\b(salon)(\s+salon)+\b', caseSensitive: false), 'Salon')
      .replaceAll(RegExp(r'\b(tiệm)(\s+tiệm)+\b', caseSensitive: false), 'Tiệm');

  msg = msg
      .replaceAll(RegExp(r'\(\s*[Mm]ã\s*:\s*\)'), '')
      .replaceAll(RegExp(r'\(\s*[Mm]ã\s*\)'), '')
      .replaceAll(RegExp(r'\(\s*[Ii][Dd]\s*:\s*\)'), '')
      .replaceAll(RegExp(r'\(\s*[Ii][Dd]\s*\)'), '')
      .replaceAll(RegExp(r'\(\s*\)'), '')
      .replaceAll(RegExp(r'\[\s*\]'), '');

  msg = msg.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (msg.startsWith(':') || msg.startsWith('-') || msg.startsWith(',')) {
    msg = msg.substring(1).trim();
  }
  return msg.isEmpty ? fallback : msg;
}

/// Sự kiện: Hàng chờ được đôn lên — có slot trống, user có 15 phút để xác nhận
class WaitlistPromotedEvent {
  final String waitlistId;
  final DateTime? expiresAt; // Thời hạn xác nhận (15 phút)
  final String message;

  const WaitlistPromotedEvent({
    required this.waitlistId,
    this.expiresAt,
    required this.message,
  });

  factory WaitlistPromotedEvent.fromJson(Map<String, dynamic> json) {
    return WaitlistPromotedEvent(
      waitlistId: json['waitlistId']?.toString() ?? '',
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      message: _cleanSignalRMessage(
        json['message']?.toString(),
        'Đã có slot trống! Bạn có 15 phút để xác nhận.',
      ),
    );
  }
}

/// Sự kiện: Hàng chờ hết hạn — quá 15 phút chưa xác nhận
class WaitlistExpiredEvent {
  final String? waitlistId;
  final String message;

  const WaitlistExpiredEvent({this.waitlistId, required this.message});

  factory WaitlistExpiredEvent.fromJson(Map<String, dynamic> json) {
    return WaitlistExpiredEvent(
      waitlistId: json['waitlistId']?.toString(),
      message: _cleanSignalRMessage(
        json['message']?.toString(),
        'Thời gian xác nhận lịch hẹn từ hàng chờ (15 phút) đã hết hạn.',
      ),
    );
  }
}

/// Sự kiện: Lịch hẹn bị hủy (Khách hủy hoặc Salon/Hệ thống hủy)
class BookingCancelledEvent {
  final String bookingId;
  final String? bookingCode;
  final String? salonName;
  final String? customerName;
  final String? reason;
  final String message;

  const BookingCancelledEvent({
    required this.bookingId,
    this.bookingCode,
    this.salonName,
    this.customerName,
    this.reason,
    required this.message,
  });

  factory BookingCancelledEvent.fromJson(Map<String, dynamic> json) {
    return BookingCancelledEvent(
      bookingId: json['bookingId']?.toString() ?? json['BookingId']?.toString() ?? '',
      bookingCode: json['bookingCode']?.toString() ?? json['BookingCode']?.toString(),
      salonName: json['salonName']?.toString() ?? json['SalonName']?.toString(),
      customerName: json['customerName']?.toString() ?? json['CustomerName']?.toString(),
      reason: _cleanSignalRReason(json['reason']?.toString() ?? json['Reason']?.toString()),
      message: _cleanSignalRMessage(
        json['message']?.toString() ?? json['Message']?.toString(),
        'Lịch hẹn đã bị hủy.',
      ),
    );
  }
}

/// Sự kiện: Đơn đặt lịch được Salon xác nhận/duyệt
class BookingConfirmedEvent {
  final String bookingId;
  final String message;

  const BookingConfirmedEvent({
    required this.bookingId,
    required this.message,
  });

  factory BookingConfirmedEvent.fromJson(Map<String, dynamic> json) {
    return BookingConfirmedEvent(
      bookingId:
          json['bookingId']?.toString() ?? json['BookingId']?.toString() ?? '',
      message: _cleanSignalRMessage(
        json['message']?.toString() ?? json['Message']?.toString(),
        'Đơn đặt lịch của bạn đã được Salon xác nhận.',
      ),
    );
  }
}

/// Sự kiện: Đơn đặt lịch bị Salon từ chối
class BookingRejectedEvent {
  final String bookingId;
  final String? bookingCode;
  final String? salonName;
  final String? customerName;
  final String? reason;
  final String message;

  const BookingRejectedEvent({
    required this.bookingId,
    this.bookingCode,
    this.salonName,
    this.customerName,
    this.reason,
    required this.message,
  });

  factory BookingRejectedEvent.fromJson(Map<String, dynamic> json) {
    return BookingRejectedEvent(
      bookingId:
          json['bookingId']?.toString() ?? json['BookingId']?.toString() ?? '',
      bookingCode:
          json['bookingCode']?.toString() ?? json['BookingCode']?.toString(),
      salonName:
          json['salonName']?.toString() ?? json['SalonName']?.toString(),
      customerName:
          json['customerName']?.toString() ?? json['CustomerName']?.toString(),
      reason: _cleanSignalRReason(json['reason']?.toString() ?? json['Reason']?.toString()),
      message: _cleanSignalRMessage(
        json['message']?.toString() ?? json['Message']?.toString(),
        'Đơn đặt lịch của bạn đã bị Salon từ chối.',
      ),
    );
  }
}

/// Sự kiện: Liên quan đến dời lịch hẹn (reschedule)
class BookingRescheduleEvent {
  final String bookingId;
  final String status; // Approved, Suggested, Rejected
  final String message;
  final String? suggestedDate;
  final String? suggestedTime;
  final String? reason;

  const BookingRescheduleEvent({
    required this.bookingId,
    required this.status,
    required this.message,
    this.suggestedDate,
    this.suggestedTime,
    this.reason,
  });

  factory BookingRescheduleEvent.fromJson(
    Map<String, dynamic> json,
    String status,
  ) {
    return BookingRescheduleEvent(
      bookingId:
          json['bookingId']?.toString() ?? json['BookingId']?.toString() ?? '',
      status: status,
      message: json['message']?.toString() ?? json['Message']?.toString() ?? '',
      suggestedDate:
          json['suggestedDate']?.toString() ??
          json['SuggestedDate']?.toString(),
      suggestedTime:
          json['suggestedTime']?.toString() ??
          json['SuggestedTime']?.toString(),
      reason: json['reason']?.toString() ?? json['Reason']?.toString(),
    );
  }
}

/// Sự kiện: Điểm ví thay đổi (cộng/trừ điểm). Payload optional.
class WalletPointsChangedEvent {
  final int? loyaltyPoint;
  final int? lifetimePoints;
  final String message;

  const WalletPointsChangedEvent({
    this.loyaltyPoint,
    this.lifetimePoints,
    required this.message,
  });

  factory WalletPointsChangedEvent.fromJson(Map<String, dynamic> json) {
    return WalletPointsChangedEvent(
      loyaltyPoint: (json['loyaltyPoint'] as num?)?.toInt(),
      lifetimePoints: (json['lifetimePoints'] as num?)?.toInt(),
      message: json['message']?.toString() ?? 'Điểm của bạn đã được cập nhật.',
    );
  }
}

/// Sự kiện: Nhận voucher mới (sau redeem hoặc tặng).
class VoucherReceivedEvent {
  final int? userPromotionUsageId;
  final int? promotionId;
  final String? promotionName;
  final String message;

  const VoucherReceivedEvent({
    this.userPromotionUsageId,
    this.promotionId,
    this.promotionName,
    required this.message,
  });

  factory VoucherReceivedEvent.fromJson(Map<String, dynamic> json) {
    return VoucherReceivedEvent(
      userPromotionUsageId: (json['userPromotionUsageId'] as num?)?.toInt(),
      promotionId: (json['promotionId'] as num?)?.toInt(),
      promotionName: json['promotionName']?.toString(),
      message: json['message']?.toString() ?? 'Bạn vừa nhận một voucher.',
    );
  }
}

/// Sự kiện: Cảnh báo trễ ca kèm quyền tự quyết (WAIT, REASSIGN, RESCHEDULE)
class DelayWarningWithAutonomyEvent {
  final String bookingId;
  final String message;
  final List<String> options;

  const DelayWarningWithAutonomyEvent({
    required this.bookingId,
    required this.message,
    required this.options,
  });

  factory DelayWarningWithAutonomyEvent.fromJson(Map<String, dynamic> json) {
    final rawOptions = json['options'] ?? json['Options'];
    List<String> parsedOptions = [];
    if (rawOptions is List) {
      parsedOptions = rawOptions.map((e) => e.toString()).toList();
    }
    if (parsedOptions.isEmpty) {
      parsedOptions = ['WAIT', 'REASSIGN', 'RESCHEDULE'];
    }

    return DelayWarningWithAutonomyEvent(
      bookingId:
          json['bookingId']?.toString() ?? json['BookingId']?.toString() ?? '',
      message: json['message']?.toString() ?? json['Message']?.toString() ?? '',
      options: parsedOptions,
    );
  }
}

/// Sự kiện: Cập nhật ETA dự kiến cho ca trễ
class DelayETAEvent {
  final String bookingId;
  final String message;

  const DelayETAEvent({this.bookingId = '', required this.message});

  factory DelayETAEvent.fromJson(Map<String, dynamic> json) {
    return DelayETAEvent(
      bookingId: json['bookingId']?.toString() ?? json['BookingId']?.toString() ?? '',
      message: json['message']?.toString() ?? json['Message']?.toString() ?? '',
    );
  }
}

/// Sự kiện: Salon báo giá mẫu nail custom của khách
class CustomNailQuotedEvent {
  final String customerNailRequestId;
  final String customerNailId;
  final double price;
  final int duration;
  final String message;

  const CustomNailQuotedEvent({
    required this.customerNailRequestId,
    required this.customerNailId,
    required this.price,
    required this.duration,
    required this.message,
  });

  factory CustomNailQuotedEvent.fromJson(Map<String, dynamic> json) {
    return CustomNailQuotedEvent(
      customerNailRequestId:
          json['customerNailRequestId']?.toString() ??
          json['CustomerNailRequestId']?.toString() ??
          '',
      customerNailId:
          json['customerNailId']?.toString() ??
          json['CustomerNailId']?.toString() ??
          '',
      price: (json['price'] ?? json['Price'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] ?? json['Duration'] as num?)?.toInt() ?? 0,
      message:
          json['message']?.toString() ??
          json['Message']?.toString() ??
          'Salon đã gửi báo giá cho mẫu nail custom của bạn!',
    );
  }
}

/// Sự kiện: Salon từ chối mẫu nail custom của khách
class CustomNailRejectedEvent {
  final String customerNailRequestId;
  final String reason;
  final String message;

  const CustomNailRejectedEvent({
    required this.customerNailRequestId,
    required this.reason,
    required this.message,
  });

  factory CustomNailRejectedEvent.fromJson(Map<String, dynamic> json) {
    final rawReason = json['reason']?.toString() ?? json['Reason']?.toString() ?? '';
    final cleanedReason = _cleanSignalRReason(rawReason) ?? rawReason;
    return CustomNailRejectedEvent(
      customerNailRequestId:
          json['customerNailRequestId']?.toString() ??
          json['CustomerNailRequestId']?.toString() ??
          '',
      reason: cleanedReason,
      message: _cleanSignalRMessage(
        json['message']?.toString() ?? json['Message']?.toString(),
        'Mẫu nail custom của bạn đã bị salon từ chối.',
      ),
    );
  }
}

class SlotStatusChangedEvent {
  final String salonId;
  final String artistId;
  final String bookingDate;
  final String startTime;
  final String action; // Held, Released, Booked
  
  SlotStatusChangedEvent({
    required this.salonId,
    required this.artistId,
    required this.bookingDate,
    required this.startTime,
    required this.action,
  });

  factory SlotStatusChangedEvent.fromJson(Map<String, dynamic> json) {
    return SlotStatusChangedEvent(
      salonId: json['salonId']?.toString() ?? json['SalonId']?.toString() ?? '',
      artistId: json['artistId']?.toString() ?? json['ArtistId']?.toString() ?? '',
      bookingDate: json['bookingDate']?.toString() ?? json['BookingDate']?.toString() ?? '',
      startTime: json['startTime']?.toString() ?? json['StartTime']?.toString() ?? '',
      action: json['action']?.toString() ?? json['Action']?.toString() ?? '',
    );
  }
}

/// Sự kiện: Thợ (Nail Artist) làm móng được phân công lại cho đơn đặt lịch
class ArtistReassignedEvent {
  final String bookingId;
  final String newArtistName;
  final String? salonName;
  final String? customerName;
  final String message;

  const ArtistReassignedEvent({
    required this.bookingId,
    required this.newArtistName,
    this.salonName,
    this.customerName,
    required this.message,
  });

  factory ArtistReassignedEvent.fromJson(Map<String, dynamic> json) {
    final bId =
        json['bookingId']?.toString() ?? json['BookingId']?.toString() ?? '';
    final artistName = json['newArtistName']?.toString() ??
        json['NewArtistName']?.toString() ??
        json['artistName']?.toString() ??
        json['ArtistName']?.toString() ??
        'Thợ mới';
    final sName = json['salonName']?.toString() ?? json['SalonName']?.toString();
    final cName = json['customerName']?.toString() ?? json['CustomerName']?.toString();

    final rawMsg = json['message']?.toString() ?? json['Message']?.toString();
    final fallbackMsg = (sName != null && sName.isNotEmpty)
        ? 'Đơn đặt lịch của bạn tại $sName đã được chuyển sang Thợ $artistName.'
        : 'Lịch hẹn của bạn đã được chuyển sang Thợ $artistName.';

    final msgText = _cleanSignalRMessage(rawMsg, fallbackMsg);

    return ArtistReassignedEvent(
      bookingId: bId,
      newArtistName: artistName,
      salonName: sName,
      customerName: cName,
      message: msgText,
    );
  }
}
