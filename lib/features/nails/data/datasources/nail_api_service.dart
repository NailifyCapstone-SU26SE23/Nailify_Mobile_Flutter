import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/paginated_response.dart';
import '../models/category_type_model.dart';
import '../models/component_model.dart';
import '../models/customer_nail_models.dart';
import '../models/nail_design_model.dart';
import '../models/nail_shape_model.dart';
import '../models/nail_surface_model.dart';
import '../models/nail_variant_model.dart';

class NailApiService {
  final ApiClient _apiClient;

  NailApiService(this._apiClient);

  Future<PaginatedResponse<NailDesignModel>> getNailDesigns({
    required int page,
    int pageSize = 10,
    String? name,
    List<int> categoryIds = const [],
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/NailDesigns',
      queryParameters: {
        'pageNumber': page,
        'pageSize': pageSize,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (categoryIds.isNotEmpty) 'categoryIds': categoryIds,
      },
    );
    return PaginatedResponse.fromJson(
      response.data,
          (json) => NailDesignModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<NailDesignModel> getNailDesignById(int id) async {
    final response = await _apiClient.get<dynamic>('/NailDesigns/$id');
    return NailDesignModel.fromJson(_unwrapMap(response.data));
  }

  Future<List<CategoryTypeModel>> getCategoryTypes({
    int page = 1,
    int pageSize = 100,
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/CategoryTypes',
      queryParameters: {
        'pageNumber': page,
        'pageSize': pageSize,
      },
    );
    final paginatedResponse = PaginatedResponse.fromJson(
      response.data,
          (json) => CategoryTypeModel.fromJson(json as Map<String, dynamic>),
    );
    return paginatedResponse.items;
  }

  Future<PaginatedResponse<NailVariantModel>> getNailVariants({
    required int page,
    int pageSize = 10,
    int? shapeId,
    int? surfaceId,
    double? minPrice,
    double? maxPrice,
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/NailVariants',
      queryParameters: {
        'pageNumber': page,
        'pageSize': pageSize,
        if (shapeId != null) 'nailShapeId': shapeId,
        if (surfaceId != null) 'nailSurfaceId': surfaceId,
        if (minPrice != null) 'minPrice': minPrice,
        if (maxPrice != null) 'maxPrice': maxPrice,
      },
    );
    return PaginatedResponse.fromJson(
      response.data,
          (json) => NailVariantModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<NailVariantModel> getNailVariantById(int id) async {
    final response = await _apiClient.get<dynamic>('/NailVariants/$id');
    return NailVariantModel.fromJson(_unwrapMap(response.data));
  }

  Future<List<NailShapeModel>> getNailShapes() async {
    final response = await _apiClient.get<dynamic>('/NailShapes');
    return _unwrapList(response.data).map(NailShapeModel.fromJson).toList();
  }

  Future<List<NailSurfaceModel>> getNailSurfaces() async {
    final response = await _apiClient.get<dynamic>('/NailSurfaces');
    return _unwrapList(response.data).map(NailSurfaceModel.fromJson).toList();
  }

  Future<List<ComponentModel>> getComponents({
    int page = 1,
    int pageSize = 100,
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/Components',
      queryParameters: {
        'pageNumber': page,
        'pageSize': pageSize,
      },
    );
    return _unwrapList(response.data).map(ComponentModel.fromJson).toList();
  }

  Future<PaginatedResponse<CustomerNailModel>> getCustomerNails({
    required int page,
    int pageSize = 10,
    String? name,
    bool? isPublic,
    bool? isFavorite,
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/CustomerNails',
      queryParameters: {
        'pageNumber': page,
        'pageSize': pageSize,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (isPublic != null) 'isPublic': isPublic,
        if (isFavorite != null) 'isFavorite': isFavorite,
      },
    );
    return PaginatedResponse.fromJson(
      response.data,
          (json) => CustomerNailModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<CustomerNailModel> getCustomerNailById(int id) async {
    final response = await _apiClient.get<dynamic>('/CustomerNails/$id');
    return CustomerNailModel.fromJson(_unwrapMap(response.data));
  }

  Future<int> createCustomerNail({
    required String name,
    bool isFavorite = false,
    bool isPublic = false,
    String? imagePath,
  }) async {
    final formData = FormData.fromMap({
      'Name': name,
      'IsFavorite': isFavorite.toString(),
      'IsPublic': isPublic.toString()
    });
    if (imagePath != null && imagePath.isNotEmpty) {
      formData.files.add(MapEntry('image', await MultipartFile.fromFile(imagePath)));
    }

    final response = await _apiClient.post<dynamic>(
      '/CustomerNails',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = _unwrapMap(response.data);
    return _asInt(data['customerNailId'] ?? data['CustomerNailId']);
  }

  Future<CustomerNailModel> updateCustomerNail({
    required int customerNailId,
    required String name,
    int? nailShapeId,
    int? nailSurfaceId,
    String? customColor,
    int? duration,
    bool isFavorite = false,
    bool isPublic = false,
    int? basedOnNailVariantId,
    String? imagePath,
  }) async {
    final formData = FormData.fromMap({
      'Name': name,
      'IsFavorite': isFavorite.toString(),
      'IsPublic': isPublic.toString(),
      if (nailShapeId != null) 'NailShapeId': nailShapeId.toString(),
      if (nailSurfaceId != null) 'NailSurfaceId': nailSurfaceId.toString(),
      if (customColor != null) 'CustomColor': customColor,
      if (duration != null) 'Duration': duration.toString(),
      if (basedOnNailVariantId != null) 'BasedOnNailVariantId': basedOnNailVariantId.toString(),
    });

    if (imagePath != null && imagePath.isNotEmpty) {
      formData.files.add(MapEntry('image', await MultipartFile.fromFile(imagePath)));
    }

    final response = await _apiClient.put<dynamic>(
      '/CustomerNails/$customerNailId',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    return CustomerNailModel.fromJson(_unwrapMap(response.data));
  }

  Future<void> deleteCustomerNail(int id) async {
    await _apiClient.delete<dynamic>('/CustomerNails/$id');
  }

  Future<PaginatedResponse<CustomerNailComponentModel>> getCustomerNailComponents({
    required int page,
    int pageSize = 50,
    int? customerNailId,
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/CustomerNailComponents',
      queryParameters: {
        'pageNumber': page,
        'pageSize': pageSize,
        if (customerNailId != null) 'customerNailId': customerNailId,
      },
    );
    return PaginatedResponse.fromJson(
      response.data,
          (json) => CustomerNailComponentModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> createCustomerNailComponent({
    required int customerNailId,
    int? componentId,
    int? customerComponentId,
    required double posX,
    required double posY,
    required int fingerIndex,
    required String configJson,
  }) async {
    await _apiClient.post<dynamic>(
      '/CustomerNailComponents',
      data: {
        'CustomerNailId': customerNailId,
        if (componentId != null) 'ComponentId': componentId,
        if (customerComponentId != null) 'CustomerComponentId': customerComponentId,
        'PosX': posX,
        'PosY': posY,
        'FingerIndex': fingerIndex,
        'ConfigJson': configJson,
      },
    );
  }

  Future<void> updateCustomerNailComponent({
    required int customerNailComponentId,
    required int customerNailId,
    int? componentId,
    int? customerComponentId,
    required double posX,
    required double posY,
    required int fingerIndex,
    required String configJson,
  }) async {
    await _apiClient.put<dynamic>(
      '/CustomerNailComponents/$customerNailComponentId',
      data: {
        'CustomerNailId': customerNailId,
        if (componentId != null) 'ComponentId': componentId,
        if (customerComponentId != null) 'CustomerComponentId': customerComponentId,
        'PosX': posX,
        'PosY': posY,
        'FingerIndex': fingerIndex,
        'ConfigJson': configJson,
      },
    );
  }

  Future<void> deleteCustomerNailComponent(int id) async {
    await _apiClient.delete<dynamic>('/CustomerNailComponents/$id');
  }

  Future<PaginatedResponse<CustomerComponentModel>> getCustomerComponents({
    required int page,
    int pageSize = 10,
    String? name,
    int? componentType,
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/CustomerComponents',
      queryParameters: {
        'pageNumber': page,
        'pageSize': pageSize,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (componentType != null) 'componentType': componentType,
      },
    );
    return PaginatedResponse.fromJson(
      response.data,
          (json) => CustomerComponentModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> createCustomerComponent({
    required String name,
    required int componentType,
    double? price,
    String? customDataJson,
    bool isPublic = false,
    String? imagePath,
  }) async {
    final formData = FormData.fromMap({
      'Name': name,
      'ComponentType': componentType,
      'IsPublic': isPublic.toString(),
      if (price != null) 'Price': price,
      if (customDataJson != null) 'CustomDataJson': customDataJson,
    });
    if (imagePath != null && imagePath.isNotEmpty) {
      formData.files.add(MapEntry('image', await MultipartFile.fromFile(imagePath)));
    }
    await _apiClient.post<dynamic>(
      '/CustomerComponents',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<void> updateCustomerComponent({
    required int customerComponentId,
    required String name,
    required int componentType,
    double? price,
    String customDataJson = '',
    bool isPublic = false,
    String? imagePath,
  }) async {
    final formData = FormData.fromMap({
      'Name': name,
      'ComponentType': componentType,
      'CustomDataJson': customDataJson,
      'IsPublic': isPublic.toString(),
      if (price != null) 'Price': price,
    });
    if (imagePath != null && imagePath.isNotEmpty) {
      formData.files.add(MapEntry('image', await MultipartFile.fromFile(imagePath)));
    }
    await _apiClient.put<dynamic>(
      '/CustomerComponents/$customerComponentId',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<void> deleteCustomerComponent(int id) async {
    await _apiClient.delete<dynamic>('/CustomerComponents/$id');
  }

  Map<String, dynamic> _unwrapMap(dynamic json) {
    if (json is Map<String, dynamic>) {
      final data = json['data'] ?? json['Data'];
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return json;
    }
    if (json is Map) return Map<String, dynamic>.from(json);
    return <String, dynamic>{};
  }

  List<Map<String, dynamic>> _unwrapList(dynamic json) {
    if (json is Map) {
      final data = json['data'] ?? json['Data'] ?? json['items'] ?? json['Items'];
      if (data != null && data != json) return _unwrapList(data);
    }
    if (json is List) {
      return json.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return const [];
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}