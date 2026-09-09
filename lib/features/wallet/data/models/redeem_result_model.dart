class RedeemResultModel {
  final int userPromotionUsageId;
  final int promotionId;
  final String promotionName;
  final String? description;
  final String? discountType;
  final num? discountValue;
  final int receivedCount;
  final int usageCount;
  final int remainingCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? imageUrl;
  final bool isValidForUse;

  const RedeemResultModel({
    required this.userPromotionUsageId,
    required this.promotionId,
    required this.promotionName,
    this.description,
    this.discountType,
    this.discountValue,
    required this.receivedCount,
    required this.usageCount,
    required this.remainingCount,
    this.startDate,
    this.endDate,
    this.imageUrl,
    required this.isValidForUse,
  });

  factory RedeemResultModel.fromJson(Map<String, dynamic> json) {
    return RedeemResultModel(
      userPromotionUsageId:
          (json['userPromotionUsageId'] as num?)?.toInt() ?? 0,
      promotionId: (json['promotionId'] as num?)?.toInt() ?? 0,
      promotionName: json['promotionName']?.toString() ?? '',
      description: json['description']?.toString(),
      discountType: json['discountType']?.toString(),
      discountValue: json['discountValue'] as num?,
      receivedCount: (json['receivedCount'] as num?)?.toInt() ?? 0,
      usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
      remainingCount: (json['remainingCount'] as num?)?.toInt() ?? 0,
      startDate: _parseDate(json['startDate']),
      endDate: _parseDate(json['endDate']),
      imageUrl: json['imageUrl']?.toString(),
      isValidForUse: json['isValidForUse'] as bool? ?? false,
    );
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }

  String get discountLabel {
    final type = discountType?.toLowerCase();
    final value = discountValue ?? 0;
    if (type == 'percentage') {
      final str = value % 1 == 0 ? value.toInt().toString() : value.toString();
      return '$str% off';
    }
    final str = value.round().toString().replaceAllMapped(
      RegExp(r'\B(?=(\d{3})+(?!\d))'),
      (_) => ',',
    );
    return '$str VND off';
  }
}
