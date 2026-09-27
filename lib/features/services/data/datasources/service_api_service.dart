import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class ServiceApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  /// Lấy danh sách dịch vụ từ BE API (/Services?pageNumber=1&pageSize=10&status=Active)
  Future<List<dynamic>> getServices({
    int pageNumber = 1,
    int pageSize = 10,
    String status = 'Active',
  }) async {
    final response = await _apiClient.get(
      '/Services',
      queryParameters: {
        'pageNumber': pageNumber,
        'pageSize': pageSize,
        'status': status,
      },
    );
    final data = response.data['data'];
    if (data is Map<String, dynamic>) {
      return (data['items'] as List<dynamic>?) ?? [];
    } else if (data is List<dynamic>) {
      return data;
    }
    return [];
  }

  /// Lấy chi tiết dịch vụ theo ID từ BE API (/Services/$id)
  Future<Map<String, dynamic>> getServiceDetail(String id) async {
    final response = await _apiClient.get('/Services/$id');
    final data = response.data['data'] ?? response.data;
    if (data is Map<String, dynamic>) {
      return data;
    }
    return {};
  }
}
