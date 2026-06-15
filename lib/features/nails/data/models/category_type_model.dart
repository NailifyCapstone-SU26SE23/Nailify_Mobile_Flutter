import 'category_model.dart';

class CategoryTypeModel {
  final int categoryTypeId;
  final String name;
  final String status;
  final List<CategoryModel> categories;

  const CategoryTypeModel({
    required this.categoryTypeId,
    required this.name,
    required this.status,
    this.categories = const [],
  });

  factory CategoryTypeModel.fromJson(Map<String, dynamic> json) {
    final categoriesJson = json['categories'] ?? json['Categories'] ?? [];
    return CategoryTypeModel(
      categoryTypeId: _asInt(json['categoryTypeId'] ?? json['CategoryTypeId']),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      status: (json['status'] ?? json['Status'] ?? '').toString(),
      categories: categoriesJson is List
          ? categoriesJson.whereType<Map>().map((item) => CategoryModel.fromJson(Map<String, dynamic>.from(item))).toList()
          : const [],
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
