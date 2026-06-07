class NailSurfaceModel {
  final int nailSurfaceId;
  final String name;
  final String shaderParam;
  final double price;

  const NailSurfaceModel({
    required this.nailSurfaceId,
    required this.name,
    required this.shaderParam,
    required this.price,
  });

  factory NailSurfaceModel.fromJson(Map<String, dynamic> json) {
    return NailSurfaceModel(
      nailSurfaceId: _asInt(json['nailSurfaceId'] ?? json['NailSurfaceId']),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      shaderParam: (json['shaderParam'] ?? json['ShaderParam'] ?? '').toString(),
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
