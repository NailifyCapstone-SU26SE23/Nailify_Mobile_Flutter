import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../models/customer_nail_model.dart';

class StudioApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  /// Lấy danh sách yêu cầu duyệt mẫu nail
  /// GET /api/CustomerNailRequests
  Future<List<CustomerNailModel>> getMyNailRequests({int pageNumber = 1, int pageSize = 20}) async {
    final response = await _apiClient.get('/CustomerNailRequests/me', queryParameters: {
      'pageNumber': pageNumber,
      'pageSize': pageSize,
    });

    final items = response.data['data']['items'] as List<dynamic>? ?? [];
    return items.map((json) => CustomerNailModel.fromJson(json)).toList();
  }

  /// Lấy chi tiết yêu cầu duyệt mẫu nail
  /// GET /api/CustomerNailRequests/{id}
  Future<CustomerNailModel> getNailRequestDetail(String customerNailRequestId) async {
    final response = await _apiClient.get('/CustomerNailRequests/$customerNailRequestId');
    return CustomerNailModel.fromJson(response.data['data']);
  }

  /// Lấy danh sách salons (dùng cho chọn salon gửi duyệt)
  Future<List<dynamic>> getSalons() async {
    final response = await _apiClient.get('/Salons', queryParameters: {
      'PageIndex': 1,
      'PageSize': 20,
    });
    return response.data['data']['items'] ?? [];
  }

  /// Gửi yêu cầu duyệt mẫu nail (submit-review)
  Future<void> submitNailReview(String nailId, String salonId) async {
    await _apiClient.post(
      '/CustomerNails/requests/submit',
      data: {
        'customerNailId': int.tryParse(nailId) ?? nailId,
        'salonId': salonId,
      },
    );
  }
}
