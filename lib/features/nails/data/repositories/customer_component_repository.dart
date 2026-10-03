import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/paginated_response.dart';
import '../models/customer_nail_models.dart';

class CustomerComponentRepository {
  final ApiClient _apiClient;

  CustomerComponentRepository(this._apiClient);

  Future<PaginatedResponse<CustomerComponentModel>> getCustomerComponents({
    required int page,
    int pageSize = 10,
    String? name,
    int? componentType,
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/CustomerComponents',
      queryParameters: {
        'pageNumber': page,
        'pageSize': pageSize,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        'componentType': ?componentType,
      },
    );
    return PaginatedResponse.fromJson(
      response.data,
      (json) => CustomerComponentModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<void> createCustomerComponent({
    required String name,
    required int componentType,
    double? price,
    String? customDataJson,
    String? imagePath,
  }) async {
    final formData = FormData.fromMap({
      'name': name,
      'componentType': componentType,
      'price': ?price,
      if (customDataJson != null && customDataJson.trim().isNotEmpty)
        'customDataJson': customDataJson.trim(),
    });
    if (imagePath != null && imagePath.isNotEmpty) {
      formData.files.add(
        MapEntry('image', await MultipartFile.fromFile(imagePath)),
      );
    }
    await _apiClient.post<dynamic>(
      '/CustomerComponents',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<void> updateCustomerComponent({
    required int customerComponentId,
    required String name,
    required int componentType,
    double? price,
    String customDataJson = '',
    String? imagePath,
  }) async {
    final formData = FormData.fromMap({
      'name': name,
      'componentType': componentType,
      if (customDataJson.trim().isNotEmpty)
        'customDataJson': customDataJson.trim(),
      'price': ?price,
    });
    if (imagePath != null && imagePath.isNotEmpty) {
      formData.files.add(
        MapEntry('image', await MultipartFile.fromFile(imagePath)),
      );
    }
    await _apiClient.put<dynamic>(
      '/CustomerComponents/$customerComponentId',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
  }

  Future<void> deleteCustomerComponent(int id) async {
    await _apiClient.delete<dynamic>('/CustomerComponents/$id');
  }
}
