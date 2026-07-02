import '../../../../core/network/api_client.dart';
import '../../../../core/utils/paginated_response.dart';
import '../models/customer_nail_models.dart';

class NailComponentRepository {
  final ApiClient _apiClient;

  NailComponentRepository(this._apiClient);

  Future<PaginatedResponse<CustomerNailComponentModel>>
  getCustomerNailComponents({
    required int page,
    int pageSize = 50,
    int? customerNailId,
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/CustomerNailComponents',
      queryParameters: {
        'pageNumber': page,
        'pageSize': pageSize,
        'customerNailId': ?customerNailId,
      },
    );
    return PaginatedResponse.fromJson(
      response.data,
      (json) =>
          CustomerNailComponentModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> createCustomerNailComponent({
    required int customerNailId,
    int? componentId,
    int? customerComponentId,
    required double posX,
    required double posY,
    required int fingerIndex,
    required String configJson,
  }) async {
    await _apiClient.post<dynamic>(
      '/CustomerNailComponents',
      data: {
        'CustomerNailId': customerNailId,
        'ComponentId': ?componentId,
        'CustomerComponentId': ?customerComponentId,
        'PosX': posX,
        'PosY': posY,
        'FingerIndex': fingerIndex,
        'ConfigJson': configJson,
      },
    );
  }

  Future<void> updateCustomerNailComponent({
    required int customerNailComponentId,
    required int customerNailId,
    int? componentId,
    int? customerComponentId,
    required double posX,
    required double posY,
    required int fingerIndex,
    required String configJson,
  }) async {
    await _apiClient.put<dynamic>(
      '/CustomerNailComponents/$customerNailComponentId',
      data: {
        'CustomerNailId': customerNailId,
        'ComponentId': ?componentId,
        'CustomerComponentId': ?customerComponentId,
        'PosX': posX,
        'PosY': posY,
        'FingerIndex': fingerIndex,
        'ConfigJson': configJson,
      },
    );
  }

  Future<void> deleteCustomerNailComponent(int id) async {
    await _apiClient.delete<dynamic>('/CustomerNailComponents/$id');
  }
}
