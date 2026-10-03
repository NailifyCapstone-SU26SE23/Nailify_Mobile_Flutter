class CategoryModel {
  final int categoryId;
  final String name;
  final int categoryTypeId;
  final String categoryTypeName;
  final String status;

  const CategoryModel({
    required this.categoryId,
    required this.name,
    required this.categoryTypeId,
    required this.categoryTypeName,
    required this.status,
  });

  factory CategoryModel.fromJson(Map<String, dynamic> json) {
    return CategoryModel(
      categoryId: _asInt(json['categoryId'] ?? json['CategoryId']),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      categoryTypeId: _asInt(json['categoryTypeId'] ?? json['CategoryTypeId']),
      categoryTypeName:
          (json['categoryTypeName'] ?? json['CategoryTypeName'] ?? '')
              .toString(),
      status: (json['status'] ?? json['Status'] ?? '').toString(),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
