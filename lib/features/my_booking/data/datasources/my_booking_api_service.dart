import 'package:dio/dio.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class MyBookingsPageResult {
  final List<dynamic> items;
  final int page;
  final bool hasNextPage;

  const MyBookingsPageResult({
    required this.items,
    required this.page,
    required this.hasNextPage,
  });
}

class MyBookingApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  Future<List<dynamic>> getMyBookings() async {
    final result = await getMyBookingsPage();
    return result.items;
  }

  Future<MyBookingsPageResult> getMyBookingsPage({
    int pageNumber = 1,
    int pageSize = 5,
  }) async {
    final response = await _apiClient.get(
      '/Bookings/my-bookings',
      queryParameters: {'pageNumber': pageNumber, 'pageSize': pageSize},
    );
    final responseData = response.data['data'];

    // API trả về đúng chuẩn Danh sách (List)
    if (responseData is List) {
      return MyBookingsPageResult(
        items: responseData,
        page: pageNumber,
        hasNextPage: false,
      );
    }

    // API bọc dữ liệu trong một Đối tượng (Map)
    if (responseData is Map) {
      // Dò tìm danh sách bên trong Map (Thường gặp ở API phân trang)
      if (responseData.containsKey('items') && responseData['items'] is List) {
        final metaData = responseData['metaData'];
        return MyBookingsPageResult(
          items: responseData['items'],
          page: _readInt(
            metaData is Map ? metaData['currentPage'] : null,
            pageNumber,
          ),
          hasNextPage: _readBool(metaData is Map ? metaData['hasNext'] : null),
        );
      }
      if (responseData.containsKey('data') && responseData['data'] is List) {
        return MyBookingsPageResult(
          items: responseData['data'],
          page: pageNumber,
          hasNextPage: false,
        );
      }

      // Trường hợp API trả về đúng 1 lịch hẹn duy nhất dưới dạng Đối tượng
      return MyBookingsPageResult(
        items: [responseData],
        page: pageNumber,
        hasNextPage: false,
      );
    }

    return MyBookingsPageResult(
      items: const [],
      page: pageNumber,
      hasNextPage: false,
    );
  }

  int _readInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  bool _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final text = value?.toString().toLowerCase().trim();
    return text == 'true' || text == '1';
  }

  Future<Map<String, dynamic>> getBookingDetails(String bookingId) async {
    final response = await _apiClient.get('/Bookings/$bookingId');
    return response.data['data'] ?? {};
  }

  Future<bool> cancelBooking(
    String bookingId, {
    required String reason,
    String holdToken = "",
  }) async {
    final response = await _apiClient.post(
      '/Bookings/$bookingId/cancel',
      data: {"reason": reason, "holdToken": holdToken},
    );
    return response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300;
  }

  Future<bool> rescheduleBooking(
    String bookingId, {
    required String bookingDate,
    required String startTime,
  }) async {
    final formattedTime = startTime.length == 5 ? "$startTime:00" : startTime;
    final response = await _apiClient.put(
      '/Bookings/$bookingId/reschedule',
      data: {"bookingDate": bookingDate, "startTime": formattedTime},
    );
    return response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300;
  }

  Future<bool> requestRescheduleBooking(
    String bookingId, {
    required String newDate,
    required String newTime,
    required String reason,
  }) async {
    // Đảm bảo định dạng giờ luôn có giây (ví dụ: "10:00" -> "10:00:00")
    final formattedTime = newTime.length == 5 ? "$newTime:00" : newTime;
    final response = await _apiClient.post(
      '/Bookings/$bookingId/request-reschedule',
      data: {"newDate": newDate, "newTime": formattedTime, "reason": reason},
    );
    return response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300;
  }

  Future<bool> acceptSuggestedTime(String bookingId) async {
    final response = await _apiClient.post(
      '/Bookings/$bookingId/accept-suggested-time',
    );
    return response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300;
  }

  Future<bool> declineSuggestedTime(String bookingId) async {
    final response = await _apiClient.post(
      '/Bookings/$bookingId/decline-suggested-time',
    );
    return response.statusCode != null &&
        response.statusCode! >= 200 &&
        response.statusCode! < 300;
  }

  Future<Map<String, dynamic>?> getRatingByBooking(String bookingId) async {
    final response = await _apiClient.get(
      '/BookingRatings/by-booking/$bookingId',
    );
    final data = response.data['data'];
    return data is Map<String, dynamic> ? data : null;
  }

  Future<List<dynamic>> getMyRatings() async {
    try {
      final response = await _apiClient.get('/BookingRatings/me');
      final responseData = response.data['data'];

      if (responseData is List) {
        return responseData;
      }

      if (responseData is Map) {
        if (responseData.containsKey('items') &&
            responseData['items'] is List) {
          return responseData['items'];
        }
        if (responseData.containsKey('data') && responseData['data'] is List) {
          return responseData['data'];
        }
      }

      // Fallback: check top-level response.data directly
      final directData = response.data;
      if (directData is Map) {
        if (directData.containsKey('items') && directData['items'] is List) {
          return directData['items'];
        }
        if (directData.containsKey('data') && directData['data'] is List) {
          final nested = directData['data'];
          if (nested is Map &&
              nested.containsKey('items') &&
              nested['items'] is List) {
            return nested['items'];
          }
        }
      }

      return [];
    } catch (_) {
      return [];
    }
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

  Future<Map<String, dynamic>> updateBookingRating({
    required String ratingId,
    required int overallScore,
    required String comment,
    required int serviceQuality,
    required int punctuality,
    required int cleanliness,
    String? imagePath,
  }) async {
    final formData = FormData.fromMap({
      'OverallScore': overallScore,
      'Comment': comment,
      'ServiceQuality': serviceQuality,
      'Punctuality': punctuality,
      'Cleanliness': cleanliness,
      if (imagePath != null && imagePath.isNotEmpty)
        'image': await MultipartFile.fromFile(imagePath),
    });

    final response = await _apiClient.put(
      '/BookingRatings/$ratingId',
      data: formData,
    );
    final data = response.data['data'];
    return data is Map<String, dynamic> ? data : {};
  }

  Future<bool> deleteBookingRating(String ratingId) async {
    final response = await _apiClient.delete('/BookingRatings/$ratingId');
    return response.statusCode == 200 || response.statusCode == 204;
  }
}
