import '../../../nails/data/models/component_model.dart';
import '../../../nails/data/models/nail_shape_model.dart';
import '../../../nails/data/models/nail_surface_model.dart';

class CustomerNailModel {
  final int customerNailId;
  final String name;
  final String imageUrl;
  final int? nailShapeId;
  final int? nailSurfaceId;
  final double? price;
  final String? customColor;
  final int? duration;
  final NailShapeModel? nailShape;
  final NailSurfaceModel? nailSurface;
  final List<CustomerNailComponentModel> customerNailComponents;

  const CustomerNailModel({
    required this.customerNailId,
    required this.name,
    required this.imageUrl,
    this.nailShapeId,
    this.nailSurfaceId,
    this.price,
    this.customColor,
    this.duration,
    this.nailShape,
    this.nailSurface,
    this.customerNailComponents = const [],
  });

  factory CustomerNailModel.fromJson(Map<String, dynamic> json) {
    final shapeJson = json['nailShape'] ?? json['NailShape'];
    final surfaceJson = json['nailSurface'] ?? json['NailSurface'];
    final componentsJson =
        json['customerNailComponents'] ?? json['CustomerNailComponents'] ?? [];

    return CustomerNailModel(
      customerNailId: _asInt(json['customerNailId'] ?? json['CustomerNailId']),
      name: _asString(json['name'] ?? json['Name']),
      imageUrl: _asString(json['imageUrl'] ?? json['ImageUrl']),
      nailShapeId: _asNullableInt(json['nailShapeId'] ?? json['NailShapeId']),
      nailSurfaceId: _asNullableInt(
        json['nailSurfaceId'] ?? json['NailSurfaceId'],
      ),
      price: _asNullableDouble(json['price'] ?? json['Price']),
      customColor: _asString(json['customColor'] ?? json['CustomColor']),
      duration: _asNullableInt(json['duration'] ?? json['Duration']),
      nailShape: shapeJson is Map
          ? NailShapeModel.fromJson(Map<String, dynamic>.from(shapeJson))
          : null,
      nailSurface: surfaceJson is Map
          ? NailSurfaceModel.fromJson(Map<String, dynamic>.from(surfaceJson))
          : null,
      customerNailComponents: componentsJson is List
          ? componentsJson
                .whereType<Map>()
                .map(
                  (item) => CustomerNailComponentModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
    );
  }
}

class CustomerNailComponentModel {
  final int customerNailComponentId;
  final int customerNailId;
  final int? componentId;
  final int? customerComponentId;
  final double posX;
  final double posY;
  final int fingerIndex;
  final String configJson;
  final ComponentModel? component;
  final CustomerComponentModel? customerComponent;

  const CustomerNailComponentModel({
    required this.customerNailComponentId,
    required this.customerNailId,
    required this.componentId,
    required this.customerComponentId,
    required this.posX,
    required this.posY,
    required this.fingerIndex,
    required this.configJson,
    this.component,
    this.customerComponent,
  });

  factory CustomerNailComponentModel.fromJson(Map<String, dynamic> json) {
    final componentJson = json['component'] ?? json['Component'];
    final customerComponentJson =
        json['customerComponent'] ?? json['CustomerComponent'];
    return CustomerNailComponentModel(
      customerNailComponentId: _asInt(
        json['customerNailComponentId'] ?? json['CustomerNailComponentId'],
      ),
      customerNailId: _asInt(json['customerNailId'] ?? json['CustomerNailId']),
      componentId: _asNullableInt(json['componentId'] ?? json['ComponentId']),
      customerComponentId: _asNullableInt(
        json['customerComponentId'] ?? json['CustomerComponentId'],
      ),
      posX: _asDouble(json['posX'] ?? json['PosX']),
      posY: _asDouble(json['posY'] ?? json['PosY']),
      fingerIndex: _normalizeFingerIndexFromApi(
        _asInt(json['fingerIndex'] ?? json['FingerIndex'], fallback: -1),
      ),
      configJson: (json['configJson'] ?? json['ConfigJson'] ?? '').toString(),
      component: componentJson is Map
          ? ComponentModel.fromJson(Map<String, dynamic>.from(componentJson))
          : null,
      customerComponent: customerComponentJson is Map
          ? CustomerComponentModel.fromJson(
              Map<String, dynamic>.from(customerComponentJson),
            )
          : null,
    );
  }
}

class CustomerComponentModel {
  final int customerComponentId;
  final String name;
  final String imageUrl;
  final String componentType;
  final double price;
  final String customDataJson;

  const CustomerComponentModel({
    required this.customerComponentId,
    required this.name,
    required this.imageUrl,
    required this.componentType,
    required this.price,
    required this.customDataJson,
  });

  factory CustomerComponentModel.fromJson(Map<String, dynamic> json) {
    return CustomerComponentModel(
      customerComponentId: _asInt(
        json['customerComponentId'] ?? json['CustomerComponentId'],
      ),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      imageUrl: (json['imageUrl'] ?? json['ImageUrl'] ?? '').toString(),
      componentType: (json['componentType'] ?? json['ComponentType'] ?? '')
          .toString(),
      price: _asDouble(json['price'] ?? json['Price']),
      customDataJson: (json['customDataJson'] ?? json['CustomDataJson'] ?? '')
          .toString(),
    );
  }
}

int _asInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

int _normalizeFingerIndexFromApi(int stored) {
  if (stored == -1) return -1;
  if (stored >= 0 && stored <= 4) return stored + 1;
  return stored.clamp(1, 5);
}

int? _asNullableInt(dynamic value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

String _asString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  return value.toString();
}

double? _asNullableDouble(dynamic value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return double.tryParse(value.toString());
}
