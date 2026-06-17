import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_response_parser.dart';
import '../../../../core/utils/paginated_response.dart';
import '../models/category_type_model.dart';
import '../models/nail_design_model.dart';
import '../models/nail_filters.dart';

class NailDesignRepository {
  final ApiClient _apiClient;

  NailDesignRepository(this._apiClient);

  Future<PaginatedResponse<NailDesignModel>> getNailDesigns({
    required int page,
    int pageSize = 10,
    NailFilters filters = const NailFilters(),
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/NailDesigns',
      queryParameters: {
        'pageNumber': page,
        'pageSize': pageSize,
        if (filters.name != null && filters.name!.trim().isNotEmpty) 'name': filters.name!.trim(),
        if (filters.categoryIds.isNotEmpty) 'categoryIds': filters.categoryIds,
      },
    );
    return PaginatedResponse.fromJson(
      response.data,
          (json) => NailDesignModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<NailDesignModel> getNailDesignById(int id) async {
    final response = await _apiClient.get<dynamic>('/NailDesigns/$id');
    final data = ApiResponseParser.unwrapMap(response.data);
    return NailDesignModel.fromJson(data);
  }

  Future<List<CategoryTypeModel>> getCategoryTypes() async {
    final response = await _apiClient.get<dynamic>(
      '/CategoryTypes',
      queryParameters: {
        'pageNumber': 1,
        'pageSize': 100,
      },
    );
    final paginatedResponse = PaginatedResponse.fromJson(
      response.data,
          (json) => CategoryTypeModel.fromJson(json as Map<String, dynamic>),
    );
    return paginatedResponse.items;
  }
}