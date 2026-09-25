// ====================================================================
// FILE: lib/core/network/signalr_events.dart
// Mô tả: Models cho các sự kiện real-time từ SignalR Hub
// ====================================================================

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
      message:
          json['message']?.toString() ??
          'Đã có slot trống! Bạn có 15 phút để xác nhận.',
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
      message:
          json['message']?.toString() ??
          'Thời gian xác nhận lịch hẹn từ hàng chờ (15 phút) đã hết hạn.',
    );
  }
}

/// Sự kiện: Lịch hẹn bị hủy tự động — trễ quá 15 phút
class BookingCancelledEvent {
  final String bookingId;
  final String message;

  const BookingCancelledEvent({required this.bookingId, required this.message});

  factory BookingCancelledEvent.fromJson(Map<String, dynamic> json) {
    return BookingCancelledEvent(
      bookingId: json['bookingId']?.toString() ?? '',
      message:
          json['message']?.toString() ??
          'Lịch hẹn của bạn đã tự động hủy do trễ quá 15 phút.',
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
  final String message;

  const DelayETAEvent({required this.message});

  factory DelayETAEvent.fromJson(Map<String, dynamic> json) {
    return DelayETAEvent(
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
    return CustomNailRejectedEvent(
      customerNailRequestId:
          json['customerNailRequestId']?.toString() ??
          json['CustomerNailRequestId']?.toString() ??
          '',
      reason: json['reason']?.toString() ?? json['Reason']?.toString() ?? '',
      message:
          json['message']?.toString() ??
          json['Message']?.toString() ??
          'Mẫu nail custom của bạn đã bị salon từ chối.',
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
