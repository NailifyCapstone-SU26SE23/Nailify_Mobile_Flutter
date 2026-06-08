class NailShapeModel {
  final int nailShapeId;
  final String name;
  final String imageUrl;
  final double price;

  const NailShapeModel({
    required this.nailShapeId,
    required this.name,
    required this.imageUrl,
    required this.price,
  });

  factory NailShapeModel.fromJson(Map<String, dynamic> json) {
    return NailShapeModel(
      nailShapeId: _asInt(json['nailShapeId'] ?? json['NailShapeId']),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? json['ImageUrl'] ?? '').toString(),
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
