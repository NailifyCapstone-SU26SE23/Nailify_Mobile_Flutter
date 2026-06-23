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
          'customerNailId': null, // FIX: Thêm null tường minh
          'quantity': 1,
        },
      ...serviceIds.map(
            (serviceId) => {
          'nailVariantId': null, // FIX: Đổi 0 thành null
          'serviceId': serviceId,
          'customerNailId': null, // FIX: Đổi 0 thành null
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
      'holdToken': '',
      'bookingItems': _buildBookingItems(nailVariantId, serviceIds),
    });
    return response.data ?? {};
  }

  // =================================================================
  // CÁC HÀM BỔ SUNG CHO LUỒNG ĐẶT DỊCH VỤ ĐỘC LẬP
  // =================================================================
  Future<List<dynamic>> getNailArtistsBySalon(String salonId) async {
    final response = await _apiClient.get('/NailArtists', queryParameters: {
      'PageNumber': 1,
      'PageSize': 50,
      'salonId': salonId,
    });
    final items = response.data['data']['items'] as List<dynamic>? ?? [];
    return items.map((artist) {
      final firstName = artist['firstName']?.toString() ?? '';
      final lastName = artist['lastName']?.toString() ?? '';
      return {
        ...artist,
        'fullName': '$firstName $lastName'.trim(),
      };
    }).toList();
  }

  Future<Map<String, dynamic>> createServiceBooking(Map<String, dynamic> bookingData) async {
    final response = await _apiClient.post('/Bookings', data: bookingData);
    return response.data ?? {};
  }

  // =================================================================
  // CÁC HÀM BỔ SUNG CHO LUỒNG CUSTOM NAIL BOOKING
  // =================================================================
  Future<Map<String, dynamic>> createCustomNailBooking(
      String salonId,
      String bookingDate,
      String startTime,
      String artistId,
      int customerNailId,
      Map<String, int> groupedExtraServices,
      ) async {
    // 1. Tạo item chính là Móng Custom
    List<Map<String, dynamic>> bookingItems = [
      {
        "nailVariantId": null, // FIX: Đổi 0 thành null
        "serviceId": null,
        "customerNailId": customerNailId,
        "quantity": 1
      }
    ];

    // 2. Thêm các dịch vụ phụ trợ (kèm số lượng x2, x3 nếu có)
    groupedExtraServices.forEach((serviceId, quantity) {
      bookingItems.add({
        "nailVariantId": null, // FIX: Đổi 0 thành null
        "serviceId": serviceId,
        "customerNailId": null, // FIX: Đổi 0 thành null
        "quantity": quantity
      });
    });

    // 3. Gửi payload lên API
    final response = await _apiClient.post('/Bookings', data: {
      "salonId": salonId,
      "bookingDate": bookingDate,
      "startTime": startTime,
      "nailArtistId": artistId,
      "holdToken": "",
      "bookingItems": bookingItems
    });

    return response.data ?? {};
  }
}
