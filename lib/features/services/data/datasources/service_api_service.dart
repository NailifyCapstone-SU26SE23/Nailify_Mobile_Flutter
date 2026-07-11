import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class ServiceApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  Future<List<dynamic>> getServices({
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    final response = await _apiClient.get(
      '/Services',
      queryParameters: {'PageNumber': pageNumber, 'PageSize': pageSize},
    );
    return response.data['data']['items'] ?? [];
  }

  Future<Map<String, dynamic>> getServiceDetail(String id) async {
    final response = await _apiClient.get('/Services/$id');
    return response.data['data'] ?? {};
  }
}
