import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_response_parser.dart';
import '../../../../core/utils/paginated_response.dart';

class FavoriteNailRepository {
  final ApiClient _apiClient;

  FavoriteNailRepository(this._apiClient);

  Future<int?> favoriteDesign(int nailDesignId) async {
    final response = await _apiClient.post<dynamic>(
      '/FavoriteNails',
      data: {'nailDesignId': nailDesignId},
    );
    return _readFavoriteNailId(response.data);
  }

  Future<int?> favoriteVariant(int nailVariantId) async {
    final response = await _apiClient.post<dynamic>(
      '/FavoriteNails',
      data: {'nailVariantId': nailVariantId},
    );
    return _readFavoriteNailId(response.data);
  }

  Future<void> unfavorite(int favoriteNailId) async {
    await _apiClient.delete<dynamic>('/FavoriteNails/$favoriteNailId');
  }

  Future<PaginatedResponse<Map<String, dynamic>>> getFavoriteNails({
    required int page,
    int pageSize = 10,
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/FavoriteNails',
      queryParameters: {'pageNumber': page, 'pageSize': pageSize},
    );
    return PaginatedResponse.fromJson(
      response.data,
      (json) => Map<String, dynamic>.from(json as Map),
    );
  }

  int? _readFavoriteNailId(dynamic responseData) {
    final data = ApiResponseParser.unwrapMap(responseData);
    final value = data['favoriteNailId'] ?? data['FavoriteNailId'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}
