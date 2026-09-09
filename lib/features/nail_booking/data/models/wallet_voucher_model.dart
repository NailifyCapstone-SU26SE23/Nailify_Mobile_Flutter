class WalletVoucherModel {
  final int userPromotionUsageId;
  final int promotionId;
  final String promotionName;
  final String description;
  final String discountType;
  final num discountValue;
  final int receivedCount;
  final int usageCount;
  final int remainingCount;
  final DateTime? startDate;
  final DateTime? endDate;
  final String? imageUrl;
  final bool isValidForUse;

  const WalletVoucherModel({
    required this.userPromotionUsageId,
    required this.promotionId,
    required this.promotionName,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.receivedCount,
    required this.usageCount,
    required this.remainingCount,
    required this.startDate,
    required this.endDate,
    this.imageUrl,
    required this.isValidForUse,
  });

  factory WalletVoucherModel.fromJson(Map<String, dynamic> json) {
    return WalletVoucherModel(
      userPromotionUsageId:
          (json['userPromotionUsageId'] as num?)?.toInt() ?? 0,
      promotionId: (json['promotionId'] as num?)?.toInt() ?? 0,
      promotionName: json['promotionName']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      discountType: json['discountType']?.toString() ?? '',
      discountValue: json['discountValue'] as num? ?? 0,
      receivedCount: (json['receivedCount'] as num?)?.toInt() ?? 0,
      usageCount: (json['usageCount'] as num?)?.toInt() ?? 0,
      remainingCount: (json['remainingCount'] as num?)?.toInt() ?? 0,
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? ''),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? ''),
      imageUrl: json['imageUrl']?.toString(),
      isValidForUse: json['isValidForUse'] == true,
    );
  }

  bool get hasUsagesLeft => remainingCount > 0;
  bool get isExpired {
    final end = endDate;
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  String get displayDiscount {
    final type = discountType.toLowerCase();
    if (type == 'percentage') {
      return '${discountValue.toString().replaceAll(RegExp(r'\.0$'), '')}%';
    }
    return '${discountValue.toString()} đ';
  }
}
