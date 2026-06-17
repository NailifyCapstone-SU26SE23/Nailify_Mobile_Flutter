import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class MyBookingApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  Future<List<dynamic>> getMyBookings() async {
    final response = await _apiClient.get('/Bookings/my-bookings');
    return response.data['data'] ?? [];
  }
  Future<Map<String, dynamic>> getBookingDetails(String bookingId) async {
    final response = await _apiClient.get('/Bookings/$bookingId');
    return response.data['data'] ?? {};
  }
}