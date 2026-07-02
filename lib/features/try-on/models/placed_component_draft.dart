import 'dart:convert';

import '../../nails/data/models/component_model.dart';
import '../../nails/data/models/customer_nail_models.dart';
import '../utils/try_on_setup_helpers.dart';
import 'try_on_data.dart';

class PlacedComponentDraft {
  final int localId;
  final int? customerNailComponentId;
  final CombinedComponent? component;
  final int? componentId;
  final int? customerComponentId;
  final String name;
  final String imageUrl;
  final int fingerIndex;
  final double posX;
  final double posY;
  final double scale;
  final double rotation;

  const PlacedComponentDraft({
    required this.localId,
    this.customerNailComponentId,
    this.component,
    this.componentId,
    this.customerComponentId,
    required this.name,
    required this.imageUrl,
    required this.fingerIndex,
    required this.posX,
    required this.posY,
    required this.scale,
    required this.rotation,
  });

  PlacedComponentDraft copyWith({
    int? fingerIndex,
    double? posX,
    double? posY,
    double? scale,
    double? rotation,
  }) {
    return PlacedComponentDraft(
      localId: localId,
      customerNailComponentId: customerNailComponentId,
      component: component,
      componentId: componentId,
      customerComponentId: customerComponentId,
      name: name,
      imageUrl: imageUrl,
      fingerIndex: fingerIndex ?? this.fingerIndex,
      posX: posX ?? this.posX,
      posY: posY ?? this.posY,
      scale: scale ?? this.scale,
      rotation: rotation ?? this.rotation,
    );
  }

  String _buildConfigJson() {
    return jsonEncode({'scale': scale, 'rotation': rotation});
  }

  CustomerNailComponentPayload toPayload(int customerNailId) {
    return CustomerNailComponentPayload(
      customerNailId: customerNailId,
      componentId: componentId,
      customerComponentId: customerComponentId,
      posX: posX,
      posY: posY,
      fingerIndex: fingerIndexToApi(fingerIndex),
      configJson: _buildConfigJson(),
    );
  }

  CustomerNailComponentModel toCustomerNailComponent(int customerNailId) {
    return CustomerNailComponentModel(
      customerNailComponentId: customerNailComponentId ?? localId,
      customerNailId: customerNailId,
      componentId: componentId,
      customerComponentId: customerComponentId,
      posX: posX,
      posY: posY,
      fingerIndex: fingerIndex,
      configJson: _buildConfigJson(),
      component: _toComponentModel(),
      customerComponent: _toCustomerComponentModel(),
    );
  }

  ComponentModel? _toComponentModel() {
    if (componentId == null) return null;
    return ComponentModel(
      componentId: componentId!,
      name: name,
      imageUrl: imageUrl,
      componentType: component?.type.stringValue ?? 'gem',
      price: component?.price ?? 0,
    );
  }

  CustomerComponentModel? _toCustomerComponentModel() {
    if (customerComponentId == null) return null;
    return CustomerComponentModel(
      customerComponentId: customerComponentId!,
      name: name,
      imageUrl: imageUrl,
      componentType: component?.type.stringValue ?? 'gem',
      price: component?.price ?? 0,
      customDataJson: '',
      isPublic: false,
    );
  }

  factory PlacedComponentDraft.fromCustomerNailComponent(
    CustomerNailComponentModel item, {
    CombinedComponent? component,
  }) {
    final config = _decodeConfig(item.configJson);
    final scale = _asDouble(config['scale'], fallback: 0.35);
    final posX = _nullableDouble(config['x']) ?? item.posX;
    final posY = _nullableDouble(config['y']) ?? item.posY;

    return PlacedComponentDraft(
      localId: item.customerNailComponentId,
      customerNailComponentId: item.customerNailComponentId,
      component: component,
      componentId: item.componentId,
      customerComponentId: item.customerComponentId,
      name:
          component?.name ??
          item.component?.name ??
          item.customerComponent?.name ??
          'Component',
      imageUrl:
          component?.imageUrl ??
          item.component?.imageUrl ??
          item.customerComponent?.imageUrl ??
          _nullableString(config['imageSrc'] ?? config['imageUrl']) ??
          '',
      fingerIndex: item.fingerIndex,
      posX: posX,
      posY: posY,
      scale: scale > 0 ? scale : 0.35,
      rotation: _asDouble(config['rotation']),
    );
  }
}

class CustomerNailComponentPayload {
  final int customerNailId;
  final int? componentId;
  final int? customerComponentId;
  final double posX;
  final double posY;
  final int fingerIndex;
  final String configJson;

  const CustomerNailComponentPayload({
    required this.customerNailId,
    required this.componentId,
    required this.customerComponentId,
    required this.posX,
    required this.posY,
    required this.fingerIndex,
    required this.configJson,
  });
}

Map<String, dynamic> _decodeConfig(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return const {};
}

double _asDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

double? _nullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}

String? _nullableString(dynamic value) {
  final text = value?.toString();
  if (text == null || text.isEmpty) return null;
  return text;
}
