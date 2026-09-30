import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_response_parser.dart';
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
          final reviewFutures = items.map((item) async {
            var review = HomeReviewItem.fromJson(item as Map<String, dynamic>);

            if (review.customerId.isNotEmpty &&
                (review.name.isEmpty ||
                    review.name == 'Khách hàng' ||
                    review.name == 'Customer')) {
              try {
                final userRes = await _apiClient.get<dynamic>(
                  '/Users/${review.customerId}',
                );
                final userData = ApiResponseParser.unwrapMap(userRes.data);
                final firstName =
                    (userData['firstName'] ?? userData['FirstName'] ?? '')
                        .toString()
                        .trim();
                final lastName =
                    (userData['lastName'] ?? userData['LastName'] ?? '')
                        .toString()
                        .trim();

                String fetchedName = '';
                if (lastName.isNotEmpty && firstName.isNotEmpty) {
                  fetchedName = '$lastName $firstName';
                } else if (firstName.isNotEmpty) {
                  fetchedName = firstName;
                } else if (lastName.isNotEmpty) {
                  fetchedName = lastName;
                } else {
                  fetchedName = (userData['fullName'] ??
                          userData['FullName'] ??
                          userData['name'] ??
                          userData['userName'] ??
                          '')
                      .toString()
                      .trim();
                }

                if (fetchedName.isNotEmpty) {
                  review = review.copyWith(
                    name: fetchedName,
                    initials: HomeReviewItem.calculateInitials(fetchedName),
                  );
                }
              } catch (_) {
                // If user fetch fails, retain default parsed review
              }
            }
            return review;
          }).toList();

          final reviews = (await Future.wait(reviewFutures))
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
