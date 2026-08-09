import 'dart:convert';

import 'nail_component_model.dart';
import 'nail_shape_model.dart';
import 'nail_surface_model.dart';

class NailVariantModel {
  final int nailVariantId;
  final String name;
  final int nailShapeId;
  final int nailSurfaceId;
  final int nailDesignId;
  final double price;
  final double? estimatedPrice;
  final int? duration;
  final String imageUrl;
  final String? colorJson;
  final NailShapeModel? nailShape;
  final NailSurfaceModel? nailSurface;
  final List<NailComponentModel> nailComponents;
  final bool isFavorited;
  final int? favoriteNailId;

  const NailVariantModel({
    required this.nailVariantId,
    required this.name,
    required this.nailShapeId,
    required this.nailSurfaceId,
    required this.nailDesignId,
    required this.price,
    this.estimatedPrice,
    required this.duration,
    required this.imageUrl,
    this.colorJson,
    this.nailShape,
    this.nailSurface,
    this.nailComponents = const [],
    this.isFavorited = false,
    this.favoriteNailId,
  });

  NailVariantModel copyWith({
    bool? isFavorited,
    int? favoriteNailId,
    bool clearFavoriteNailId = false,
  }) {
    return NailVariantModel(
      nailVariantId: nailVariantId,
      name: name,
      nailShapeId: nailShapeId,
      nailSurfaceId: nailSurfaceId,
      nailDesignId: nailDesignId,
      price: price,
      estimatedPrice: estimatedPrice,
      duration: duration,
      imageUrl: imageUrl,
      colorJson: colorJson,
      nailShape: nailShape,
      nailSurface: nailSurface,
      nailComponents: nailComponents,
      isFavorited: isFavorited ?? this.isFavorited,
      favoriteNailId: clearFavoriteNailId
          ? null
          : favoriteNailId ?? this.favoriteNailId,
    );
  }

  factory NailVariantModel.fromJson(Map<String, dynamic> json) {
    final shapeJson = json['nailShape'] ?? json['NailShape'];
    final surfaceJson = json['nailSurface'] ?? json['NailSurface'];
    final componentsJson =
        json['nailComponents'] ?? json['NailComponents'] ?? [];
    return NailVariantModel(
      nailVariantId: _asInt(json['nailVariantId'] ?? json['NailVariantId']),
      name: (json['name'] ?? json['Name'] ?? '').toString(),
      nailShapeId: _asInt(json['nailShapeId'] ?? json['NailShapeId']),
      nailSurfaceId: _asInt(json['nailSurfaceId'] ?? json['NailSurfaceId']),
      nailDesignId: _asInt(json['nailDesignId'] ?? json['NailDesignId']),
      price: _asDouble(json['price'] ?? json['Price']),
      estimatedPrice: _asNullableDouble(
        json['estimatedPrice'] ?? json['EstimatedPrice'],
      ),
      duration: _asNullableInt(json['duration'] ?? json['Duration']),
      imageUrl:
          (json['imageUrl'] ??
                  json['ImageUrl'] ??
                  json['image'] ??
                  json['Image'] ??
                  '')
              .toString(),
      colorJson: _asNullableJsonString(json['colorJson'] ?? json['ColorJson']),
      nailShape: shapeJson is Map
          ? NailShapeModel.fromJson(Map<String, dynamic>.from(shapeJson))
          : null,
      nailSurface: surfaceJson is Map
          ? NailSurfaceModel.fromJson(Map<String, dynamic>.from(surfaceJson))
          : null,
      nailComponents: componentsJson is List
          ? componentsJson
                .whereType<Map>()
                .map(
                  (item) => NailComponentModel.fromJson(
                    Map<String, dynamic>.from(item),
                  ),
                )
                .toList()
          : const [],
      isFavorited: _asBool(json['isFavorited'] ?? json['IsFavorited']),
      favoriteNailId: _asNullableInt(
        json['favoriteNailId'] ?? json['FavoriteNailId'],
      ),
    );
  }

  static int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _asNullableInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double? _asNullableDouble(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static String? _asNullableJsonString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.isEmpty ? null : value;
    if (value is Map || value is List) return jsonEncode(value);
    final text = value.toString();
    return text.isEmpty ? null : text;
  }

  static bool _asBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase().trim();
    return text == 'true' || text == '1';
  }
}
