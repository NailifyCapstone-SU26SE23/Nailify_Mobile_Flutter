import 'package:dio/dio.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class BookingApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  // 1. Lấy danh sách chi nhánh (Salon)
  Future<List<dynamic>> getSalons() async {
    final response = await _apiClient.get('/Salons', queryParameters: {
      'PageIndex': 1,
      'PageSize': 10,
    });
    return response.data['data']['items'] ?? [];
  }

  // 2. Lấy danh sách thợ đề xuất
  Future<List<dynamic>> getSuggestedArtists(String salonId, String bookingDate, int nailVariantId) async {
    final response = await _apiClient.post('/Bookings/suggested-artists', data: {
      "salonId": salonId,
      "bookingDate": bookingDate,
      "bookingItems": [
        {
          "nailVariantId": nailVariantId,
          "serviceId": null,
          "quantity": 1
        }
      ]
    });
    return response.data['data'] ?? [];
  }

  // 3. Lấy khung giờ rảnh của thợ
  Future<List<dynamic>> getArtistAvailableSlots(String artistId, String bookingDate) async {
    final response = await _apiClient.get('/Bookings/artist-available-slots', queryParameters: {
      'NailArtistId': artistId,
      'BookingDate': bookingDate,
    });
    return response.data['data']['timeSlots'] ?? [];
  }

  // 4. Tạo Booking
  Future<void> createBooking(String salonId, String bookingDate, String startTime, String artistId, int nailVariantId) async {
    await _apiClient.post('/Bookings', data: {
      "salonId": salonId,
      "bookingDate": bookingDate,
      "startTime": startTime,
      "nailArtistId": artistId,
      "bookingItems": [
        {
          "nailVariantId": nailVariantId,
          "serviceId": null,
          "quantity": 1
        }
      ]
    });
  }
}