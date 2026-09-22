import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../models/waitlist_model.dart';

class WaitlistApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  // POST /api/Waitlists/join
  Future<WaitlistApiModel> joinWaitlist({
    required String salonId,
    String? preferredNailArtistId,
    required DateTime requestedDate,
    required String requestedStartTime,
    int estimatedDuration = 60,
    List<Map<String, dynamic>> waitlistItems = const [],
  }) async {
    final response = await _apiClient.post(
      '/Waitlists/join',
      data: {
        'salonId': salonId,
        'preferredNailArtistId': ?preferredNailArtistId,
        'requestedDate': requestedDate.toIso8601String(),
        'requestedStartTime': requestedStartTime,
        'estimatedDuration': estimatedDuration,
        'waitlistItems': waitlistItems,
      },
    );
    return WaitlistApiModel.fromJson(
      response.data['data'] as Map<String, dynamic>,
    );
  }

  // POST /api/Waitlists/{id}/confirm
  Future<String?> confirmWaitlist(
    String waitlistId, {
    bool useWalletBalance = true,
    List<int>? selectedPromotionIds,
  }) async {
    final response = await _apiClient.post(
      '/Waitlists/$waitlistId/confirm',
      data: {
        "useWalletBalance": useWalletBalance,
        "selectedPromotionIds": selectedPromotionIds ?? [],
      },
    );
    if (response.statusCode == 200) {
      final data = response.data['data'];
      if (data != null && data['convertedBookingId'] != null) {
        return data['convertedBookingId'].toString();
      }
      return "SUCCESS_NO_ID"; // In case it succeeded but no ID returned somehow
    }
    return null;
  }

  // POST /api/Waitlists/{id}/cancel
  Future<bool> cancelWaitlist(String waitlistId) async {
    final response = await _apiClient.post(
      '/Waitlists/$waitlistId/cancel',
      data: {},
    );
    return response.statusCode == 200;
  }

  // GET /api/Waitlists/me
  Future<List<WaitlistApiModel>> getMyWaitlists() async {
    final response = await _apiClient.get('/Waitlists/me');
    final data = response.data['data'];
    if (data is List) {
      return data
          .whereType<Map<String, dynamic>>()
          .map((json) => WaitlistApiModel.fromJson(json))
          .toList();
    }
    return [];
  }
}
