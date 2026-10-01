// ====================================================================
// FILE: lib/features/my_booking/data/models/waitlist_model.dart
// Mô tả: Model cho tính năng Slot Waitlist (API thật + Mock data fallback)
// ====================================================================

class WaitlistItemModel {
  final String waitlistItemId;
  final String waitlistId;
  final int? nailVariantId;
  final String? nailVariantName;
  final String? nailVariantImageUrl;
  final String? serviceId;
  final String? serviceName;
  final int? customerNailId;
  final String? customerNailName;
  final String? customerNailImageUrl;
  final int? shapeMethodConfigId;
  final String? shapeMethodConfigName;
  final String? customerNailRequestId;
  final int? quantity;

  const WaitlistItemModel({
    required this.waitlistItemId,
    required this.waitlistId,
    this.nailVariantId,
    this.nailVariantName,
    this.nailVariantImageUrl,
    this.serviceId,
    this.serviceName,
    this.customerNailId,
    this.customerNailName,
    this.customerNailImageUrl,
    this.shapeMethodConfigId,
    this.shapeMethodConfigName,
    this.customerNailRequestId,
    this.quantity,
  });

  factory WaitlistItemModel.fromJson(Map<String, dynamic> json) {
    int? parseNullableInt(dynamic val) {
      if (val is int) return val;
      if (val is num) return val.toInt();
      return int.tryParse(val?.toString() ?? '');
    }

    return WaitlistItemModel(
      waitlistItemId: json['waitlistItemId']?.toString() ??
          json['WaitlistItemId']?.toString() ??
          '',
      waitlistId: json['waitlistId']?.toString() ??
          json['WaitlistId']?.toString() ??
          '',
      nailVariantId:
          parseNullableInt(json['nailVariantId'] ?? json['NailVariantId']),
      nailVariantName: json['nailVariantName']?.toString() ??
          json['NailVariantName']?.toString(),
      nailVariantImageUrl: json['nailVariantImageUrl']?.toString() ??
          json['NailVariantImageUrl']?.toString(),
      serviceId:
          json['serviceId']?.toString() ?? json['ServiceId']?.toString(),
      serviceName:
          json['serviceName']?.toString() ?? json['ServiceName']?.toString(),
      customerNailId:
          parseNullableInt(json['customerNailId'] ?? json['CustomerNailId']),
      customerNailName: json['customerNailName']?.toString() ??
          json['CustomerNailName']?.toString(),
      customerNailImageUrl: json['customerNailImageUrl']?.toString() ??
          json['CustomerNailImageUrl']?.toString(),
      shapeMethodConfigId: parseNullableInt(
          json['shapeMethodConfigId'] ?? json['ShapeMethodConfigId']),
      shapeMethodConfigName: json['shapeMethodConfigName']?.toString() ??
          json['ShapeMethodConfigName']?.toString(),
      customerNailRequestId: json['customerNailRequestId']?.toString() ??
          json['CustomerNailRequestId']?.toString(),
      quantity: parseNullableInt(json['quantity'] ?? json['Quantity']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'waitlistItemId': waitlistItemId,
      'waitlistId': waitlistId,
      'nailVariantId': nailVariantId,
      'nailVariantName': nailVariantName,
      'nailVariantImageUrl': nailVariantImageUrl,
      'serviceId': serviceId,
      'serviceName': serviceName,
      'customerNailId': customerNailId,
      'customerNailName': customerNailName,
      'customerNailImageUrl': customerNailImageUrl,
      'shapeMethodConfigId': shapeMethodConfigId,
      'shapeMethodConfigName': shapeMethodConfigName,
      'customerNailRequestId': customerNailRequestId,
      'quantity': quantity,
    };
  }
}

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
  final List<WaitlistItemModel> waitlistItems;

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
    this.waitlistItems = const [],
  });

  bool get isOpened =>
      status.toLowerCase() == 'opened' || status.toLowerCase() == 'notified';
  bool get isPending =>
      status.toLowerCase() == 'pending' || status.toLowerCase() == 'waiting';

  static DateTime? _parseServerDateTime(dynamic value) {
    if (value == null) return null;
    final raw = value.toString().trim();
    if (raw.isEmpty) return null;

    String isoStr = raw;
    if (!isoStr.contains('Z') &&
        !isoStr.contains('+') &&
        !RegExp(r'-\d{2}:\d{2}$').hasMatch(isoStr)) {
      isoStr = '${isoStr}Z';
    }

    final parsed = DateTime.tryParse(isoStr) ?? DateTime.tryParse(raw);
    if (parsed == null) return null;

    return parsed.toLocal();
  }

  factory WaitlistApiModel.fromJson(Map<String, dynamic> json) {
    final rawItems = json['waitlistItems'] ?? json['WaitlistItems'];
    List<WaitlistItemModel> parsedItems = [];
    if (rawItems is List) {
      parsedItems = rawItems
          .whereType<Map>()
          .map((e) => WaitlistItemModel.fromJson(Map<String, dynamic>.from(e)))
          .toList();
    }

    dynamic getValue(List<String> keys) {
      for (final key in keys) {
        final val = json[key];
        if (val != null && val.toString().trim().isNotEmpty) {
          return val;
        }
      }
      return null;
    }

    final createdAtRaw = getValue([
      'createdAt',
      'CreatedAt',
      'createdDate',
      'CreatedDate',
      'joinedAt',
      'JoinedAt',
      'created_at',
    ]);
    final notifiedAtRaw = getValue(['notifiedAt', 'NotifiedAt', 'notified_at']);
    final expiresAtRaw = getValue(['expiresAt', 'ExpiresAt', 'expires_at']);
    final requestedDateRaw = getValue([
      'requestedDate',
      'RequestedDate',
      'requested_date',
    ]);

    return WaitlistApiModel(
      waitlistId: json['waitlistId']?.toString() ??
          json['WaitlistId']?.toString() ??
          json['wailistId']?.toString() ??
          json['id']?.toString() ??
          json['Id']?.toString() ??
          '',
      customerId: json['customerId']?.toString() ?? json['CustomerId']?.toString(),
      customerName: json['customerName']?.toString() ?? json['CustomerName']?.toString(),
      salonId: json['salonId']?.toString() ?? json['SalonId']?.toString(),
      salonName: json['salonName']?.toString() ?? json['SalonName']?.toString(),
      preferredNailArtistId: json['preferredNailArtistId']?.toString() ?? json['PreferredNailArtistId']?.toString(),
      preferredNailArtistName: json['preferredNailArtistName']?.toString() ?? json['PreferredNailArtistName']?.toString(),
      requestedDate: _parseServerDateTime(requestedDateRaw),
      requestedStartTime: json['requestedStartTime']?.toString() ?? json['RequestedStartTime']?.toString(),
      estimatedDuration: json['estimatedDuration'] is int
          ? json['estimatedDuration'] as int
          : int.tryParse(json['estimatedDuration']?.toString() ?? json['EstimatedDuration']?.toString() ?? ''),
      position: json['position'] is int
          ? json['position'] as int
          : int.tryParse(json['position']?.toString() ?? json['Position']?.toString() ?? ''),
      status: json['status']?.toString() ?? json['Status']?.toString() ?? 'Pending',
      createdAt: _parseServerDateTime(createdAtRaw),
      notifiedAt: _parseServerDateTime(notifiedAtRaw),
      expiresAt: _parseServerDateTime(expiresAtRaw),
      convertedBookingId: json['convertedBookingId']?.toString() ?? json['ConvertedBookingId']?.toString(),
      waitlistItems: parsedItems,
    );
  }
}

