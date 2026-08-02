import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class BookingApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  Future<List<dynamic>> getSalons() async {
    final response = await _apiClient.get(
      '/Salons',
      queryParameters: {'PageIndex': 1, 'PageSize': 10},
    );
    return response.data['data']['items'] ?? [];
  }

  Future<List<dynamic>> getServices() async {
    final response = await _apiClient.get(
      '/Services',
      queryParameters: {'PageIndex': 1, 'PageSize': 100},
    );
    return response.data['data']['items'] ?? response.data['data'] ?? [];
  }

  List<Map<String, dynamic>> _buildBookingItems(
    int nailVariantId,
    List<String> serviceIds,
    int? shapeMethodConfigId,
  ) {
    return [
      if (nailVariantId > 0)
        {
          'nailVariantId': nailVariantId,
          'shapeMethodConfigId': ?shapeMethodConfigId,
          'quantity': 1,
        },
      ...serviceIds.map((serviceId) => {'serviceId': serviceId, 'quantity': 1}),
    ];
  }

  Future<List<dynamic>> getSuggestedArtists(
    String salonId,
    String bookingDate,
    int nailVariantId,
    List<String> serviceIds,
    int? shapeMethodConfigId,
  ) async {
    final response = await _apiClient.post(
      '/Bookings/suggested-artists',
      data: {
        'salonId': salonId,
        'bookingDate': bookingDate,
        'bookingItems': _buildBookingItems(
          nailVariantId,
          serviceIds,
          shapeMethodConfigId,
        ),
      },
    );
    return response.data['data'] ?? [];
  }

  Future<List<dynamic>> getArtistAvailableSlots(
    String artistId,
    String bookingDate,
  ) async {
    final response = await _apiClient.get(
      '/Bookings/artist-available-slots',
      queryParameters: {'NailArtistId': artistId, 'BookingDate': bookingDate},
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
    final int dayOfWeek =
        date.weekday % 7; // Dart: Mon=1..Sun=7 → 0=Sun,1=Mon,...6=Sat
    final Map<String, dynamic>? todayHours = hours
        .cast<Map<String, dynamic>?>()
        .firstWhere((h) => h?['dayOfWeek'] == dayOfWeek, orElse: () => null);
    if (todayHours == null || todayHours['isClosed'] == true) return [];

    final String openStr = todayHours['openTime'] ?? '08:00:00';
    final String closeStr = todayHours['closeTime'] ?? '19:00:00';

    int toMinutes(String t) {
      final parts = t.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    String fromMinutes(int m) {
      final h = (m ~/ 60).toString().padLeft(2, '0');
      final min = (m % 60).toString().padLeft(2, '0');
      return '$h:$min:00';
    }

    final int openMin = toMinutes(openStr);
    final int closeMin = toMinutes(closeStr);
    final List<Map<String, dynamic>> slots = [];
    for (int m = openMin; m + 30 <= closeMin; m += 30) {
      slots.add({
        'startTime': fromMinutes(m),
        'endTime': fromMinutes(m + 30),
        'isAvailable': true,
        'isHeld': false,
      });
    }
    return slots;
  }

  // =================================================================
  // HOLD SLOT APIs
  // =================================================================

  /// Giữ chỗ slot 5 phút để tránh race condition.
  /// Dùng [expiresAt] (UTC) để tính toán thời gian còn lại chính xác,
  /// tránh sai lệch đồng hồ giữa app và server.
  Future<Map<String, dynamic>> holdSlot({
    required String salonId,
    required String nailArtistId,
    required String bookingDate,
    required String startTime,
    required List<Map<String, dynamic>> bookingItems,
  }) async {
    final response = await _apiClient.post(
      '/Bookings/hold-slot',
      data: {
        'salonId': salonId,
        'nailArtistId': nailArtistId,
        'bookingDate': bookingDate,
        'startTime': startTime,
        'bookingItems': bookingItems,
      },
    );
    return response.data['data'] ?? {};
  }

  /// Huỷ giữ chỗ thủ công (khi user đổi ý hoặc thoát màn hình đặt lịch).
  Future<void> cancelHoldSlot(String holdToken) async {
    try {
      await _apiClient.delete('/Bookings/hold-slot/$holdToken');
    } catch (_) {
      // Fire-and-forget: không throw để không ảnh hưởng UX
    }
  }

  /// Kiểm tra trạng thái giữ chỗ (còn hiệu lực không, còn bao nhiêu giây).
  Future<Map<String, dynamic>> checkHoldStatus(String holdToken) async {
    final response = await _apiClient.get(
      '/Bookings/hold-slot/$holdToken/status',
    );
    return response.data['data'] ?? {};
  }

  // =================================================================

  Future<Map<String, dynamic>> createBooking(
    String salonId,
    String bookingDate,
    String startTime,
    String? artistId,
    int nailVariantId,
    List<String> serviceIds, {
    List<int>? selectedPromotionIds,
    String? holdToken,
    int? shapeMethodConfigId,
    String? warrantyForBookingId,
    List<Map<String, dynamic>>? warrantyBookingItems,
  }) async {
    final response = await _apiClient.post(
      '/Bookings',
      data: {
        'salonId': salonId,
        'bookingDate': bookingDate,
        'startTime': startTime,
        'nailArtistId': artistId?.isEmpty == true ? null : artistId,
        'holdToken': holdToken,
        'bookingItems':
            warrantyBookingItems ??
            _buildBookingItems(nailVariantId, serviceIds, shapeMethodConfigId),
        'selectedPromotionIds': selectedPromotionIds,
        'warrantyForBookingId': ?warrantyForBookingId,
      },
    );
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
    int? shapeMethodConfigId,
  }) async {
    final response = await _apiClient.post(
      '/Bookings/price',
      data: {
        'salonId': salonId,
        'bookingDate': bookingDate,
        'startTime': startTime,
        'nailArtistId': artistId?.isEmpty == true ? null : artistId,
        'holdToken': null,
        'bookingItems': _buildBookingItems(
          nailVariantId,
          serviceIds,
          shapeMethodConfigId,
        ),
        'selectedPromotionIds': selectedPromotionIds,
      },
    );
    return Map<String, dynamic>.from(
      response.data['data'] ?? response.data ?? {},
    );
  }

  // =================================================================
  // CÁC HÀM BỔ SUNG CHO LUỒNG ĐẶT DỊCH VỤ ĐỘC LẬP
  // =================================================================
  Future<List<dynamic>> getNailArtistsBySalon(String salonId) async {
    final response = await _apiClient.get(
      '/NailArtists',
      queryParameters: {'PageNumber': 1, 'PageSize': 50, 'salonId': salonId},
    );
    final items = response.data['data']['items'] as List<dynamic>? ?? [];
    return items.map((artist) {
      final firstName = artist['firstName']?.toString() ?? '';
      final lastName = artist['lastName']?.toString() ?? '';
      return {...artist, 'fullName': '$firstName $lastName'.trim()};
    }).toList();
  }

  Future<Map<String, dynamic>> createServiceBooking(
    Map<String, dynamic> bookingData, {
    List<int>? selectedPromotionIds,
    String? holdToken,
  }) async {
    final payload = {
      ...bookingData,
      'holdToken': holdToken,
      if (selectedPromotionIds != null && selectedPromotionIds.isNotEmpty)
        'selectedPromotionIds': selectedPromotionIds,
    };
    final response = await _apiClient.post('/Bookings', data: payload);
    return response.data['data'] ?? {};
  }

  Future<Map<String, dynamic>> createCustomNailBooking(
    String salonId,
    String bookingDate,
    String startTime,
    String? artistId,
    String customerNailRequestId,
    Map<String, int> groupedExtraServices, {
    int? shapeMethodConfigId,
    List<int>? selectedPromotionIds,
    String? holdToken,
  }) async {
    final bookingItems = <Map<String, dynamic>>[
      {
        'customerNailRequestId': customerNailRequestId,
        'shapeMethodConfigId': ?shapeMethodConfigId,
        'quantity': 1,
      },
    ];

    groupedExtraServices.forEach((serviceId, quantity) {
      bookingItems.add({'serviceId': serviceId, 'quantity': quantity});
    });

    final response = await _apiClient.post(
      '/Bookings',
      data: {
        'salonId': salonId,
        'bookingDate': bookingDate,
        'startTime': startTime,
        if (artistId != null && artistId.isNotEmpty) 'nailArtistId': artistId,
        if (holdToken != null && holdToken.isNotEmpty) 'holdToken': holdToken,
        'bookingItems': bookingItems,
        if (selectedPromotionIds != null && selectedPromotionIds.isNotEmpty)
          'selectedPromotionIds': selectedPromotionIds,
      },
    );

    return response.data['data'] ?? {};
  }
}
