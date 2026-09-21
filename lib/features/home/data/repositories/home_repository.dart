import '../../../../core/network/api_client.dart';
import '../models/home_data_models.dart';

class HomeRepository {
  final ApiClient _apiClient;

  HomeRepository(this._apiClient);

  /// Lấy danh sách Dịch Vụ Nổi Bật từ BE API (/Services)
  Future<List<HomeCategoryItem>> getFeaturedServices() async {
    try {
      final response = await _apiClient.get<dynamic>(
        '/Services',
        queryParameters: {'pageNumber': 1, 'pageSize': 10, 'status': 'Active'},
      );
      if (response.data != null && response.data['data'] != null) {
        final List items = response.data['data']['items'] ?? [];
        if (items.isNotEmpty) {
          return items
              .map(
                (item) =>
                    HomeCategoryItem.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        }
      }
      return [];
    } catch (_) {
      rethrow;
    }
  }

  /// Lấy danh sách Mẫu Móng Bộ Sưu Tập (/NailDesigns)
  Future<List<HomeGalleryItem>> getGalleryDesigns() async {
    try {
      final response = await _apiClient.get<dynamic>(
        '/NailDesigns',
        queryParameters: {'pageNumber': 1, 'pageSize': 10, 'status': 'Active'},
      );
      if (response.data != null && response.data['data'] != null) {
        final List items = response.data['data']['items'] ?? [];
        if (items.isNotEmpty) {
          return items
              .map(
                (item) =>
                    HomeGalleryItem.fromJson(item as Map<String, dynamic>),
              )
              .toList();
        }
      }
      return [];
    } catch (_) {
      rethrow;
    }
  }

  /// Lấy danh sách Ý Kiến Đánh Giá Khách Hàng (/BookingRatings từ 3-5 sao)
  Future<List<HomeReviewItem>> getCustomerReviews() async {
    try {
      final response = await _apiClient.get<dynamic>(
        '/BookingRatings',
        queryParameters: {'PageNumber': 1, 'PageSize': 10},
      );
      if (response.data != null && response.data['data'] != null) {
        final List items = response.data['data']['items'] ?? [];
        if (items.isNotEmpty) {
          final reviews = items
              .map(
                (item) => HomeReviewItem.fromJson(item as Map<String, dynamic>),
              )
              .where((r) => r.stars >= 3)
              .toList();
          if (reviews.isNotEmpty) {
            return reviews;
          }
        }
      }
      return [];
    } catch (_) {
      rethrow;
    }
  }

  /// Lấy chi nhánh Salon (/Salons)
  Future<HomeSalonItem?> getNearestSalon() async {
    try {
      final response = await _apiClient.get<dynamic>(
        '/Salons',
        queryParameters: {'PageNumber': 1, 'PageSize': 1, 'Status': 'Open'},
      );
      if (response.data != null && response.data['data'] != null) {
        final List items = response.data['data']['items'] ?? [];
        if (items.isNotEmpty) {
          return HomeSalonItem.fromJson(items.first as Map<String, dynamic>);
        }
      }
      return null;
    } catch (_) {
      rethrow;
    }
  }
}
