class ComponentModel {
  final int componentId;
  final String name;
  final String imageUrl;
  final String componentType;
  final double price;

  const ComponentModel({
    required this.componentId,
    required this.name,
    required this.imageUrl,
    required this.componentType,
    required this.price,
  });

  factory ComponentModel.fromJson(Map<String, dynamic> json) {
    return ComponentModel(
      componentId: _asInt(json['componentId'] ?? json['ComponentId']),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? json['ImageUrl'] ?? '').toString(),
      componentType: (json['componentType'] ?? json['ComponentType'] ?? '').toString(),
      price: _asDouble(json['price'] ?? json['Price']),
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
