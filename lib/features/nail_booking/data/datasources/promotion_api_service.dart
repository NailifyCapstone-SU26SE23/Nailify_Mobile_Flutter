import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../models/promotion_model.dart';

class PromotionApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  Future<List<PromotionModel>> getVouchers({
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    final response = await _apiClient.get(
      '/Promotions/today',
      queryParameters: {'pageNumber': pageNumber, 'pageSize': pageSize},
    );

    final items = response.data['data']?['items'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map((json) => PromotionModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }
}
