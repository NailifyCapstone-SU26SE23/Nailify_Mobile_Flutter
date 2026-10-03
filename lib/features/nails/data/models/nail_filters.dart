import 'package:equatable/equatable.dart';

class NailFilters extends Equatable {
  final String? name;
  final List<int> categoryIds;
  final int? shapeId;
  final int? surfaceId;
  final double? minPrice;
  final double? maxPrice;

  const NailFilters({
    this.name,
    this.categoryIds = const [],
    this.shapeId,
    this.surfaceId,
    this.minPrice,
    this.maxPrice,
  });

  bool get isEmpty =>
      (name == null || name!.trim().isEmpty) &&
      categoryIds.isEmpty &&
      shapeId == null &&
      surfaceId == null &&
      minPrice == null &&
      maxPrice == null;

  bool get isNotEmpty => !isEmpty;

  @override
  List<Object?> get props => [
    name,
    categoryIds,
    shapeId,
    surfaceId,
    minPrice,
    maxPrice,
  ];
}
