import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../../try-on/presentation/native_try_on_screen.dart';
import '../../try-on/services/nail_image_generator.dart';
import '../data/models/customer_nail_models.dart';
import '../data/models/nail_component_config.dart';
import '../data/models/nail_component_model.dart';
import '../data/models/nail_surface_model.dart';
import '../data/models/nail_variant_model.dart';

/// Service trung gian cho AR Try-On.
///
/// Refactor: Toàn bộ live/photo giờ chạy trong NailTryOnPlugin (native).
/// Service chỉ:
///  - Convert config (NailVariantModel / CustomerNailModel) -> Map.
///  - Gọi Navigator.push(NativeTryOnScreen) thay vì startActivity Native cũ.
///
/// Snapshot mode KHÔNG còn được hỗ trợ (chưa port sang plugin mới).
/// Caller có thể dùng launchCustomerLive thay thế.
class ArTryOnService {
  Future<bool> isAvailable() async {
    return Platform.isAndroid;
  }

  /// Mở camera Live overlay qua plugin Native.
  /// [context] là BuildContext của caller (button bấm). Navigator sẽ push từ đó.
  Future<void> launchLive(
    NailVariantModel nailVariant, {
    NailSurfaceModel? surface,
    BuildContext? context,
  }) {
    return _pushLiveScreen(
      _convertToArFormat(nailVariant, surface: surface),
      context: context,
    );
  }

  Future<void> launchPhoto(
    NailVariantModel nailVariant, {
    NailSurfaceModel? surface,
    BuildContext? context,
  }) {
    return _pushLiveScreen(
      _convertToArFormat(nailVariant, surface: surface),
      mode: 'photo',
      context: context,
    );
  }

  Future<void> launchCustomerLive(
    CustomerNailModel customerNail, {
    BuildContext? context,
  }) async {
    if (context == null) return;
    final designPaths = await NailImageGenerator.generate(context, customerNail);
    final config = _convertCustomerToArFormat(customerNail);
    config['designPaths'] = designPaths;
    
    return _pushLiveScreen(
      config,
      context: context,
    );
  }

  Future<void> launchCustomerPhoto(
    CustomerNailModel customerNail, {
    BuildContext? context,
  }) {
    return _pushLiveScreen(
      _convertCustomerToArFormat(customerNail),
      mode: 'photo',
      context: context,
    );
  }

  /// Snapshot mode KHÔNG còn được hỗ trợ bởi plugin mới.
  /// Caller nên dùng `launchCustomerLive` để live preview.
  Future<SnapshotResult> launchCustomerSnapshot(
    CustomerNailModel customerNail,
  ) async {
    throw UnsupportedError(
      'Snapshot mode chưa được port sang plugin mới. Dùng launchCustomerLive để live preview.',
    );
  }


  Future<void> launch(
    NailVariantModel nailVariant, {
    NailSurfaceModel? surface,
    BuildContext? context,
  }) {
    return launchLive(nailVariant, surface: surface, context: context);
  }

  // -------------------------------------------------------------------------
  // Internal helpers
  // -------------------------------------------------------------------------

