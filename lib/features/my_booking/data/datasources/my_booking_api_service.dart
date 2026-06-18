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

  Future<bool> cancelBooking(String bookingId) async {
    final response = await _apiClient.put('/Bookings/$bookingId/cancel');
    return response.statusCode == 200 || response.statusCode == 204;
  }

}