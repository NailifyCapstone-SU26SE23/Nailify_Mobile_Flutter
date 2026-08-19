import 'dart:convert';

class ColorFingerConfig {
  final int fingerIndex;
  final String color;

  ColorFingerConfig({required this.fingerIndex, required this.color});

  factory ColorFingerConfig.fromJson(Map<String, dynamic> json) {
    return ColorFingerConfig(
      fingerIndex: json['fingerIndex'] ?? -1,
      color: json['color'] ?? '#FF0000',
    );
  }
}

class ColorJsonConfig {
  final String mode; // 'perFinger', 'solid', 'gradient'
  final List<ColorFingerConfig> fingers;

  ColorJsonConfig({required this.mode, required this.fingers});

  factory ColorJsonConfig.fromJson(String rawJson) {
    try {
      final Map<String, dynamic> data = jsonDecode(rawJson);
      final String mode = data['mode'] ?? 'solid';
      final List<dynamic> fingerList = data['fingers'] ?? [];

      return ColorJsonConfig(
        mode: mode,
        fingers: fingerList.map((f) => ColorFingerConfig.fromJson(f)).toList(),
      );
    } catch (_) {
      return ColorJsonConfig(mode: 'solid', fingers: []);
    }
  }
}

class NailShape {
  final int nailShapeId;
  final String name;
  final String imageUrl;

  NailShape({
    required this.nailShapeId,
    required this.name,
    required this.imageUrl,
  });

  factory NailShape.fromJson(Map<String, dynamic> json) {
    return NailShape(
      nailShapeId: json['nailShapeId'] ?? 0,
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
    );
  }
}

/// Parsed representation of NailSurface.shaderParam. Supports both BE formats:
/// - {"reflectivity":0.95, "metallic":1.0}                       (Chrome)
/// - {"texture":{"type":"matte","roughness":0.85},"shine":{"enabled":false}}
/// - {"texture":{"type":"glossy"},"shine":{"opacity":1}}
class SurfaceShaderParams {
  final String textureType; // '', 'glossy', 'matte', 'chrome', 'cateye'...
  final double roughness;
  final double reflectivity;
  final double metallic;
  final bool shineEnabled;
  final double shineOpacity;

  const SurfaceShaderParams({
    this.textureType = '',
    this.roughness = 0.5,
    this.reflectivity = 0.9,
    this.metallic = 0.0,
    this.shineEnabled = true,
    this.shineOpacity = 1.0,
  });

  factory SurfaceShaderParams.fromRaw(String rawJson) {
    try {
      final data = jsonDecode(rawJson);
      if (data is! Map<String, dynamic>) return const SurfaceShaderParams();
      final texture = data['texture'];
      final shine = data['shine'];
      return SurfaceShaderParams(
        textureType:
            (texture is Map ? texture['type'] : null)?.toString() ?? '',
        roughness: _toDouble(texture is Map ? texture['roughness'] : null, 0.5),
        reflectivity: _toDouble(data['reflectivity'], 0.9),
        metallic: _toDouble(data['metallic'], 0.0),
        shineEnabled: (shine is Map ? shine['enabled'] : null) as bool? ?? true,
        shineOpacity: _toDouble(shine is Map ? shine['opacity'] : null, 1.0),
      );
    } catch (_) {
      return const SurfaceShaderParams();
    }
  }

  static double _toDouble(dynamic v, double def) =>
      (v as num?)?.toDouble() ?? def;

  /// Resolves the effect type: explicit texture.type wins, then metallic
  /// implies chrome, then the surface display name as fallback.
  String resolveType(String surfaceName) {
    final t = textureType.toLowerCase();
    if (t.contains('chrome') || t.contains('metallic')) return 'chrome';
    if (t.contains('cateye') || t.contains('cat eye')) return 'cateye';
    if (t.contains('matte')) return 'matte';
    if (t.contains('gloss')) return 'glossy';
    if (metallic >= 0.5) return 'chrome';
    final n = surfaceName.toLowerCase();
    if (n.contains('chrome') || n.contains('metallic')) return 'chrome';
    if (n.contains('cateye') || n.contains('cat eye')) return 'cateye';
    if (n.contains('matte')) return 'matte';
    return 'glossy';
  }
}

class NailSurface {
  final int nailSurfaceId;
  final String name;
  final String shaderParam;
  final SurfaceShaderParams params;
  final double lightnessOffset;
  final double saturationOffset;
  final double hueOffset;

  NailSurface({
    required this.nailSurfaceId,
    required this.name,
    required this.shaderParam,
    this.params = const SurfaceShaderParams(),
    required this.lightnessOffset,
    required this.saturationOffset,
    required this.hueOffset,
  });

