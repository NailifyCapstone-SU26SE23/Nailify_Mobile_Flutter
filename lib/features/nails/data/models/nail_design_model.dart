import 'category_model.dart';
import 'nail_variant_model.dart';

class NailDesignModel {
  final int nailDesignId;
  final String name;
  final double minPrice;
  final double maxPrice;
  final String description;
  final String status;
  final String imageUrl;
  final List<CategoryModel> categories;
  final List<NailVariantModel> nailVariants;

  const NailDesignModel({
    required this.nailDesignId,
    required this.name,
    required this.minPrice,
    required this.maxPrice,
    required this.description,
    required this.status,
    required this.imageUrl,
    this.categories = const [],
    this.nailVariants = const [],
  });

  factory NailDesignModel.fromJson(Map<String, dynamic> json) {
    final categoriesJson = json['categories'] ?? json['Categories'] ?? [];
    final variantsJson = json['nailVariants'] ?? json['NailVariants'] ?? [];
    return NailDesignModel(
      nailDesignId: _asInt(json['nailDesignId'] ?? json['NailDesignId']),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      minPrice: _asDouble(json['minPrice'] ?? json['MinPrice']),
      maxPrice: _asDouble(json['maxPrice'] ?? json['MaxPrice']),
      description: (json['description'] ?? json['Description'] ?? '')
          .toString(),
      status: (json['status'] ?? json['Status'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? json['ImageUrl'] ?? '').toString(),
      categories: categoriesJson is List
          ? categoriesJson
                .whereType<Map>()
                .map(
                  (item) =>
                      CategoryModel.fromJson(Map<String, dynamic>.from(item)),
                )
                .toList()
          : const [],
      nailVariants: variantsJson is List
          ? variantsJson
                .whereType<Map>()
                .map(
                  (item) => NailVariantModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}
