import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class BookingApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  Future<List<dynamic>> getSalons() async {
    final response = await _apiClient.get('/Salons', queryParameters: {
      'PageIndex': 1,
      'PageSize': 10,
    });
    return response.data['data']['items'] ?? [];
  }

  Future<List<dynamic>> getServices() async {
    final response = await _apiClient.get('/Services', queryParameters: {
      'PageIndex': 1,
      'PageSize': 100,
    });
    return response.data['data']['items'] ?? response.data['data'] ?? [];
  }

  List<Map<String, dynamic>> _buildBookingItems(
    int nailVariantId,
    List<String> serviceIds,
  ) {
    return [
      if (nailVariantId > 0)
        {
          'nailVariantId': nailVariantId,
          'serviceId': null,
          'quantity': 1,
        },
      ...serviceIds.map(
        (serviceId) => {
          'nailVariantId': null,
          'serviceId': serviceId,
          'quantity': 1,
        },
      ),
    ];
  }

  Future<List<dynamic>> getSuggestedArtists(
    String salonId,
    String bookingDate,
    int nailVariantId,
    List<String> serviceIds,
  ) async {
    final response = await _apiClient.post('/Bookings/suggested-artists', data: {
      'salonId': salonId,
      'bookingDate': bookingDate,
      'bookingItems': _buildBookingItems(nailVariantId, serviceIds),
    });
    return response.data['data'] ?? [];
  }

  Future<List<dynamic>> getArtistAvailableSlots(
    String artistId,
    String bookingDate,
  ) async {
    final response = await _apiClient.get(
      '/Bookings/artist-available-slots',
      queryParameters: {
        'NailArtistId': artistId,
        'BookingDate': bookingDate,
      },
    );
    return response.data['data']['timeSlots'] ?? [];
  }

  Future<Map<String, dynamic>> createBooking(
    String salonId,
    String bookingDate,
    String startTime,
    String artistId,
    int nailVariantId,
    List<String> serviceIds,
  ) async {
    final response = await _apiClient.post('/Bookings', data: {
      'salonId': salonId,
      'bookingDate': bookingDate,
      'startTime': startTime,
      'nailArtistId': artistId,
      'bookingItems': _buildBookingItems(nailVariantId, serviceIds),
    });
    return Map<String, dynamic>.from(response.data['data'] ?? {});
  }

  // đặt dịch vụ
  Future<List<dynamic>> getNailArtistsBySalon(String salonId) async {
    final response = await _apiClient.get('/NailArtists', queryParameters: {
      'PageNumber': 1,
      'PageSize': 20,
      'salonId': salonId,
    });

    final items = response.data['data']['items'] as List<dynamic>? ?? [];

    //  bổ sung thêm từ firstname + lastname -> fullName để chạy được với BookingStylistSelection Widget
    return items.map((artist) {
      final firstName = artist['firstName']?.toString() ?? '';
      final lastName = artist['lastName']?.toString() ?? '';
      return {
        ...artist,
        'fullName': '$firstName $lastName'.trim(), // Map lại thành fullName
      };
    }).toList();
  }
  Future<Map<String, dynamic>> createServiceBooking(Map<String, dynamic> bookingData) async {
    final response = await _apiClient.post('/Bookings', data: bookingData);
    return response.data ?? {};
  }
}
