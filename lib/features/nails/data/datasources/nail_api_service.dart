import '../../../../core/network/api_client.dart';
import '../models/category_type_model.dart';
import '../models/nail_design_model.dart';
import '../models/nail_shape_model.dart';
import '../models/nail_surface_model.dart';
import '../models/nail_variant_model.dart';
import '../models/paginated_response.dart';

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
      NailDesignModel.fromJson,
      fallbackPage: page,
      fallbackPageSize: pageSize,
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
    return PaginatedResponse.fromJson(
      response.data,
      CategoryTypeModel.fromJson,
      fallbackPage: page,
      fallbackPageSize: pageSize,
    ).items;
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
      NailVariantModel.fromJson,
      fallbackPage: page,
      fallbackPageSize: pageSize,
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
    final data = json is Map ? (json['data'] ?? json['Data'] ?? json['items'] ?? json['Items']) : json;
    if (data is List) {
      return data.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return const [];
  }
}
