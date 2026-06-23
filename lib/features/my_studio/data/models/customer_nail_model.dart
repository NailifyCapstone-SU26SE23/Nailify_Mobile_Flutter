class CustomerNailModel {
  final String id;
  final String name;
  final String status;
  final String? imageUrl;
  final int price;
  final int duration;
  final String? rejectReason;
  final String? approvedArtistId;
  final DateTime? createdAt;

  // CÁC TRƯỜNG DỮ LIỆU ĐƯỢC GIỮ LẠI ĐỂ PHÁT TRIỂN TÍNH NĂNG XỬ LÝ (TỌA ĐỘ, AR, v.v) SAU NÀY
  final int? nailShapeId;
  final int? nailSurfaceId;
  final String? customColor;
  final Map<String, dynamic>? nailShape;
  final Map<String, dynamic>? nailSurface;
  final List<dynamic> customerNailComponents;

  CustomerNailModel({
    required this.id,
    required this.name,
    required this.status,
    this.imageUrl,
    required this.price,
    required this.duration,
    this.rejectReason,
    this.approvedArtistId,
    this.createdAt,
    this.nailShapeId,
    this.nailSurfaceId,
    this.customColor,
    this.nailShape,
    this.nailSurface,
    required this.customerNailComponents,
  });

  factory CustomerNailModel.fromJson(Map<String, dynamic> json) {
    return CustomerNailModel(
      id: json['customerNailId']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Móng tùy chỉnh',
      status: json['status']?.toString() ?? 'Draft',
      imageUrl: json['imageUrl']?.toString(),
      price: (json['price'] as num?)?.toInt() ?? 0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      rejectReason: json['rejectReason']?.toString(),
      approvedArtistId: json['approvedArtistId']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt']) : null,

      // Giữ  dữ liệu kỹ thuật (tọa độ,....)
      nailShapeId: (json['nailShapeId'] as num?)?.toInt(),
      nailSurfaceId: (json['nailSurfaceId'] as num?)?.toInt(),
      customColor: json['customColor']?.toString(),
      nailShape: json['nailShape'] as Map<String, dynamic>?,
      nailSurface: json['nailSurface'] as Map<String, dynamic>?,
      customerNailComponents: json['customerNailComponents'] as List<dynamic>? ?? [],
    );
  }

  // --- util UI  ---
  String get shapeName => nailShape?['name']?.toString() ?? 'Mặc định';
  String get surfaceName => nailSurface?['name']?.toString() ?? 'Mặc định';

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