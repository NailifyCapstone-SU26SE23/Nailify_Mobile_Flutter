import 'package:dio/dio.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../models/customer_nail_model.dart';

class StudioApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  /// Lấy danh sách yêu cầu duyệt mẫu nail
  /// GET /api/CustomerNailRequests
  Future<List<CustomerNailModel>> getMyNailRequests({
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/CustomerNailRequests/me',
      queryParameters: {'pageNumber': pageNumber, 'pageSize': pageSize},
    );

    final items = response.data['data']['items'] as List<dynamic>? ?? [];
    return items.map((json) => CustomerNailModel.fromJson(json)).toList();
  }

  /// Lấy chi tiết yêu cầu duyệt mẫu nail
  /// GET /api/CustomerNailRequests/{id}
  Future<CustomerNailModel> getNailRequestDetail(
    String customerNailRequestId,
  ) async {
    final response = await _apiClient.get(
      '/CustomerNailRequests/$customerNailRequestId',
    );
    return CustomerNailModel.fromJson(response.data['data']);
  }

  /// Lấy danh sách salons (dùng cho chọn salon gửi duyệt)
  Future<List<dynamic>> getSalons() async {
    final response = await _apiClient.get(
      '/Salons',
      queryParameters: {'PageIndex': 1, 'PageSize': 20, 'Status': 'Open'},
    );
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

  /// Phản hồi đồng ý hoặc từ chối báo giá mẫu nail custom
  /// POST /api/CustomerNails/requests/{id}/customer-respond-quote
  Future<Map<String, dynamic>> respondToQuote(
    String customerNailRequestId, {
    required bool isAccepted,
    String? rejectReason,
  }) async {
    try {
      final response = await _apiClient.post(
        '/CustomerNails/requests/$customerNailRequestId/customer-respond-quote',
        data: {
          'isAccepted': isAccepted,
          if (rejectReason != null && rejectReason.isNotEmpty)
            'rejectReason': rejectReason,
        },
      );
      final isSuccess =
          response.statusCode != null &&
          response.statusCode! >= 200 &&
          response.statusCode! < 300;
      final dataMap = response.data is Map ? response.data : {};
      final message =
          dataMap['message']?.toString() ??
          (isSuccess
              ? (isAccepted
                    ? 'Đồng ý báo giá thành công! Bạn có thể đặt lịch ngay.'
                    : 'Đã từ chối báo giá thành công.')
              : 'Không thể xử lý phản hồi.');

      return {'success': isSuccess, 'message': message};
    } on DioException catch (e) {
      final errorData = e.response?.data;
      String message = 'Đã có lỗi xảy ra khi gửi phản hồi.';
      if (errorData is Map) {
        message = errorData['message']?.toString() ?? message;
      }
      return {'success': false, 'message': message};
    } catch (e) {
      return {'success': false, 'message': e.toString()};
    }
  }
}
