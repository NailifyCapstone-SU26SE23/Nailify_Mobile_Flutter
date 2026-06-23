import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../models/customer_nail_model.dart';

class StudioApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  Future<List<CustomerNailModel>> getMyNails({int pageNumber = 1, int pageSize = 50}) async {
    final response = await _apiClient.get('/CustomerNails/me', queryParameters: {
      'PageNumber': pageNumber,
      'PageSize': pageSize,
    });

    final items = response.data['data']['items'] as List<dynamic>? ?? [];
    return items.map((json) => CustomerNailModel.fromJson(json)).toList();
  }

  Future<CustomerNailModel> getNailDetail(String id) async {
    final response = await _apiClient.get('/CustomerNails/$id');
    return CustomerNailModel.fromJson(response.data['data']);
  }
  Future<void> submitNailReview (String id) async {
    await _apiClient.post('/CustomerNails/$id/submit-review');
  }
  Future<List<dynamic>> getSalons() async {
    // Lưu ý: Thường endpoint liệt kê là GET. Nếu Backend bắt buộc là POST, bạn đổi .get thành .post nhé
    final response = await _apiClient.get('/Salons', queryParameters: {
      'PageIndex': 1,
      'PageSize': 20,
    });
    return response.data['data']['items'] ?? [];
  }

  // Future<void> submitForReview(String nailId, String salonId) async {
  //   await _apiClient.post('/CustomerNails/$nailId/submit-review', data: {
  //     'salonId': salonId, // Gửi ID salon được chọn vào Body
  //   });
  // }
  Future<Map<String, dynamic>> getArtistDetail(String artistId) async {
    final response = await _apiClient.get('/NailArtists/$artistId');
    return response.data['data'] ?? {};
  }
}