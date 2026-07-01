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
          'customerNailId': null,
          'quantity': 1,
        },
      ...serviceIds.map(
        (serviceId) => {
          'nailVariantId': null,
          'serviceId': serviceId,
          'customerNailId': null,
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

  /// Tạo danh sách khung giờ từ lịch hoạt động của salon (không cần chọn thợ).
  /// Trả về cùng định dạng với [getArtistAvailableSlots] để widget dùng chung.
  List<dynamic> getSalonOperatingSlots(
    Map<String, dynamic> salon,
    DateTime date,
  ) {
    final List<dynamic> hours = salon['operatingHours'] ?? [];
    final int dayOfWeek = date.weekday % 7; // Dart: Mon=1..Sun=7 → 0=Sun,1=Mon,...6=Sat
    final Map<String, dynamic>? todayHours = hours.cast<Map<String, dynamic>?>().firstWhere(
      (h) => h?['dayOfWeek'] == dayOfWeek,
      orElse: () => null,
    );
    if (todayHours == null || todayHours['isClosed'] == true) return [];

    final String openStr = todayHours['openTime'] ?? '08:00:00';
    final String closeStr = todayHours['closeTime'] ?? '19:00:00';

    int _toMinutes(String t) {
      final parts = t.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }
    String _fromMinutes(int m) {
      final h = (m ~/ 60).toString().padLeft(2, '0');
      final min = (m % 60).toString().padLeft(2, '0');
      return '$h:$min:00';
    }

    final int openMin = _toMinutes(openStr);
    final int closeMin = _toMinutes(closeStr);
    final List<Map<String, dynamic>> slots = [];
    for (int m = openMin; m + 30 <= closeMin; m += 30) {
      slots.add({
        'startTime': _fromMinutes(m),
        'endTime': _fromMinutes(m + 30),
        'isAvailable': true,
        'isHeld': false,
      });
    }
    return slots;
  }

  Future<Map<String, dynamic>> createBooking(
    String salonId,
    String bookingDate,
    String startTime,
    String? artistId,
    int nailVariantId,
    List<String> serviceIds, {
      List<int>? selectedPromotionIds,
    }) async {
    final response = await _apiClient.post('/Bookings', data: {
      'salonId': salonId,
      'bookingDate': bookingDate,
      'startTime': startTime,
      'nailArtistId': artistId?.isEmpty == true ? null : artistId,
      'holdToken': null,
      'bookingItems': _buildBookingItems(nailVariantId, serviceIds),
      'selectedPromotionIds': selectedPromotionIds,
    });
    return response.data['data'] ?? {};
  }

  Future<Map<String, dynamic>> reviewBookingPrice({
    required String salonId,
    required String bookingDate,
    required String startTime,
    required String? artistId,
    required int nailVariantId,
    required List<String> serviceIds,
    List<int>? selectedPromotionIds,
  }) async {
    final response = await _apiClient.post('/Bookings/price', data: {
      'salonId': salonId,
      'bookingDate': bookingDate,
      'startTime': startTime,
      'nailArtistId': artistId?.isEmpty == true ? null : artistId,
      'holdToken': null,
      'bookingItems': _buildBookingItems(nailVariantId, serviceIds),
      'selectedPromotionIds': selectedPromotionIds,
    });
    return response.data['data'] ?? {};
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

  Future<Map<String, dynamic>> createServiceBooking(
    Map<String, dynamic> bookingData,
  ) async {
    final response = await _apiClient.post('/Bookings', data: bookingData);
    return response.data['data'] ?? {};
  }

  Future<Map<String, dynamic>> createCustomNailBooking(
    String salonId,
    String bookingDate,
    String startTime,
    String artistId,
    int customerNailId,
    Map<String, int> groupedExtraServices,
  ) async {
    final bookingItems = <Map<String, dynamic>>[
      {
        'nailVariantId': null,
        'serviceId': null,
        'customerNailId': customerNailId,
        'quantity': 1,
      },
    ];

    groupedExtraServices.forEach((serviceId, quantity) {
      bookingItems.add({
        'nailVariantId': null,
        'serviceId': serviceId,
        'customerNailId': null,
        'quantity': quantity,
      });
    });

    final response = await _apiClient.post('/Bookings', data: {
      'salonId': salonId,
      'bookingDate': bookingDate,
      'startTime': startTime,
      'nailArtistId': artistId,
      'holdToken': '',
      'bookingItems': bookingItems,
    });

    return response.data['data'] ?? {};
  }
}
