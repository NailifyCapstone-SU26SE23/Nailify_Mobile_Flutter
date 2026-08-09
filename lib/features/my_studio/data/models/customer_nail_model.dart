/// Model cho một yêu cầu duyệt mẫu nail (CustomerNailRequest)
/// Được map từ response API GET /api/CustomerNailRequests
class CustomerNailModel {
  // --- Trường chính của CustomerNailRequest ---
  final String customerNailRequestId;
  final int customerNailId;
  final String salonId;
  final String status; // 'Pending', 'Approved', 'Rejected', etc.
  final String? rejectReason;
  final String? approvedArtistId;
  final int price;
  final int duration;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? artistFullName;
  final String? salonName;

  // --- Thông tin chi tiết customerNail (nested) ---
  final String name;
  final String? imageUrl;
  final int? nailShapeId;
  final int? nailSurfaceId;
  final int customerNailPrice;
  final String? customColor;
  final Map<String, dynamic>? nailShape;
  final Map<String, dynamic>? nailSurface;
  final List<dynamic> customerNailComponents;
  final String? customerNailStatus;

  // --- Thông tin Salon (nested) ---
  final Map<String, dynamic>? salonData;

  // --- Thông tin Approved Artist (nested) ---
  final Map<String, dynamic>? approvedArtistData;

  CustomerNailModel({
    required this.customerNailRequestId,
    required this.customerNailId,
    required this.salonId,
    required this.status,
    this.rejectReason,
    this.approvedArtistId,
    required this.price,
    required this.duration,
    this.createdAt,
    this.updatedAt,
    this.artistFullName,
    this.salonName,
    required this.name,
    this.imageUrl,
    this.nailShapeId,
    this.nailSurfaceId,
    required this.customerNailPrice,
    this.customColor,
    this.nailShape,
    this.nailSurface,
    required this.customerNailComponents,
    this.customerNailStatus,
    this.salonData,
    this.approvedArtistData,
  });

  factory CustomerNailModel.fromJson(Map<String, dynamic> json) {
    final customerNail = json['customerNail'] as Map<String, dynamic>? ?? {};
    final salon = json['salon'] as Map<String, dynamic>?;
    final approvedArtist = json['approvedArtist'] as Map<String, dynamic>?;

    final rawPrice = json['price'] ?? json['Price'];
    final parsedPrice = (rawPrice as num?)?.toInt() ?? 0;

    final rawDuration = json['duration'] ?? json['Duration'];
    final fallbackDuration =
        customerNail['duration'] ?? customerNail['Duration'];
    final parsedDuration = (rawDuration as num?)?.toInt() ?? 0;
    final finalDuration = parsedDuration > 0
        ? parsedDuration
        : ((fallbackDuration as num?)?.toInt() ?? 0);

    return CustomerNailModel(
      customerNailRequestId: json['customerNailRequestId']?.toString() ?? '',
      customerNailId: (json['customerNailId'] as num?)?.toInt() ?? 0,
      salonId: json['salonId']?.toString() ?? '',
      status: json['status']?.toString() ?? 'Pending',
      rejectReason: json['rejectReason']?.toString(),
      approvedArtistId: json['approvedArtistId']?.toString(),
      price: parsedPrice,
      duration: finalDuration,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'])
          : null,
      updatedAt: json['updatedAt'] != null
          ? DateTime.tryParse(json['updatedAt'])
          : null,
      artistFullName: json['artistFullName']?.toString(),
      salonName: json['salonName']?.toString(),

      // Nested customerNail fields
      name: customerNail['name']?.toString() ?? 'Móng tùy chỉnh',
      imageUrl: customerNail['imageUrl']?.toString(),
      nailShapeId: (customerNail['nailShapeId'] as num?)?.toInt(),
      nailSurfaceId: (customerNail['nailSurfaceId'] as num?)?.toInt(),
      customerNailPrice: (customerNail['price'] as num?)?.toInt() ?? 0,
      customColor: customerNail['customColor']?.toString(),
      nailShape: customerNail['nailShape'] as Map<String, dynamic>?,
      nailSurface: customerNail['nailSurface'] as Map<String, dynamic>?,
      customerNailComponents:
          customerNail['customerNailComponents'] as List<dynamic>? ?? [],
      customerNailStatus: customerNail['status']?.toString(),

      // Nested salon & artist data (giữ nguyên để dùng khi cần)
      salonData: salon,
      approvedArtistData: approvedArtist,
    );
  }

  // --- Util getters cho UI ---
  String get shapeName => nailShape?['name']?.toString() ?? 'Mặc định';
  String get surfaceName => nailSurface?['name']?.toString() ?? 'Mặc định';

  int get surfacePrice {
    final value = nailSurface?['price'] ?? nailSurface?['Price'];
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  /// Tên thợ đã duyệt (lấy từ field artistFullName hoặc nested approvedArtist)
  String get stylistName {
    if (artistFullName != null && artistFullName!.isNotEmpty) {
      return artistFullName!;
    }
    if (approvedArtistData != null) {
      final first = approvedArtistData!['firstName']?.toString() ?? '';
      final last = approvedArtistData!['lastName']?.toString() ?? '';
      return '$first $last'.trim();
    }
    return 'Chưa gán';
  }

  /// ID thợ nail (nailArtistId) từ nested approvedArtist
  String? get nailArtistId {
    return approvedArtistData?['nailArtistId']?.toString() ?? approvedArtistId;
  }

  /// Địa chỉ salon
  String? get salonAddress => salonData?['address']?.toString();

  /// Avatar thợ
  String? get artistAvatarUrl => approvedArtistData?['avatarUrl']?.toString();

  List<String> get accessoryNames {
    List<String> list = [];
    for (var c in customerNailComponents) {
      if (c['component'] != null) {
        list.add(c['component']['name']?.toString() ?? '');
      } else if (c['customerComponent'] != null) {
        list.add(c['customerComponent']['name']?.toString() ?? '');
      }
    }
    return list.where((s) => s.isNotEmpty).toList();
  }
}
