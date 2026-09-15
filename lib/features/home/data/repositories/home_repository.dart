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
              .map((item) => HomeCategoryItem.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {
      // Ignored: dùng fallback nếu không có mạng
    }

    return const [
      HomeCategoryItem(id: 1, title: 'Chăm sóc móng', imagePath: 'assets/images/image 1.png'),
      HomeCategoryItem(id: 2, title: 'Sơn Gel', imagePath: 'assets/images/image 2.png'),
      HomeCategoryItem(id: 3, title: 'Vẽ Nghệ Thuật', imagePath: 'assets/images/image 3.png'),
      HomeCategoryItem(id: 4, title: 'Úp Móng Acrylic', imagePath: 'assets/images/image 4.png'),
      HomeCategoryItem(id: 5, title: 'Dưỡng Móng', imagePath: 'assets/images/home-mid.jpg'),
    ];
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
              .map((item) => HomeGalleryItem.fromJson(item as Map<String, dynamic>))
              .toList();
        }
      }
    } catch (_) {
      // Ignored: dùng fallback nếu API lỗi
    }

    return const [
      HomeGalleryItem(id: 1, title: 'Hoa Anh Đào', imageUrl: 'assets/images/Rectangle 1.png'),
      HomeGalleryItem(id: 2, title: 'Gel Kim Tuyến', imageUrl: 'assets/images/Rectangle 2.png'),
      HomeGalleryItem(id: 3, title: 'Ombre Hồng San Hô', imageUrl: 'assets/images/home-mid.jpg'),
      HomeGalleryItem(id: 4, title: 'Art Đính Đá Nổi', imageUrl: 'assets/images/image.png'),
    ];
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
              .map((item) => HomeReviewItem.fromJson(item as Map<String, dynamic>))
              .where((r) => r.stars >= 3)
              .toList();
          if (reviews.isNotEmpty) {
            return reviews;
          }
        }
      }
    } catch (_) {
      // Ignored: dùng fallback nếu API lỗi
    }

    return const [
      HomeReviewItem(
        id: '1',
        name: 'Linh Mai',
        initials: 'LM',
        review: 'Tôi rất yêu thích bộ móng của mình! Nhân viên ở đây vô cùng tài năng và các thiết kế rất lộng lẫy.',
        stars: 5,
        timeAgo: '2 ngày trước',
      ),
      HomeReviewItem(
        id: '2',
        name: 'Thu Nga',
        initials: 'TN',
        review: 'Màu sơn gương (chrome) lên cực chuẩn, các bạn nhân viên cực kỳ chu đáo và thân thiện!',
        stars: 4,
        timeAgo: '5 ngày trước',
      ),
      HomeReviewItem(
        id: '3',
        name: 'Hoàng Anh',
        initials: 'HA',
        review: 'Không gian salon sang trọng, móng giữ được tương đối bền lâu. Rất hài lòng.',
        stars: 5,
        timeAgo: '1 tuần trước',
      ),
      HomeReviewItem(
        id: '4',
        name: 'Phương Thảo',
        initials: 'PT',
        review: 'Nhân viên tư vấn nhiệt tình, làm móng tay rất sạch sẽ và cẩn thận.',
        stars: 4,
        timeAgo: '2 tuần trước',
      ),
      HomeReviewItem(
        id: '5',
        name: 'Bích Ngọc',
        initials: 'BN',
        review: 'Dịch vụ nhanh chóng, màu sơn tươi tắn đúng như thiết kế tôi chọn.',
        stars: 3,
        timeAgo: '3 tuần trước',
      ),
    ];
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
    } catch (_) {
      // Ignored
    }
    return const HomeSalonItem(
      id: '',
      name: 'Tìm salon gần bạn nhất',
      address: 'Khám phá hệ thống Nailify trên toàn quốc',
    );
  }
}
