class RedeemablePromotionModel {
  final int promotionId;
  final String name;
  final String? description;
  final String type;
  final String scope;
  final String discountType; // Percentage | FixedAmount
  final num discountValue;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final int? usageLimit;
  final int currentUsageCount;
  final int? userLimit;
  final String? imageUrl;
  final int? remainingCount;

  /// Số điểm cần để đổi voucher này.
  /// BE sẽ trả field này trong tương lai gần; hiện tại có thể null.
  final int? pointsRequired;

  const RedeemablePromotionModel({
    required this.promotionId,
    required this.name,
    this.description,
    required this.type,
    required this.scope,
    required this.discountType,
    required this.discountValue,
    this.startDate,
    this.endDate,
    required this.status,
    this.usageLimit,
    required this.currentUsageCount,
    this.userLimit,
    this.imageUrl,
    this.remainingCount,
    this.pointsRequired,
  });

  factory RedeemablePromotionModel.fromJson(Map<String, dynamic> json) {
    return RedeemablePromotionModel(
      promotionId: (json['promotionId'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      type: json['type']?.toString() ?? '',
      scope: json['scope']?.toString() ?? '',
      discountType: json['discountType']?.toString() ?? '',
      discountValue: json['discountValue'] as num? ?? 0,
      startDate: _parseDate(json['startDate']),
      endDate: _parseDate(json['endDate']),
      status: json['status']?.toString() ?? '',
      usageLimit: (json['usageLimit'] as num?)?.toInt(),
      currentUsageCount: (json['currentUsageCount'] as num?)?.toInt() ?? 0,
      userLimit: (json['userLimit'] as num?)?.toInt(),
      imageUrl: json['imageUrl']?.toString(),
      remainingCount: (json['remainingCount'] as num?)?.toInt(),
      pointsRequired: (json['pointsRequired'] as num?)?.toInt(),
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  bool get isActive => status.toLowerCase() == 'active';

  bool get isSoldOut {
    final remaining = remainingCount;
    if (remaining == null) return false;
    return remaining <= 0;
  }

  /// True nếu user có thể đổi được (BE còn cho phép, còn lượt).
  bool get canRedeem => isActive && !isSoldOut;

  String get discountLabel {
    if (discountType.toLowerCase() == 'percentage') {
      final value = discountValue % 1 == 0
          ? discountValue.toInt().toString()
          : discountValue.toString();
      return '$value% off';
    }
    final value = discountValue.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$value VND off';
  }
}
