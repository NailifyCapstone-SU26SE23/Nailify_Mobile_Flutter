class NailSurfaceModel {
  final int nailSurfaceId;
  final String name;
  final String shaderParam;
  final double lightnessOffset;
  final double saturationOffset;
  final double hueOffset;
  final double price;
  final int? duration;

  const NailSurfaceModel({
    required this.nailSurfaceId,
    required this.name,
    required this.shaderParam,
    this.lightnessOffset = 0,
    this.saturationOffset = 0,
    this.hueOffset = 0,
    required this.price,
    this.duration,
  });

  factory NailSurfaceModel.fromJson(Map<String, dynamic> json) {
    return NailSurfaceModel(
      nailSurfaceId: _asInt(json['nailSurfaceId'] ?? json['NailSurfaceId']),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      shaderParam: (json['shaderParam'] ?? json['ShaderParam'] ?? '').toString(),
      lightnessOffset: _asDouble(json['lightnessOffset'] ?? json['LightnessOffset']),
      saturationOffset: _asDouble(json['saturationOffset'] ?? json['SaturationOffset']),
      hueOffset: _asDouble(json['hueOffset'] ?? json['HueOffset']),
      price: _asDouble(json['price'] ?? json['Price']),
      duration: _asNullableInt(json['duration'] ?? json['Duration']),
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

  static int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }
}
