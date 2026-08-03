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
          if (shapeMethodConfigId != null)
            'shapeMethodConfigId': shapeMethodConfigId,
          'quantity': 1,
        },
      ...serviceIds.map(
        (serviceId) => {
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

  Future<List<dynamic>> getSalonAvailableSlots({
    required String salonId,
    required String bookingDate,
    required List<Map<String, dynamic>> bookingItems,
  }) async {
    final response = await _apiClient.post(
      '/Bookings/salon-available-slots',
      data: {
        'salonId': salonId,
        'bookingDate': bookingDate,
        'bookingItems': bookingItems,
      },
    );
    final List<dynamic> list = response.data['data']['timeSlots'] ?? response.data['data'] ?? [];
    return list.map((slot) {
      final map = Map<String, dynamic>.from(slot);
      final rawTime = map['startTime'] ?? map['time'] ?? '';
      // Chuẩn hóa thời gian sang định dạng HH:mm:ss nếu chỉ có HH:mm
      String formattedTime = rawTime.toString();
      if (formattedTime.isNotEmpty && formattedTime.split(':').length == 2) {
        formattedTime = '$formattedTime:00';
      }
      return {
        'startTime': formattedTime,
        'isAvailable': map['isAvailable'] == true,
        'isHeld': map['isHeld'] == true,
      };
    }).toList();
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

    // Lọc tất cả các khung giờ hoạt động cho thứ này mà không bị đóng cửa
    final List<Map<String, dynamic>> activeSegments = hours
        .whereType<Map>()
        .map((h) => Map<String, dynamic>.from(h))
        .where((h) => h['dayOfWeek'] == dayOfWeek && h['isClosed'] != true)
        .toList();

    if (activeSegments.isEmpty) return [];

    int toMinutes(String t) {
      final parts = t.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    String fromMinutes(int m) {
      final h = (m ~/ 60).toString().padLeft(2, '0');
      final min = (m % 60).toString().padLeft(2, '0');
      return '$h:$min:00';
    }

    final List<Map<String, dynamic>> slots = [];
    for (final segment in activeSegments) {
      final String openStr = segment['openTime'] ?? '08:00:00';
      final String closeStr = segment['closeTime'] ?? '19:00:00';
      final int openMin = toMinutes(openStr);
      final int closeMin = toMinutes(closeStr);

      for (int m = openMin; m <= closeMin; m += 30) {
        slots.add({
          'startTime': fromMinutes(m),
          'endTime': fromMinutes(m + 30),
          'isAvailable': true,
          'isHeld': false,
        });
      }
    }

    // Loại bỏ các slot trùng startTime và sắp xếp theo thứ tự thời gian tăng dần
    final Map<String, Map<String, dynamic>> uniqueSlots = {};
    for (final slot in slots) {
      uniqueSlots[slot['startTime']] = slot;
    }

    final List<Map<String, dynamic>> sortedSlots = uniqueSlots.values.toList()
      ..sort((a, b) => a['startTime'].compareTo(b['startTime']));

    return sortedSlots;
  }

  /// Lọc bất kỳ danh sách slot nào theo lịch hoạt động của salon.
  List<dynamic> filterSlotsByOperatingHours({
    required List<dynamic> slots,
    required Map<String, dynamic>? salon,
    required DateTime? date,
  }) {
    if (salon == null || date == null || slots.isEmpty) return slots;

    final List<dynamic>? hours = salon['operatingHours'];
    if (hours == null || hours.isEmpty) return slots;

    final int dayOfWeek =
        date.weekday % 7; // Dart: Mon=1..Sun=7 → 0=Sun,1=Mon,...6=Sat

    // Lọc tất cả các khung giờ hoạt động cho thứ này mà không bị đóng cửa
    final List<Map<String, dynamic>> activeSegments = hours
        .whereType<Map>()
        .map((h) => Map<String, dynamic>.from(h))
        .where((h) => h['dayOfWeek'] == dayOfWeek && h['isClosed'] != true)
        .toList();

    if (activeSegments.isEmpty) return [];

    int toMinutes(String t) {
      final parts = t.split(':');
      return int.parse(parts[0]) * 60 + int.parse(parts[1]);
    }

    return slots.where((slot) {
      final String? startTimeStr = slot['startTime'] as String?;
      final String? endTimeStr = slot['endTime'] as String?;
      if (startTimeStr == null) return false;

      final int slotStartMin = toMinutes(startTimeStr);
      final int slotEndMin = endTimeStr != null
          ? toMinutes(endTimeStr)
          : slotStartMin + 30;

      for (final segment in activeSegments) {
        final String openStr = segment['openTime'] ?? '08:00:00';
        final String closeStr = segment['closeTime'] ?? '19:00:00';
        final int openMin = toMinutes(openStr);
        final int closeMin = toMinutes(closeStr);

        if (slotStartMin >= openMin && slotStartMin <= closeMin) {
          return true;
        }
      }
      return false;
    }).toList();
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
        if (shapeMethodConfigId != null)
          'shapeMethodConfigId': shapeMethodConfigId,
        'quantity': 1,
      },
    ];

    groupedExtraServices.forEach((serviceId, quantity) {
      bookingItems.add({
        'serviceId': serviceId,
        'quantity': quantity,
      });
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