// ─────────────────────────────────────────────────────────────
// MODEL CŨ - Giữ lại để WaitlistCard vẫn tương thích
// ─────────────────────────────────────────────────────────────
enum WaitlistStatus { pending, opened }

class WaitlistModel {
  final String id;
  final String? salonId;
  final String salonName;
  final String address;
  final String time; // "09:00"
  final DateTime date;
  final String? staffId;
  final String staffName;
  final List<String> services;
  final WaitlistStatus status;
  final DateTime holdUntil;
  final DateTime registeredAt;
  final List<WaitlistItemModel> waitlistItems;

  const WaitlistModel({
    required this.id,
    this.salonId,
    required this.salonName,
    required this.address,
    required this.time,
    required this.date,
    this.staffId,
    required this.staffName,
    required this.services,
    required this.status,
    required this.holdUntil,
    required this.registeredAt,
    this.waitlistItems = const [],
  });

  factory WaitlistModel.fromApi(WaitlistApiModel api) {
    final timeRaw = api.requestedStartTime ?? '00:00';
    final timeFormatted = timeRaw.length >= 5
        ? timeRaw.substring(0, 5)
        : timeRaw;
    final extractedServices = api.waitlistItems
        .map((e) => e.serviceName ?? e.nailVariantName ?? e.customerNailName)
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();

    return WaitlistModel(
      id: api.waitlistId,
      salonId: api.salonId,
      salonName: api.salonName ?? 'Salon',
      address: '',
      time: timeFormatted,
      date: api.requestedDate ?? DateTime.now(),
      staffId: api.preferredNailArtistId,
      staffName: api.preferredNailArtistName ?? 'Bất kỳ',
      services: extractedServices,
      status: api.isOpened ? WaitlistStatus.opened : WaitlistStatus.pending,
      holdUntil:
          api.expiresAt ?? DateTime.now().add(const Duration(minutes: 30)),
      registeredAt: api.createdAt ?? DateTime.now(),
      waitlistItems: api.waitlistItems,
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
