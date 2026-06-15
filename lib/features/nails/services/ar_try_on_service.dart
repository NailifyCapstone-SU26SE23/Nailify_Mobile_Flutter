import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';

import '../data/models/customer_nail_models.dart';
import '../data/models/nail_component_config.dart';
import '../data/models/nail_component_model.dart';
import '../data/models/nail_variant_model.dart';

class ArTryOnService {
  static const MethodChannel _channel = MethodChannel('com.nailify.ar/tryon');

  Future<bool> isAvailable() async {
    if (!Platform.isAndroid) return false;
    return await _channel.invokeMethod<bool>('isAvailable') ?? false;
  }

  Future<void> launchLive(NailVariantModel nailVariant) {
    return _launch(nailVariant, mode: 'live');
  }

  Future<void> launchPhoto(NailVariantModel nailVariant) {
    return _launch(nailVariant, mode: 'photo');
  }

  Future<void> launchCustomerLive(CustomerNailModel customerNail) {
    return _launchConfig(_convertCustomerToArFormat(customerNail), mode: 'live');
  }

  Future<void> launchCustomerPhoto(CustomerNailModel customerNail) {
    return _launchConfig(_convertCustomerToArFormat(customerNail), mode: 'photo');
  }

  Future<void> launch(NailVariantModel nailVariant) {
    return launchLive(nailVariant);
  }

  Future<void> _launch(NailVariantModel nailVariant, {required String mode}) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Virtual try-on is only available on Android.');
    }
    await _launchConfig(_convertToArFormat(nailVariant), mode: mode);
  }

  Future<void> _launchConfig(Map<String, dynamic> config, {required String mode}) async {
    if (!Platform.isAndroid) {
      throw UnsupportedError('Virtual try-on is only available on Android.');
    }
    await _channel.invokeMethod<void>('launch', {
      'config': config,
      'mode': mode,
    });
  }

  Map<String, dynamic> _convertToArFormat(NailVariantModel nail) {
    return {
      'shape': _normalizeShape(nail.nailShape?.name),
      'shapeImageSrc': _nullableText(nail.nailShape?.imageUrl),
      'length': 1.0,
      'material': _normalizeMaterial(
        nail.nailSurface?.shaderParam.isNotEmpty == true
            ? nail.nailSurface?.shaderParam
            : nail.nailSurface?.name,
      ),
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
        'decorations': fingerComponents.map(_customerComponentToDecoration).toList(),
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

  Map<String, dynamic> _customerComponentToDecoration(CustomerNailComponentModel item) {
    final config = NailComponentConfig.fromJsonString(item.configJson);
    final imageUrl = config.imageSrc ?? item.component?.imageUrl ?? item.customerComponent?.imageUrl;
    final componentId = (item.componentId ?? item.customerComponentId ?? item.customerNailComponentId).toString();
    final decoration = config.toArJson(
      fallbackImage: imageUrl,
      fallbackType: _normalizeComponentType(item.component?.componentType ?? item.customerComponent?.componentType),
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
        'color': color ?? appearance?.color ?? '#FF4081',
        'customShapeSrc': null,
        'gradient': gradient ?? appearance?.gradient,
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
            _asInt(finger['fingerIndex'] ?? finger['FingerIndex']):
                _FingerAppearance(
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
