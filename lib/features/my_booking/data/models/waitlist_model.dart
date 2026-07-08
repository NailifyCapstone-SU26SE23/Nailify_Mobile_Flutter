// ====================================================================
// FILE: lib/features/my_booking/data/models/waitlist_model.dart
// Mô tả: Model cho tính năng Slot Waitlist (API thật + Mock data fallback)
// ====================================================================

// ─────────────────────────────────────────────────────────────
// MODEL DÙNG VỚI API THẬT (/api/Waitlists/me, join, confirm, cancel)
// ─────────────────────────────────────────────────────────────
class WaitlistApiModel {
  final String waitlistId;
  final String? customerId;
  final String? customerName;
  final String? salonId;
  final String? salonName;
  final String? preferredNailArtistId;
  final String? preferredNailArtistName;
  final DateTime? requestedDate;
  final String? requestedStartTime;
  final int? estimatedDuration;
  final int? position;
  final String status; // "Pending", "Opened", "Confirmed", "Cancelled"
  final DateTime? createdAt;
  final DateTime? notifiedAt;
  final DateTime? expiresAt;
  final String? convertedBookingId;

  const WaitlistApiModel({
    required this.waitlistId,
    this.customerId,
    this.customerName,
    this.salonId,
    this.salonName,
    this.preferredNailArtistId,
    this.preferredNailArtistName,
    this.requestedDate,
    this.requestedStartTime,
    this.estimatedDuration,
    this.position,
    required this.status,
    this.createdAt,
    this.notifiedAt,
    this.expiresAt,
    this.convertedBookingId,
  });

  bool get isOpened => status.toLowerCase() == 'opened' || status.toLowerCase() == 'notified';
  bool get isPending => status.toLowerCase() == 'pending' || status.toLowerCase() == 'waiting';

  factory WaitlistApiModel.fromJson(Map<String, dynamic> json) {
    return WaitlistApiModel(
      waitlistId: json['wailistId']?.toString() ?? json['waitlistId']?.toString() ?? '',
      customerId: json['customerId']?.toString(),
      customerName: json['customerName']?.toString(),
      salonId: json['salonId']?.toString(),
      salonName: json['salonName']?.toString(),
      preferredNailArtistId: json['preferredNailArtistId']?.toString(),
      preferredNailArtistName: json['preferredNailArtistName']?.toString(),
      requestedDate: json['requestedDate'] != null
          ? DateTime.tryParse(json['requestedDate'].toString())
          : null,
      requestedStartTime: json['requestedStartTime']?.toString(),
      estimatedDuration: json['estimatedDuration'] is int
          ? json['estimatedDuration'] as int
          : int.tryParse(json['estimatedDuration']?.toString() ?? ''),
      position: json['position'] is int
          ? json['position'] as int
          : int.tryParse(json['position']?.toString() ?? ''),
      status: json['status']?.toString() ?? 'Pending',
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString())
          : null,
      notifiedAt: json['notifiedAt'] != null
          ? DateTime.tryParse(json['notifiedAt'].toString())
          : null,
      expiresAt: json['expiresAt'] != null
          ? DateTime.tryParse(json['expiresAt'].toString())
          : null,
      convertedBookingId: json['convertedBookingId']?.toString(),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MODEL CŨ - Giữ lại để WaitlistCard vẫn tương thích (sẽ loại bỏ dần)
// ─────────────────────────────────────────────────────────────
enum WaitlistStatus { pending, opened }

class WaitlistModel {
  final String id;
  final String salonName;
  final String address;
  final String time; // "09:00"
  final DateTime date;
  final String staffName;
  final List<String> services;
  final WaitlistStatus status;
  final DateTime holdUntil; // Thời hạn giữ chỗ (chỉ có ý nghĩa khi status == opened)
  final DateTime registeredAt; // Thời điểm đăng ký

  const WaitlistModel({
    required this.id,
    required this.salonName,
    required this.address,
    required this.time,
    required this.date,
    required this.staffName,
    required this.services,
    required this.status,
    required this.holdUntil,
    required this.registeredAt,
  });

  /// Tạo WaitlistModel từ WaitlistApiModel (để tương thích WaitlistCard)
  factory WaitlistModel.fromApi(WaitlistApiModel api) {
    final timeRaw = api.requestedStartTime ?? '00:00';
    final timeFormatted = timeRaw.length >= 5 ? timeRaw.substring(0, 5) : timeRaw;
    return WaitlistModel(
      id: api.waitlistId,
      salonName: api.salonName ?? 'Salon',
      address: '',
      time: timeFormatted,
      date: api.requestedDate ?? DateTime.now(),
      staffName: api.preferredNailArtistName ?? 'Bất kỳ',
      services: [],
      status: api.isOpened ? WaitlistStatus.opened : WaitlistStatus.pending,
      holdUntil: api.expiresAt ?? DateTime.now().add(const Duration(minutes: 30)),
      registeredAt: api.createdAt ?? DateTime.now(),
    );
  }

  WaitlistModel copyWith({
    String? id,
    String? salonName,
    String? address,
    String? time,
    DateTime? date,
    String? staffName,
    List<String>? services,
    WaitlistStatus? status,
    DateTime? holdUntil,
    DateTime? registeredAt,
  }) {
    return WaitlistModel(
      id: id ?? this.id,
      salonName: salonName ?? this.salonName,
      address: address ?? this.address,
      time: time ?? this.time,
      date: date ?? this.date,
      staffName: staffName ?? this.staffName,
      services: services ?? this.services,
      status: status ?? this.status,
      holdUntil: holdUntil ?? this.holdUntil,
      registeredAt: registeredAt ?? this.registeredAt,
    );
  }
}

