import 'package:equatable/equatable.dart';

/// Thực thể nghiệp vụ thuần túy đại diện cho một chương trình khuyến mãi.
class PromotionEntity extends Equatable {
  final int promotionId;
  final String name;
  final String description;
  final String discountType; // 'Percentage' | 'Fixed'
  final num discountValue;
  final String status;
  final bool isSelectable;
  final String? imageUrl;

  const PromotionEntity({
    required this.promotionId,
    required this.name,
    required this.description,
    required this.discountType,
    required this.discountValue,
    required this.status,
    required this.isSelectable,
    this.imageUrl,
  });

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

  @override
  List<Object?> get props => [promotionId, name, discountType, discountValue];
}
