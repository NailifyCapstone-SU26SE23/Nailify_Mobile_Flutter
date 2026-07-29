import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../models/promotion_model.dart';

class PromotionApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  /// Lấy danh sách khuyến mãi từ API /Promotions
  Future<List<PromotionModel>> getPromotions({
    int pageNumber = 1,
    int pageSize = 20,
    String? type,
    String? scope,
    String? discountType,
  }) async {
    final queryParams = <String, dynamic>{
      'pageNumber': pageNumber,
      'pageSize': pageSize,
    };
    if (type != null) queryParams['type'] = type;
    if (scope != null) queryParams['scope'] = scope;
    if (discountType != null) queryParams['discountType'] = discountType;

    final response = await _apiClient.get(
      '/Promotions',
      queryParameters: queryParams,
    );

    final items = response.data['data']?['items'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map((json) => PromotionModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  Future<List<PromotionModel>> getTodayPromotions({
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    final queryParams = <String, dynamic>{
      'pageNumber': pageNumber,
      'pageSize': pageSize,
    };
    final response = await _apiClient.get(
      '/Promotions/today',
      queryParameters: queryParams,
    );

    final items = response.data['data']?['items'] as List<dynamic>? ?? [];
    return items
        .whereType<Map>()
        .map((json) => PromotionModel.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  /// Giữ lại hàm cũ để tương thích ngược với các file đang dùng
  Future<List<PromotionModel>> getVouchers({
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    return getPromotions(pageNumber: pageNumber, pageSize: pageSize);
  }
}
