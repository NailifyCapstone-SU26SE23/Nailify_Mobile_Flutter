import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_response_parser.dart';
import '../../../../core/utils/paginated_response.dart';
import '../models/nail_filters.dart';
import '../models/nail_shape_model.dart';
import '../models/nail_surface_model.dart';
import '../models/nail_variant_model.dart';
import '../models/shape_method_config_model.dart';

class NailVariantRepository {
  final ApiClient _apiClient;

  NailVariantRepository(this._apiClient);

  Future<PaginatedResponse<NailVariantModel>> getNailVariants({
    required int page,
    int pageSize = 10,
    NailFilters filters = const NailFilters(),
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/NailVariants',
      queryParameters: {
        'pageNumber': page,
        'pageSize': pageSize,
        if (filters.shapeId != null) 'nailShapeId': filters.shapeId,
        if (filters.surfaceId != null) 'nailSurfaceId': filters.surfaceId,
        if (filters.minPrice != null) 'minPrice': filters.minPrice,
        if (filters.maxPrice != null) 'maxPrice': filters.maxPrice,
      },
    );
    return PaginatedResponse.fromJson(
      response.data,
      (json) => NailVariantModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<NailVariantModel> getNailVariantById(int id) async {
    final response = await _apiClient.get<dynamic>('/NailVariants/$id');
    final data = ApiResponseParser.unwrapMap(response.data);
    return NailVariantModel.fromJson(data);
  }

  Future<List<NailShapeModel>> getNailShapes() async {
    final response = await _apiClient.get<dynamic>('/NailShapes');
    final list = ApiResponseParser.unwrapList(response.data);
    return list.map(NailShapeModel.fromJson).toList();
  }

  Future<List<NailSurfaceModel>> getNailSurfaces() async {
    final response = await _apiClient.get<dynamic>('/NailSurfaces');
    final list = ApiResponseParser.unwrapList(response.data);
    return list.map(NailSurfaceModel.fromJson).toList();
  }

  Future<List<ShapeMethodConfigModel>> getShapeMethodConfigsByNailShape(
    int nailShapeId,
  ) async {
    final response = await _apiClient.get<dynamic>(
      '/ShapeMethodConfigs/nail-shape/$nailShapeId',
    );
    final list = ApiResponseParser.unwrapList(response.data);
    return list.map(ShapeMethodConfigModel.fromJson).toList();
  }

  Future<ShapeMethodConfigModel> getShapeMethodConfigById(int id) async {
    final response = await _apiClient.get<dynamic>('/ShapeMethodConfigs/$id');
    final data = ApiResponseParser.unwrapMap(response.data);
    return ShapeMethodConfigModel.fromJson(data);
  }

  Future<Map<String, dynamic>> getRatingStatsForVariants(List<int> variantIds) async {
    if (variantIds.isEmpty) {
      return {'rating': 0.0, 'reviewsCount': 0};
    }

    try {
      final futures = variantIds.map((id) {
        return _apiClient.get<dynamic>('/BookingRatings/by-nail-variant/$id');
      }).toList();

      final responses = await Future.wait(futures);

      double totalScoreSum = 0;
      int totalRatingCount = 0;

      for (final response in responses) {
        final data = ApiResponseParser.unwrapMap(response.data);
        final items = data['items'] as List<dynamic>? ?? [];
        for (final item in items) {
          final score = ApiResponseParser.asInt(item['overallScore'] ?? item['OverallScore']);
          totalScoreSum += score;
          totalRatingCount++;
        }
      }

      final averageRating = totalRatingCount == 0 ? 0.0 : totalScoreSum / totalRatingCount;
      return {
        'rating': averageRating,
        'reviewsCount': totalRatingCount,
      };
    } catch (e) {
      return {'rating': 0.0, 'reviewsCount': 0};
    }
  }
}
