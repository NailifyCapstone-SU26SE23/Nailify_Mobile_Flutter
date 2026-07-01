class PromotionModel {
  final int promotionId;
  final String name;
  final String description;
  final String type;
  final String scope;
  final String discountType;
  final num discountValue;
  final DateTime? startDate;
  final DateTime? endDate;
  final String status;
  final bool isSelectable;
  final String? imageUrl;

  const PromotionModel({
    required this.promotionId,
    required this.name,
    required this.description,
    required this.type,
    required this.scope,
    required this.discountType,
    required this.discountValue,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.isSelectable,
    this.imageUrl,
  });

  factory PromotionModel.fromJson(Map<String, dynamic> json) {
    return PromotionModel(
      promotionId: (json['promotionId'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      scope: json['scope']?.toString() ?? '',
      discountType: json['discountType']?.toString() ?? '',
      discountValue: json['discountValue'] as num? ?? 0,
      startDate: DateTime.tryParse(json['startDate']?.toString() ?? ''),
      endDate: DateTime.tryParse(json['endDate']?.toString() ?? ''),
      status: json['status']?.toString() ?? '',
      isSelectable: json['isSelectable'] == true,
      imageUrl: json['imageUrl']?.toString(),
    );
  }

  String get discountLabel {
    if (discountType == 'Percentage') {
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
