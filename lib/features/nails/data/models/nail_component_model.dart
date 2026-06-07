import 'dart:convert';

import 'component_model.dart';
import 'nail_component_config.dart';

class NailComponentModel {
  final int nailComponentId;
  final int componentId;
  final int nailVariantId;
  final double posX;
  final double posY;
  final int fingerIndex;
  final String configJson;
  final ComponentModel? component;

  const NailComponentModel({
    required this.nailComponentId,
    required this.componentId,
    required this.nailVariantId,
    required this.posX,
    required this.posY,
    required this.fingerIndex,
    required this.configJson,
    this.component,
  });

  NailComponentConfig get config => NailComponentConfig.fromJsonValue(configJson);

  factory NailComponentModel.fromJson(Map<String, dynamic> json) {
    final componentJson = json['component'] ?? json['Component'];
    return NailComponentModel(
      nailComponentId: _asInt(json['nailComponentId'] ?? json['NailComponentId']),
      componentId: _asInt(json['componentId'] ?? json['ComponentId']),
      nailVariantId: _asInt(json['nailVariantId'] ?? json['NailVariantId']),
      posX: _asDouble(json['posX'] ?? json['PosX']),
      posY: _asDouble(json['posY'] ?? json['PosY']),
      fingerIndex: _asInt(json['fingerIndex'] ?? json['FingerIndex'], fallback: -1),
      configJson: _asConfigJson(json['configJson'] ?? json['ConfigJson']),
      component: componentJson is Map ? ComponentModel.fromJson(Map<String, dynamic>.from(componentJson)) : null,
    );
  }

  bool appliesToFinger(int zeroBasedFingerIndex) {
    if (fingerIndex == -1) return true;
    return fingerIndex == zeroBasedFingerIndex + 1;
  }

  static int _asInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _asConfigJson(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }
}
