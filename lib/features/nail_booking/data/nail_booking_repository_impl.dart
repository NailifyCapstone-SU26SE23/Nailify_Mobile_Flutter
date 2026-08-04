import '../domain/repositories/nail_booking_repository.dart';
import '../data/datasources/booking_api_service.dart';
import '../data/datasources/promotion_api_service.dart';
import '../data/models/promotion_model.dart';

/// Implementation của [NailBookingRepository].
/// Delegate mọi lời gọi xuống [BookingApiService] và [PromotionApiService].
class NailBookingRepositoryImpl implements NailBookingRepository {
  final BookingApiService _bookingApi;
  final PromotionApiService _promotionApi;

  NailBookingRepositoryImpl({
    BookingApiService? bookingApi,
    PromotionApiService? promotionApi,
  }) : _bookingApi = bookingApi ?? BookingApiService(),
       _promotionApi = promotionApi ?? PromotionApiService();

  @override
  Future<List<Map<String, dynamic>>> getSalons() async {
    final list = await _bookingApi.getSalons();
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getServices() async {
    final list = await _bookingApi.getServices();
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getSuggestedArtists({
    required String salonId,
    required String bookingDate,
    required int nailVariantId,
    required List<String> serviceIds,
    int? shapeMethodConfigId,
  }) async {
    final list = await _bookingApi.getSuggestedArtists(
      salonId,
      bookingDate,
      nailVariantId,
      serviceIds,
      shapeMethodConfigId,
    );
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getArtistsBySalon(String salonId) async {
    final list = await _bookingApi.getNailArtistsBySalon(salonId);
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getArtistAvailableSlots({
    required String artistId,
    required String bookingDate,
  }) async {
    final list = await _bookingApi.getArtistAvailableSlots(
      artistId,
      bookingDate,
    );
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getSalonAvailableSlots({
    required String salonId,
    required String bookingDate,
    required List<Map<String, dynamic>> bookingItems,
  }) async {
    final list = await _bookingApi.getSalonAvailableSlots(
      salonId: salonId,
      bookingDate: bookingDate,
      bookingItems: bookingItems,
    );
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  List<Map<String, dynamic>> getSalonOperatingSlots({
    required Map<String, dynamic> salon,
    required DateTime date,
  }) {
    final list = _bookingApi.getSalonOperatingSlots(salon, date);
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  List<Map<String, dynamic>> filterSlotsByOperatingHours({
    required List<dynamic> slots,
    required Map<String, dynamic>? salon,
    required DateTime? date,
  }) {
    final list = _bookingApi.filterSlotsByOperatingHours(
      slots: slots,
      salon: salon,
      date: date,
    );
    return list
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }

  @override
  Future<Map<String, dynamic>> holdSlot({
    required String salonId,
    required String nailArtistId,
    required String bookingDate,
    required String startTime,
    required List<Map<String, dynamic>> bookingItems,
  }) {
    return _bookingApi.holdSlot(
      salonId: salonId,
      nailArtistId: nailArtistId,
      bookingDate: bookingDate,
      startTime: startTime,
      bookingItems: bookingItems,
    );
  }

  @override
  Future<void> cancelHoldSlot(String holdToken) {
    return _bookingApi.cancelHoldSlot(holdToken);
  }

  @override
  Future<Map<String, dynamic>> checkHoldStatus(String holdToken) {
    return _bookingApi.checkHoldStatus(holdToken);
  }

  @override
  Future<Map<String, dynamic>> createBooking({
    required String salonId,
    required String bookingDate,
    required String startTime,
    String? artistId,
    required int nailVariantId,
    required List<String> serviceIds,
    List<int>? selectedPromotionIds,
    String? holdToken,
    int? shapeMethodConfigId,
    String? warrantyForBookingId,
    List<Map<String, dynamic>>? warrantyBookingItems,
  }) {
    return _bookingApi.createBooking(
      salonId,
      bookingDate,
      startTime,
      artistId,
      nailVariantId,
      serviceIds,
      selectedPromotionIds: selectedPromotionIds,
      holdToken: holdToken,
      shapeMethodConfigId: shapeMethodConfigId,
      warrantyForBookingId: warrantyForBookingId,
      warrantyBookingItems: warrantyBookingItems,
    );
  }

  @override
  Future<Map<String, dynamic>> createServiceBooking(
    Map<String, dynamic> bookingData, {
    List<int>? selectedPromotionIds,
    String? holdToken,
  }) {
    return _bookingApi.createServiceBooking(
      bookingData,
      selectedPromotionIds: selectedPromotionIds,
      holdToken: holdToken,
    );
  }

  @override
  Future<Map<String, dynamic>> createCustomNailBooking({
    required String salonId,
    required String bookingDate,
    required String startTime,
    required String artistId,
    required int customerNailId,
    required Map<String, int> groupedExtraServices,
    int? shapeMethodConfigId,
    List<int>? selectedPromotionIds,
    String? holdToken,
  }) {
    return _bookingApi.createCustomNailBooking(
      salonId,
      bookingDate,
      startTime,
      artistId,
      customerNailId.toString(),
      groupedExtraServices,
      shapeMethodConfigId: shapeMethodConfigId,
      selectedPromotionIds: selectedPromotionIds,
      holdToken: holdToken,
    );
  }

  @override
  Future<List<PromotionModel>> getTodayPromotions() {
    return _promotionApi.getTodayPromotions();
  }
}
