import '../../../core/network/api_client.dart';
import 'models/booking_rating_model.dart';
import 'models/nail_artist_model.dart';

class NailArtistRepository {
  final ApiClient _apiClient;

  const NailArtistRepository(this._apiClient);

  Future<NailArtistModel> getNailArtistDetail(String nailArtistId) async {
    final response = await _apiClient.get('/NailArtists/$nailArtistId');
    final data = _readData(response.data);
    return NailArtistModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<BookingRatingModel>> getNailArtistRatings(
    String nailArtistId, {
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    final response = await _apiClient.get(
      '/BookingRatings/by-nail-artist/$nailArtistId',
      queryParameters: {
        'PageNumber': pageNumber,
        'PageSize': pageSize,
      },
    );

    return _readItems(response.data)
        .whereType<Map>()
        .map((item) =>
            BookingRatingModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }
}

dynamic _readData(dynamic responseData) {
  if (responseData is Map && responseData.containsKey('data')) {
    return responseData['data'];
  }
  return responseData;
}

List<dynamic> _readItems(dynamic responseData) {
  final data = _readData(responseData);
  if (data is Map && data['items'] is List) return data['items'] as List;
  if (data is List) return data;
  return const [];
}
