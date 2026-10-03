class ShapeMethodConfigModel {
  final int shapeMethodConfigId;
  final int nailShapeId;
  final String nailShapeName;
  final String name;
  final double price;
  final int duration;
  final String status;

  const ShapeMethodConfigModel({
    required this.shapeMethodConfigId,
    required this.nailShapeId,
    required this.nailShapeName,
    required this.name,
    required this.price,
    required this.duration,
    required this.status,
  });

  factory ShapeMethodConfigModel.fromJson(Map<String, dynamic> json) {
    return ShapeMethodConfigModel(
      shapeMethodConfigId: _asInt(
        json['shapeMethodConfigId'] ?? json['ShapeMethodConfigId'],
      ),
      nailShapeId: _asInt(json['nailShapeId'] ?? json['NailShapeId']),
      nailShapeName: (json['nailShapeName'] ?? json['NailShapeName'] ?? '')
          .toString(),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      price: _asDouble(json['price'] ?? json['Price']),
      duration: _asInt(json['duration'] ?? json['Duration']),
      status: (json['status'] ?? json['Status'] ?? '').toString(),
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
