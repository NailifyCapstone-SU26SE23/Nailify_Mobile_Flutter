import 'package:dio/dio.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class MyBookingApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  Future<List<dynamic>> getMyBookings() async {
    final response = await _apiClient.get('/Bookings/my-bookings');
    final responseData = response.data['data'];

    // API trả về đúng chuẩn Danh sách (List)
    if (responseData is List) {
      return responseData;
    }

    //API bọc dữ liệu trong một Đối tượng (Map)
    if (responseData is Map) {
      // Dò tìm danh sách bên trong Map (Thường gặp ở API phân trang)
      if (responseData.containsKey('items') && responseData['items'] is List) {
        return responseData['items'];
      }
      if (responseData.containsKey('data') && responseData['data'] is List) {
        return responseData['data'];
      }

      // Trường hợp API trả về đúng 1 lịch hẹn duy nhất dưới dạng Đối tượng
      return [responseData];
    }

    return [];
  }

  Future<Map<String, dynamic>> getBookingDetails(String bookingId) async {
    final response = await _apiClient.get('/Bookings/$bookingId');
    return response.data['data'] ?? {};
  }

  Future<bool> cancelBooking(String bookingId, {required String reason}) async {
    final response = await _apiClient.post(
      '/Bookings/$bookingId/cancel',
      data: {
        "reason": reason,
      },
    );
    return response.statusCode == 200 || response.statusCode == 204;
  }

  Future<Map<String, dynamic>?> getRatingByBooking(String bookingId) async {
    final response = await _apiClient.get(
      '/BookingRatings/by-booking/$bookingId',
    );
    final data = response.data['data'];
    return data is Map<String, dynamic> ? data : null;
  }

  Future<Map<String, dynamic>> createBookingRating({
    required String bookingId,
    required int overallScore,
    required String comment,
    required int serviceQuality,
    required int punctuality,
    required int cleanliness,
    String? imagePath,
  }) async {
    final formData = FormData.fromMap({
      'BookingId': bookingId,
      'OverallScore': overallScore,
      'Comment': comment,
      'ServiceQuality': serviceQuality,
      'Punctuality': punctuality,
      'Cleanliness': cleanliness,
      if (imagePath != null && imagePath.isNotEmpty)
        'image': await MultipartFile.fromFile(imagePath),
    });

    final response = await _apiClient.post('/BookingRatings', data: formData);
    final data = response.data['data'];
    return data is Map<String, dynamic> ? data : {};
  }
}
