import 'dart:convert';

class NailComponentConfig {
  final double scale;
  final double rotation;
  final String? color;
  final Map<String, dynamic>? gradient;
  final String? type;
  final String? imageSrc;
  final double? x;
  final double? y;

  const NailComponentConfig({
    this.scale = 0.25,
    this.rotation = 0,
    this.color,
    this.gradient,
    this.type,
    this.imageSrc,
    this.x,
    this.y,
  });

  factory NailComponentConfig.fromJsonString(String jsonString) {
    return NailComponentConfig.fromJsonValue(jsonString);
  }

  factory NailComponentConfig.fromJsonValue(dynamic value) {
    if (value == null) return const NailComponentConfig();
    if (value is Map<String, dynamic>) return NailComponentConfig.fromMap(value);
    if (value is Map) return NailComponentConfig.fromMap(Map<String, dynamic>.from(value));

    final jsonString = value.toString();
    if (jsonString.trim().isEmpty) return const NailComponentConfig();
    try {
      final decoded = jsonDecode(jsonString);
      if (decoded is Map<String, dynamic>) return NailComponentConfig.fromMap(decoded);
      if (decoded is Map) return NailComponentConfig.fromMap(Map<String, dynamic>.from(decoded));
    } catch (_) {
      return const NailComponentConfig();
    }
    return const NailComponentConfig();
  }

  factory NailComponentConfig.fromMap(Map<String, dynamic> json) {
    return NailComponentConfig(
      scale: _asDouble(json['scale'], fallback: 0.25),
      rotation: _asDouble(json['rotation']),
      color: _asNullableString(json['color']),
      gradient: _asNullableMap(json['gradient']),
      type: _asNullableString(json['type']),
      imageSrc: _asNullableString(json['imageSrc'] ?? json['imageUrl']),
      x: json.containsKey('x') ? _asDouble(json['x']) : null,
      y: json.containsKey('y') ? _asDouble(json['y']) : null,
    );
  }

  Map<String, dynamic> toArJson({String? fallbackImage, String? fallbackType, String? componentId}) {
    return {
      'id': componentId ?? '',
      'type': type ?? fallbackType ?? 'pattern',
      'componentId': componentId,
      'imageSrc': imageSrc ?? fallbackImage ?? '',
      'x': x ?? 0,
      'y': y ?? 0,
      'scale': scale,
      'rotation': rotation,
    };
  }

  static String? _asNullableString(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  static Map<String, dynamic>? _asNullableMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }

  static double _asDouble(dynamic value, {double fallback = 0}) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
