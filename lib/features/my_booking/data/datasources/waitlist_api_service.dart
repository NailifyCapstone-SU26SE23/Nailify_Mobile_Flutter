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
    final response = await _apiClient.post('/Waitlists/join', data: {
      'salonId': salonId,
      if (preferredNailArtistId != null)
        'preferredNailArtistId': preferredNailArtistId,
      'requestedDate': requestedDate.toIso8601String(),
      'requestedStartTime': requestedStartTime,
      'estimatedDuration': estimatedDuration,
      'waitlistItems': waitlistItems,
    });
    return WaitlistApiModel.fromJson(response.data['data'] as Map<String, dynamic>);
  }

  // POST /api/Waitlists/{id}/confirm
  Future<bool> confirmWaitlist(String waitlistId) async {
    final response = await _apiClient.post('/Waitlists/$waitlistId/confirm', data: {});
    return response.statusCode == 200;
  }

  // POST /api/Waitlists/{id}/cancel
  Future<bool> cancelWaitlist(String waitlistId) async {
    final response = await _apiClient.post('/Waitlists/$waitlistId/cancel', data: {});
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
