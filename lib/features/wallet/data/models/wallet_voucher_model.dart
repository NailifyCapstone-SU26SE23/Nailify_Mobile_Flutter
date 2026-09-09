enum VoucherStatus { usable, used, expired, upcoming }

class WalletVoucherModel {
  final int userPromotionUsageId;
  final int promotionId;
  final String promotionName;
  final String? description;
  final String discountType; // Percentage | FixedAmount
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
    this.description,
    required this.discountType,
    required this.discountValue,
    required this.receivedCount,
    required this.usageCount,
    required this.remainingCount,
    this.startDate,
    this.endDate,
    this.imageUrl,
    required this.isValidForUse,
  });

  factory WalletVoucherModel.fromJson(Map<String, dynamic> json) {
    return WalletVoucherModel(
      userPromotionUsageId:
          (json['userPromotionUsageId'] as num?)?.toInt() ?? 0,
      promotionId: (json['promotionId'] as num?)?.toInt() ?? 0,
      promotionName: json['promotionName']?.toString() ?? '',
      description: json['description']?.toString(),
      discountType: json['discountType']?.toString() ?? '',
      discountValue: json['discountValue'] as num? ?? 0,
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

  bool get isFullyUsed => receivedCount > 0 && usageCount >= receivedCount;

  bool get isExpired {
    final end = endDate;
    if (end == null) return false;
    return end.isBefore(DateTime.now());
  }

  bool get isUpcoming {
    final start = startDate;
    if (start == null) return false;
    return start.isAfter(DateTime.now());
  }

  VoucherStatus get status {
    if (isFullyUsed) return VoucherStatus.used;
    if (isExpired) return VoucherStatus.expired;
    if (isUpcoming) return VoucherStatus.upcoming;
    return VoucherStatus.usable;
  }

  /// True nếu voucher còn hiệu lực và có lượt dùng.
  bool get isUsableNow =>
      isValidForUse && !isExpired && !isUpcoming && !isFullyUsed;

  /// Số ngày còn lại (âm nếu đã hết hạn).
  int? get daysUntilExpiry {
    final end = endDate;
    if (end == null) return null;
    final now = DateTime.now();
    final diff = end.difference(DateTime(now.year, now.month, now.day));
    return diff.inDays;
  }

  /// Hiển thị "5d", "12h", "30m" cho badge sắp hết hạn.
  String? get countdownLabel {
    final end = endDate;
    if (end == null) return null;
    final diff = end.difference(DateTime.now());
    if (diff.isNegative) return null;
    if (diff.inDays >= 1) return '${diff.inDays}d';
    if (diff.inHours >= 1) return '${diff.inHours}h';
    if (diff.inMinutes >= 1) return '${diff.inMinutes}m';
    return 'now';
  }

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