  Future<void> _pushLiveScreen(
    Map<String, dynamic> config, {
    String mode = 'live',
    BuildContext? context,
  }) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Virtual try-on is only available on Android.');
    }
    final ctx = context;
    if (ctx == null) {
      throw StateError(
        'BuildContext is required to push NativeTryOnScreen. '
        'Pass context from the calling screen.',
      );
    }
    await Navigator.of(ctx).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => NativeTryOnScreen(config: config, mode: mode),
      ),
    );
  }

  // -------------------------------------------------------------------------
  // Config conversion (giữ nguyên từ bản cũ)
  // -------------------------------------------------------------------------

  Map<String, dynamic> _convertToArFormat(
    NailVariantModel nail, {
    NailSurfaceModel? surface,
  }) {
    final nailSurface = surface ?? nail.nailSurface;
    return {
      'shape': _normalizeShape(nail.nailShape?.name),
      'shapeImageSrc': _nullableText(nail.nailShape?.imageUrl),
      'length': 1.0,
      'material': _normalizeMaterial(
        nailSurface?.shaderParam.isNotEmpty == true
            ? nailSurface?.shaderParam
            : nailSurface?.name,
      ),
      'surface': _surfaceToArJson(nailSurface),
      'gradient': {
        'enabled': false,
        'type': 'linear',
        'stops': ['#FF4081', '#FFFFFF', '#000000'],
        'stopCount': 2,
      },
      'nails': _buildFingerDesigns(
        nail.nailComponents,
        _parseVariantColorJson(nail.colorJson),
      ),
    };
  }

  Map<String, dynamic> _convertCustomerToArFormat(CustomerNailModel nail) {
    return {
      'shape': _normalizeShape(nail.nailShape?.name),
      'shapeImageSrc': _nullableText(nail.nailShape?.imageUrl),
      'length': 1.0,
      'material': 'standard',
      'surface': _surfaceToArJson(nail.nailSurface),
      'gradient': {
        'enabled': false,
        'type': 'linear',
        'stops': ['#FF4081', '#FFFFFF', '#000000'],
        'stopCount': 2,
      },
      'nails': _buildCustomerFingerDesigns(
        nail.customerNailComponents,
        _parseVariantColorJson(nail.customColor),
      ),
    };
  }

  List<Map<String, dynamic>> _buildCustomerFingerDesigns(
    List<CustomerNailComponentModel> components,
    Map<int, _FingerAppearance> appearances,
  ) {
    return List.generate(5, (fingerIndex) {
      final fingerComponents = components
          .where((item) => _customerComponentAppliesToFinger(item, fingerIndex))
          .toList();
      final appearance = appearances[fingerIndex + 1];
      return {
        'color': appearance?.color ?? '#FF4081',
        'customShapeSrc': null,
        'gradient': appearance?.gradient,
        'decorations': fingerComponents
            .map(_customerComponentToDecoration)
            .toList(),
      };
    });
  }

  bool _customerComponentAppliesToFinger(
    CustomerNailComponentModel item,
    int zeroBasedFingerIndex,
  ) {
    if (item.fingerIndex == -1) return true;
    return item.fingerIndex == zeroBasedFingerIndex + 1;
  }

  Map<String, dynamic> _customerComponentToDecoration(
    CustomerNailComponentModel item,
  ) {
    final config = NailComponentConfig.fromJsonString(item.configJson);
    final imageUrl =
        config.imageSrc ??
        item.component?.imageUrl ??
        item.customerComponent?.imageUrl;
    final componentId =
        (item.componentId ??
                item.customerComponentId ??
                item.customerNailComponentId)
            .toString();
    final decoration = config.toArJson(
      fallbackImage: imageUrl,
      fallbackType: _normalizeComponentType(
        item.component?.componentType ?? item.customerComponent?.componentType,
      ),
      componentId: componentId,
    );
    decoration['x'] = config.x ?? item.posX;
    decoration['y'] = config.y ?? item.posY;
    decoration['id'] = item.customerNailComponentId.toString();
    return decoration;
  }

  List<Map<String, dynamic>> _buildFingerDesigns(
    List<NailComponentModel> components,
    Map<int, _FingerAppearance> appearances,
  ) {
    return List.generate(5, (fingerIndex) {
      final fingerComponents = components
          .where((item) => item.appliesToFinger(fingerIndex))
          .toList();
      final appearance = appearances[fingerIndex + 1];
      final color = fingerComponents
          .map((item) => item.config.color)
          .whereType<String>()
          .where((value) => value.isNotEmpty)
          .firstOrNull;
      final gradient = fingerComponents
          .map((item) => item.config.gradient)
          .whereType<Map<String, dynamic>>()
          .firstOrNull;
      return {
        'color': appearance?.color ?? color ?? '#FF4081',
        'customShapeSrc': null,
        'gradient': appearance?.gradient ?? gradient,
        'decorations': fingerComponents.map(_componentToDecoration).toList(),
      };
    });
  }

  Map<String, dynamic> _componentToDecoration(NailComponentModel item) {
    final config = item.config;
    final decoration = config.toArJson(
      fallbackImage: item.component?.imageUrl,
      fallbackType: _normalizeComponentType(item.component?.componentType),
      componentId: item.componentId.toString(),
    );
    decoration['x'] = config.x ?? item.posX;
    decoration['y'] = config.y ?? item.posY;
    decoration['id'] = item.nailComponentId.toString();
    return decoration;
  }

  String _normalizeShape(String? value) {
    final text = value?.trim().toLowerCase() ?? '';
    if (text.contains('stiletto')) return 'stiletto';
    if (text.contains('squoval')) return 'squoval';
    if (text.contains('ballerina')) return 'ballerina';
    return text.isEmpty ? 'ballerina' : text;
  }

  String? _nullableText(String? value) {
    final text = value?.trim();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  String _normalizeMaterial(String? value) {
    final text = value?.trim().toLowerCase() ?? '';
    if (text.contains('metal')) return 'metallic';
    if (text.contains('iridescent')) return 'iridescent';
    if (text.contains('matte')) return 'matte';
    return 'standard';
  }

  Map<String, dynamic>? _surfaceToArJson(NailSurfaceModel? surface) {
    if (surface == null) return null;
    return {
      'name': surface.name,
      'shaderParam': surface.shaderParam,
      'lightnessOffset': surface.lightnessOffset,
      'saturationOffset': surface.saturationOffset,
      'hueOffset': surface.hueOffset,
    };
  }

  String _normalizeComponentType(String? value) {
    final text = value?.trim().toLowerCase() ?? '';
    if (text.contains('gem') || text == '1') return 'gem';
    return 'pattern';
  }

  Map<int, _FingerAppearance> _parseVariantColorJson(String? colorJson) {
    if (colorJson == null || colorJson.trim().isEmpty) {
      return const <int, _FingerAppearance>{};
    }

    try {
      final decoded = jsonDecode(colorJson);
      if (decoded is List) {
        return {
          for (var i = 0; i < decoded.length && i < 5; i++)
            i + 1: _FingerAppearance(color: decoded[i]?.toString()),
        };
      }

      final map = decoded is Map<String, dynamic>
          ? decoded
          : decoded is Map
          ? Map<String, dynamic>.from(decoded)
          : null;
      if (map == null) return const <int, _FingerAppearance>{};

      if (map['mode'] == 'perFinger') {
        final fingers = map['fingers'];
        if (fingers is! List) return const <int, _FingerAppearance>{};
        return {
          for (final finger in fingers.whereType<Map>())
            _asInt(
              finger['fingerIndex'] ?? finger['FingerIndex'],
            ): _FingerAppearance(
              color: _asString(finger['color'] ?? finger['Color']),
              gradient: _asMap(finger['gradient'] ?? finger['Gradient']),
            ),
        }..removeWhere((index, _) => index < 1 || index > 5);
      }

      final color = _asString(map['color'] ?? map['Color']);
      final gradient = _asMap(map['gradient'] ?? map['Gradient']);
      if (color == null && gradient == null) {
        return const <int, _FingerAppearance>{};
      }
      return {
        for (var index = 1; index <= 5; index++)
          index: _FingerAppearance(color: color, gradient: gradient),
      };
    } catch (_) {
      return const <int, _FingerAppearance>{};
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String? _asString(dynamic value) {
    final text = value?.toString();
    if (text == null || text.isEmpty) return null;
    return text;
  }

  Map<String, dynamic>? _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return Map<String, dynamic>.from(value);
    return null;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _FingerAppearance {
  final String? color;
  final Map<String, dynamic>? gradient;

  const _FingerAppearance({this.color, this.gradient});
}

// =============================================================================
// Snapshot Result Models (giữ nguyên cho snapshot screens khác dùng lại)
// =============================================================================

/// Kết quả trả về từ Native sau khi chụp Snapshot và phân tích MediaPipe.
class SnapshotResult {
  final String imagePath;
  final List<FingerLandmark> landmarks;

  const SnapshotResult({required this.imagePath, required this.landmarks});

  factory SnapshotResult.fromJson(String imagePath, String jsonStr) {
    final list = jsonDecode(jsonStr) as List<dynamic>;
    return SnapshotResult(
      imagePath: imagePath,
      landmarks: list
          .map((item) => FingerLandmark.fromMap(item as Map<dynamic, dynamic>))
          .toList(),
    );
  }

  bool get hasHand => landmarks.isNotEmpty;
}

/// Tọa độ và góc xoay của một ngón tay.
class FingerLandmark {
  final String finger;
  final int fingerIndex;
  final double baseX;
  final double baseY;
  final double baseRotation;
  final double baseScale;
  final int imageWidth;
  final int imageHeight;

  const FingerLandmark({
    required this.finger,
    required this.fingerIndex,
    required this.baseX,
    required this.baseY,
    required this.baseRotation,
    required this.baseScale,
    required this.imageWidth,
    required this.imageHeight,
  });

  factory FingerLandmark.fromMap(Map<dynamic, dynamic> map) {
    return FingerLandmark(
      finger: map['finger'] as String? ?? '',
      fingerIndex: (map['fingerIndex'] as num?)?.toInt() ?? 0,
      baseX: (map['baseX'] as num?)?.toDouble() ?? 0,
      baseY: (map['baseY'] as num?)?.toDouble() ?? 0,
      baseRotation: (map['baseRotation'] as num?)?.toDouble() ?? 0,
      baseScale: (map['baseScale'] as num?)?.toDouble() ?? 1,
      imageWidth: (map['imageWidth'] as num?)?.toInt() ?? 1,
      imageHeight: (map['imageHeight'] as num?)?.toInt() ?? 1,
    );
  }
}