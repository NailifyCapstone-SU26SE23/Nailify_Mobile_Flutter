import '../../data/models/promotion_model.dart';

/// Abstract interface định nghĩa các chức năng dữ liệu của tính năng Đặt lịch.
/// Implementation nằm ở [NailBookingRepositoryImpl].
abstract class NailBookingRepository {
  /// Lấy danh sách salon/chi nhánh.
  Future<List<Map<String, dynamic>>> getSalons();

  /// Lấy danh sách dịch vụ thêm.
  Future<List<Map<String, dynamic>>> getServices();

  /// Lấy danh sách thợ được gợi ý dựa trên salon, ngày, và dịch vụ.
  Future<List<Map<String, dynamic>>> getSuggestedArtists({
    required String salonId,
    required String bookingDate,
    required int nailVariantId,
    required List<String> serviceIds,
  });

  /// Lấy danh sách thợ theo salon (dùng cho ServiceBooking).
  Future<List<Map<String, dynamic>>> getArtistsBySalon(String salonId);

  /// Lấy danh sách slot giờ rảnh của thợ theo ngày.
  Future<List<Map<String, dynamic>>> getArtistAvailableSlots({
    required String artistId,
    required String bookingDate,
  });

  /// Tạo danh sách slot từ lịch hoạt động của salon (khi không chọn thợ).
  List<Map<String, dynamic>> getSalonOperatingSlots({
    required Map<String, dynamic> salon,
    required DateTime date,
  });

  /// Tạo booking từ luồng Nail Variant.
  Future<Map<String, dynamic>> createBooking({
    required String salonId,
    required String bookingDate,
    required String startTime,
    String? artistId,
    required int nailVariantId,
    required List<String> serviceIds,
    List<int>? selectedPromotionIds,
  });

  /// Tạo booking từ luồng Service độc lập.
  Future<Map<String, dynamic>> createServiceBooking(
    Map<String, dynamic> bookingData, {
    List<int>? selectedPromotionIds,
  });

  /// Tạo booking từ luồng Custom Nail.
  Future<Map<String, dynamic>> createCustomNailBooking({
    required String salonId,
    required String bookingDate,
    required String startTime,
    required String artistId,
    required int customerNailId,
    required Map<String, int> groupedExtraServices,
    List<int>? selectedPromotionIds,
  });

  /// Lấy danh sách khuyến mãi.
  Future<List<PromotionModel>> getPromotions();
}
