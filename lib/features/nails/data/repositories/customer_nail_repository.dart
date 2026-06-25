import 'package:dio/dio.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_response_parser.dart';
import '../../../../core/utils/paginated_response.dart';
import '../models/customer_nail_models.dart';

class CustomerNailRepository {
  final ApiClient _apiClient;

  CustomerNailRepository(this._apiClient);

  Future<PaginatedResponse<CustomerNailModel>> getCustomerNails({
    required int page,
    int pageSize = 10,
    String? name,
    bool? isPublic,
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/CustomerNails',
      queryParameters: {
        'pageNumber': page,
        'pageSize': pageSize,
        if (name != null && name.trim().isNotEmpty) 'name': name.trim(),
        if (isPublic != null) 'isPublic': isPublic,
      },
    );
    return PaginatedResponse.fromJson(
      response.data,
          (json) => CustomerNailModel.fromJson(json as Map<String, dynamic>),
    );
  }

  Future<CustomerNailModel> getCustomerNailById(int id) async {
    final response = await _apiClient.get<dynamic>('/CustomerNails/$id');
    final data = ApiResponseParser.unwrapMap(response.data);
    return CustomerNailModel.fromJson(data);
  }

  Future<int> createCustomerNail({
    required String name,
    bool isPublic = false,
    String? imagePath,
  }) async {
    final formData = FormData.fromMap({
      'Name': name,
      'IsPublic': isPublic.toString()
    });
    if (imagePath != null && imagePath.isNotEmpty) {
      formData.files.add(MapEntry('image', await MultipartFile.fromFile(imagePath)));
    }

    final response = await _apiClient.post<dynamic>(
      '/CustomerNails',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = ApiResponseParser.unwrapMap(response.data);
    return ApiResponseParser.asInt(data['customerNailId'] ?? data['CustomerNailId']);
  }

  Future<CustomerNailModel> updateCustomerNail({
    required int customerNailId,
    required String name,
    int? nailShapeId,
    int? nailSurfaceId,
    String? customColor,
    int? duration,
    bool isPublic = false,
    String? imagePath,
  }) async {
    final formData = FormData.fromMap({
      'Name': name,
      'IsPublic': isPublic.toString(),
      if (nailShapeId != null) 'NailShapeId': nailShapeId.toString(),
      if (nailSurfaceId != null) 'NailSurfaceId': nailSurfaceId.toString(),
      if (customColor != null) 'CustomColor': customColor,
      if (duration != null) 'Duration': duration.toString(),
    });

    if (imagePath != null && imagePath.isNotEmpty) {
      formData.files.add(MapEntry('image', await MultipartFile.fromFile(imagePath)));
    }

    final response = await _apiClient.put<dynamic>(
      '/CustomerNails/$customerNailId',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
    );
    final data = ApiResponseParser.unwrapMap(response.data);
    return CustomerNailModel.fromJson(data);
  }

  Future<void> deleteCustomerNail(int id) async {
    await _apiClient.delete<dynamic>('/CustomerNails/$id');
  }
}