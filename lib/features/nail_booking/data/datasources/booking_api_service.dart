import '../../../../core/di/injection.dart';
import '../../../../core/error/exceptions.dart';
import '../../../../core/network/api_client.dart';

class BookingApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  double _parseAverageRating(dynamic data) {
    if (data == null) return 0.0;
    if (data is Map) {
      if (data['averageRating'] is num) {
        return (data['averageRating'] as num).toDouble();
      }
      if (data['averageScore'] is num) {
        return (data['averageScore'] as num).toDouble();
      }
      if (data['rating'] is num) {
        return (data['rating'] as num).toDouble();
      }
      final inner = data['data'];
      if (inner != null && inner != data) {
        return _parseAverageRating(inner);
      }
      final items = data['items'] as List<dynamic>? ?? [];
      if (items.isEmpty) return 0.0;
      double sum = 0;
      int count = 0;
      for (final item in items) {
        if (item is Map) {
          final score =
              item['overallScore'] ??
              item['OverallScore'] ??
              item['rating'] ??
              item['score'];
          if (score is num) {
            sum += score;
            count++;
          }
        }
      }
      return count > 0 ? sum / count : 0.0;
    } else if (data is List) {
      if (data.isEmpty) return 0.0;
      double sum = 0;
      int count = 0;
      for (final item in data) {
        if (item is Map) {
          final score =
              item['overallScore'] ??
              item['OverallScore'] ??
              item['rating'] ??
              item['score'];
          if (score is num) {
            sum += score;
            count++;
          }
        }
      }
      return count > 0 ? sum / count : 0.0;
    }
    return 0.0;
  }

  Future<double> getSalonRating(String salonId) async {
    if (salonId.isEmpty) return 0.0;
    try {
      final response = await _apiClient.get(
        '/BookingRatings/by-salon/$salonId',
      );
      return _parseAverageRating(response.data);
    } catch (_) {
      return 0.0;
    }
  }

  Future<double> getNailArtistRating(String artistId) async {
    if (artistId.isEmpty) return 0.0;
    try {
      final response = await _apiClient.get(
        '/BookingRatings/by-nail-artist/$artistId',
      );
      return _parseAverageRating(response.data);
    } catch (_) {
      return 0.0;
    }
  }

  /// Fetch the current customer's wallet summary (balance, frozenBalance, etc.)
  /// Endpoint: GET /api/Wallets/summary → CustomerWalletSummaryDto
  Future<Map<String, dynamic>?> getCustomerWalletSummary() async {
    try {
      final response = await _apiClient.get('/Wallets/summary');
      final data = response.data['data'];
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } catch (_) {
      return null;
    }
  }

  static bool _isSalonOpen(dynamic salon) {
    if (salon == null || salon is! Map) return false;

    // 1. Status string check
    final status =
        (salon['status'] ?? salon['salonStatus'] ?? salon['state'])
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
    if (status == 'closed' ||
        status == 'close' ||
        status == 'inactive' ||
        status == 'disabled' ||
        status == 'off' ||
        status == 'maintenance' ||
        status == 'đóng cửa' ||
        status == 'dong cua' ||
        status == 'ngừng hoạt động') {
      return false;
    }

    // 2. Explicit boolean flags
    final isClosedVal = salon['isClosed'];
    if (isClosedVal == true || isClosedVal == 1 || isClosedVal == 'true') {
      return false;
    }
    final isOpenVal = salon['isOpen'];
    if (isOpenVal == false || isOpenVal == 0 || isOpenVal == 'false') {
      return false;
    }
    final isOperatingVal = salon['isOperating'];
    if (isOperatingVal == false ||
        isOperatingVal == 0 ||
        isOperatingVal == 'false') {
      return false;
    }
    final isActiveVal = salon['isActive'];
    if (isActiveVal == false || isActiveVal == 0 || isActiveVal == 'false') {
      return false;
    }

    // 3. Operating hours check for current day
    final operatingHours = salon['operatingHours'];
    if (operatingHours is List && operatingHours.isNotEmpty) {
      final now = DateTime.now();
      final currentDayOfWeek = now.weekday % 7;

      final todayHours = operatingHours.whereType<Map>().where((h) {
        final day = h['dayOfWeek'];
        if (day == null) return false;
        final d = day is num ? day.toInt() : int.tryParse(day.toString());
        return d == currentDayOfWeek;
      }).toList();

      if (todayHours.isNotEmpty) {
        final allClosedToday = todayHours.every((h) {
          final isClosed = h['isClosed'];
          final isOpen = h['isOpen'];
          return isClosed == true ||
              isClosed == 1 ||
              isClosed == 'true' ||
              isOpen == false ||
              isOpen == 0 ||
              isOpen == 'false';
        });
        if (allClosedToday) {
          return false;
        }
      }
    }

    return true;
  }

  Future<List<dynamic>> getSalons() async {
    final response = await _apiClient.get(
      '/Salons',
      queryParameters: {
        'PageNumber': 1,
        'PageIndex': 1,
        'PageSize': 100,
        'Status': 'Open',
      },
    );
    final items = (response.data['data']['items'] as List<dynamic>?) ?? [];

    final listWithRatings = await Future.wait(
      items.map((salon) async {
        if (salon is! Map) return salon;
        final map = Map<String, dynamic>.from(salon);
        final salonId = map['salonId']?.toString() ?? '';
        final rating = await getSalonRating(salonId);
        return {...map, 'rating': rating};
      }),
    );

    // Lọc nghiêm ngặt chỉ giữ lại các salon đang MỞ cửa (loại bỏ hoàn toàn salon đóng cửa)
    return listWithRatings.where((salon) {
      if (salon is! Map) return false;
      return _isSalonOpen(salon);
    }).toList();
  }

  Future<Map<String, dynamic>?> getSalonDetail(String salonId) async {
    if (salonId.isEmpty) return null;
    final response = await _apiClient.get('/Salons/$salonId');
    final data = response.data['data'] ?? response.data;
    return data is Map ? Map<String, dynamic>.from(data) : null;
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
    final List<Map<String, dynamic>> items = [];
    if (nailVariantId > 0) {
      items.add({
        'nailVariantId': nailVariantId,
        'shapeMethodConfigId': ?shapeMethodConfigId,
        'quantity': 1,
      });
    }

    final serviceCounts = <String, int>{};
    for (final sId in serviceIds) {
      if (sId.isNotEmpty) {
        serviceCounts[sId] = (serviceCounts[sId] ?? 0) + 1;
      }
    }
    for (final entry in serviceCounts.entries) {
      items.add({'serviceId': entry.key, 'quantity': entry.value});
    }
    return items;
  }

  Future<List<dynamic>> getSuggestedArtists(
    String salonId,
    String bookingDate, {
    int nailVariantId = 0,
    List<String> serviceIds = const [],
    int? shapeMethodConfigId,
    List<Map<String, dynamic>>? bookingItems,
  }) async {
    final itemsPayload =
        bookingItems ??
        _buildBookingItems(nailVariantId, serviceIds, shapeMethodConfigId);
    final response = await _apiClient.post(
      '/Bookings/suggested-artists',
      data: {
        'salonId': salonId,
        'bookingDate': bookingDate,
        'bookingItems': itemsPayload,
      },
    );
    final items = (response.data['data'] as List<dynamic>?) ?? [];

    final listWithRatings = await Future.wait(
      items.map((artist) async {
        if (artist is! Map) return artist;
        final map = Map<String, dynamic>.from(artist);
        final artistId =
            map['nailArtistId']?.toString() ?? map['id']?.toString() ?? '';
        final firstName = map['firstName']?.toString() ?? '';
        final lastName = map['lastName']?.toString() ?? '';
        final fullName =
            map['fullName']?.toString() ?? '$firstName $lastName'.trim();
        final rating = await getNailArtistRating(artistId);
        return {
          ...map,
          'fullName': fullName.isNotEmpty ? fullName : 'Thợ nail',
          'rating': rating,
        };
      }),
    );

    listWithRatings.sort((a, b) {
      final rA = (a is Map ? a['rating'] : 0) as num? ?? 0;
      final rB = (b is Map ? b['rating'] : 0) as num? ?? 0;
      return rB.compareTo(rA);
    });

    return listWithRatings;
  }

  Future<List<dynamic>> getArtistAvailableSlots(
    String artistId,
    String bookingDate, {
    List<Map<String, dynamic>>? bookingItems,
  }) async {
    final response = await _apiClient.post(
      '/Bookings/artist-available-slots',
      data: {
        'nailArtistId': artistId,
        'bookingDate': bookingDate,
        'bookingItems': bookingItems ?? [],
      },
    );
    final List<dynamic> list =
        response.data['data']['timeSlots'] ?? response.data['data'] ?? [];
    return list.map((slot) {
      final map = Map<String, dynamic>.from(slot);
      final rawTime = map['startTime'] ?? map['time'] ?? '';
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
    final List<dynamic> list =
        response.data['data']['timeSlots'] ?? response.data['data'] ?? [];
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
      if (startTimeStr == null) return false;

      final int slotStartMin = toMinutes(startTimeStr);

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
  ///
  /// Lưu ý: [nailArtistId] có thể rỗng cho luồng "Không chọn thợ"
  /// (backend sẽ giữ chỗ ở cấp salon).
  ///
  /// Throw [AppException] với message từ server khi API trả về
  /// `isSucceeded: false` (kể cả HTTP 200 lẫn 4xx) để UI hiển thị.
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
        // Chỉ gửi nailArtistId khi có chọn thợ cụ thể
        if (nailArtistId.isNotEmpty) 'nailArtistId': nailArtistId,
        'bookingDate': bookingDate,
        'startTime': startTime,
        'bookingItems': bookingItems,
      },
    );

    // Kiểm tra ApiResponse wrapper từ backend .NET:
    // { isSucceeded: false, message: "Thợ đã đầy lịch...", data: null }
    // Một số backend trả HTTP 200 + isSucceeded=false mà Dio KHÔNG throw,
    // nên cần check thủ công để ném exception cho UI hiển thị message.
    final body = response.data;
    if (body is Map) {
      final isSucceeded = body['isSucceeded'] ?? body['IsSucceeded'] ?? true;
      if (isSucceeded == false) {
        final msg =
            (body['message'] ??
                    body['Message'] ??
                    body['error'] ??
                    body['Error'])
                ?.toString()
                .trim();
        throw AppException(
          message: (msg != null && msg.isNotEmpty)
              ? msg
              : 'Không thể giữ khung giờ này. Vui lòng chọn giờ khác.',
          code: 'HOLD_SLOT_FAILED',
          data: body,
        );
      }
    }

    return body is Map ? (body['data'] ?? {}) : {};
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

  Future<String> getBookingIdByOrderCode(int orderCode) async {
    final response = await _apiClient.get(
      '/Bookings/by-order-code/$orderCode/booking-id',
    );
    final data = response.data['data'];
    if (data is Map<String, dynamic>) {
      return data['bookingId']?.toString() ?? '';
    }
    return '';
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
    try {
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
      if (response.data is Map) {
        final dataMap = response.data['data'] ?? response.data;
        if (dataMap is Map) {
          return Map<String, dynamic>.from(dataMap);
        }
      }
      return {};
    } catch (e) {
      return {};
    }
  }

  Future<Map<String, dynamic>> reviewNailVariantPrice({
    required int nailVariantId,
    int? shapeMethodConfigId,
  }) async {
    final response = await _apiClient.post(
      '/Bookings/price',
      data: {
        'bookingItems': _buildBookingItems(
          nailVariantId,
          const [],
          shapeMethodConfigId,
        ),
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
      queryParameters: {
        'PageNumber': 1,
        'PageSize': 50,
        'salonId': salonId,
        'status': 'Active',
      },
    );
    final items = response.data['data']['items'] as List<dynamic>? ?? [];

    final listWithRatings = await Future.wait(
      items.map((artist) async {
        if (artist is! Map) return artist;
        final map = Map<String, dynamic>.from(artist);
        final artistId =
            map['nailArtistId']?.toString() ?? map['id']?.toString() ?? '';
        final firstName = map['firstName']?.toString() ?? '';
        final lastName = map['lastName']?.toString() ?? '';
        final fullName =
            map['fullName']?.toString() ?? '$firstName $lastName'.trim();
        final rating = await getNailArtistRating(artistId);
        return {
          ...map,
          'fullName': fullName.isNotEmpty ? fullName : 'Thợ nail',
          'rating': rating,
        };
      }),
    );

    listWithRatings.sort((a, b) {
      final rA = (a is Map ? a['rating'] : 0) as num? ?? 0;
      final rB = (b is Map ? b['rating'] : 0) as num? ?? 0;
      return rB.compareTo(rA);
    });

    return listWithRatings;
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

  Future<Map<String, dynamic>> reviewCustomNailBookingPrice({
    required String customerNailRequestId,
    required Map<String, int> groupedExtraServices,
    int? shapeMethodConfigId,
    List<int>? selectedPromotionIds,
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
      '/Bookings/price',
      data: {
        'bookingItems': bookingItems,
        if (selectedPromotionIds != null && selectedPromotionIds.isNotEmpty)
          'selectedPromotionIds': selectedPromotionIds,
      },
    );
    return Map<String, dynamic>.from(
      response.data['data'] ?? response.data ?? {},
    );
  }
}