  factory NailSurface.fromJson(Map<String, dynamic> json) {
    final String rawShaderParam = json['shaderParam'] ?? '{}';
    return NailSurface(
      nailSurfaceId: json['nailSurfaceId'] ?? 0,
      name: json['name'] ?? '',
      shaderParam: rawShaderParam,
      params: SurfaceShaderParams.fromRaw(rawShaderParam),
      lightnessOffset: (json['lightnessOffset'] as num?)?.toDouble() ?? 0.0,
      saturationOffset: (json['saturationOffset'] as num?)?.toDouble() ?? 0.0,
      hueOffset: (json['hueOffset'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

class ComponentDetail {
  final int componentId;
  final String name;
  final String imageUrl;
  final String componentType; // 'Sticker', 'Charm', etc.

  ComponentDetail({
    required this.componentId,
    required this.name,
    required this.imageUrl,
    required this.componentType,
  });

  factory ComponentDetail.fromJson(Map<String, dynamic> json) {
    return ComponentDetail(
      componentId: json['componentId'] ?? 0,
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      componentType: json['componentType'] ?? 'Sticker',
    );
  }
}

class NailComponentItem {
  final int nailComponentId;
  final double posX; // Normalized -1.0 to 1.0
  final double posY; // Normalized -1.0 to 1.0
  final int fingerIndex; // -1 for all fingers, 1-5 for specific
  final double scale;
  final double rotation;
  final ComponentDetail component;

  NailComponentItem({
    required this.nailComponentId,
    required this.posX,
    required this.posY,
    required this.fingerIndex,
    required this.scale,
    required this.rotation,
    required this.component,
  });

  factory NailComponentItem.fromJson(Map<String, dynamic> json) {
    double scale = 1.0;
    double rotation = 0.0;

    if (json['configJson'] != null) {
      try {
        final config = jsonDecode(json['configJson']);
        scale = (config['scale'] as num?)?.toDouble() ?? 1.0;
        rotation = (config['rotation'] as num?)?.toDouble() ?? 0.0;
      } catch (_) {}
    }

    return NailComponentItem(
      nailComponentId: json['nailComponentId'] ?? 0,
      posX: (json['posX'] as num?)?.toDouble() ?? 0.0,
      posY: (json['posY'] as num?)?.toDouble() ?? 0.0,
      fingerIndex: json['fingerIndex'] ?? -1,
      scale: scale,
      rotation: rotation,
      component: ComponentDetail.fromJson(json['component'] ?? {}),
    );
  }

  NailComponentItem copyWith({
    int? nailComponentId,
    double? posX,
    double? posY,
    int? fingerIndex,
    double? scale,
    double? rotation,
    ComponentDetail? component,
  }) {
    return NailComponentItem(
      nailComponentId: nailComponentId ?? this.nailComponentId,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      fingerIndex: fingerIndex ?? this.fingerIndex,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
      component: component ?? this.component,
    );
  }
}

class NailVariantModel {
  final int nailVariantId;
  final String name;
  final String imageUrl;
  final ColorJsonConfig colorConfig;
  final NailShape nailShape;
  final NailSurface nailSurface;
  final List<NailComponentItem> nailComponents;

  NailVariantModel({
    required this.nailVariantId,
    required this.name,
    required this.imageUrl,
    required this.colorConfig,
    required this.nailShape,
    required this.nailSurface,
    required this.nailComponents,
  });

  factory NailVariantModel.fromJson(Map<String, dynamic> json) {
    return NailVariantModel(
      nailVariantId: json['nailVariantId'] ?? 0,
      name: json['name'] ?? '',
      imageUrl: json['imageUrl'] ?? '',
      colorConfig: ColorJsonConfig.fromJson(json['colorJson'] ?? '{}'),
      nailShape: NailShape.fromJson(json['nailShape'] ?? {}),
      nailSurface: NailSurface.fromJson(json['nailSurface'] ?? {}),
      nailComponents: (json['nailComponents'] as List<dynamic>? ?? [])
          .map((c) => NailComponentItem.fromJson(c))
          .toList(),
    );
  }

  NailVariantModel copyWith({
    int? nailVariantId,
    String? name,
    String? imageUrl,
    ColorJsonConfig? colorConfig,
    NailShape? nailShape,
    NailSurface? nailSurface,
    List<NailComponentItem>? nailComponents,
  }) {
    return NailVariantModel(
      nailVariantId: nailVariantId ?? this.nailVariantId,
      name: name ?? this.name,
      imageUrl: imageUrl ?? this.imageUrl,
      colorConfig: colorConfig ?? this.colorConfig,
      nailShape: nailShape ?? this.nailShape,
      nailSurface: nailSurface ?? this.nailSurface,
      nailComponents: nailComponents ?? this.nailComponents,
    );
  }
}
