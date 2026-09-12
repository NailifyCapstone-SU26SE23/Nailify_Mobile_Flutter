import '../../../core/network/api_client.dart';
import 'models/booking_rating_model.dart';
import 'models/nail_artist_model.dart';
import 'models/salon_model.dart';

class SalonRepository {
  final ApiClient _apiClient;

  const SalonRepository(this._apiClient);

  Future<List<SalonModel>> getSalons({
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    final response = await _apiClient.get(
      '/Salons',
      queryParameters: {'PageNumber': pageNumber, 'PageSize': pageSize, 'Status': 'Open'},
    );

    return _readItems(response.data)
        .whereType<Map>()
        .map((item) => SalonModel.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<SalonModel> getSalonDetail(String salonId) async {
    final response = await _apiClient.get('/Salons/$salonId');
    final data = _readData(response.data);
    return SalonModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<List<SalonOffDate>> getSalonOffDates(String salonId) async {
    final response = await _apiClient.get('/SalonOffDates/salons/$salonId');
    return _readDataList(response.data)
        .whereType<Map>()
        .map((item) => SalonOffDate.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  Future<List<BookingRatingModel>> getSalonRatings(
    String salonId, {
    int pageNumber = 1,
    int pageSize = 10,
  }) async {
    final response = await _apiClient.get(
      '/BookingRatings/by-salon/$salonId',
      queryParameters: {'PageNumber': pageNumber, 'PageSize': pageSize},
    );

    return _readItems(response.data)
        .whereType<Map>()
        .map(
          (item) =>
              BookingRatingModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }

  Future<List<NailArtistModel>> getSalonArtists(
    String salonId, {
    int pageNumber = 1,
    int pageSize = 50,
  }) async {
    final response = await _apiClient.get(
      '/NailArtists',
      queryParameters: {
        'PageNumber': pageNumber,
        'PageSize': pageSize,
        'salonId': salonId,
        'status': 'Active'
      },
    );

    return _readItems(response.data)
        .whereType<Map>()
        .map(
          (item) => NailArtistModel.fromJson(Map<String, dynamic>.from(item)),
        )
        .toList();
  }
}

dynamic _readData(dynamic responseData) {
  if (responseData is Map && responseData.containsKey('data')) {
    return responseData['data'];
  }
  return responseData;
}

List<dynamic> _readDataList(dynamic responseData) {
  final data = _readData(responseData);
  return data is List ? data : const [];
}

List<dynamic> _readItems(dynamic responseData) {
  final data = _readData(responseData);
  if (data is Map && data['items'] is List) return data['items'] as List;
  if (data is List) return data;
  return const [];
}
