import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n.dart';
import '../../data/models/home_data_models.dart';

/// Khối Đánh Giá Khách Hàng (Customer Reviews):
/// - Dạng thẻ mini vuốt ngang (Horizontal Scroll Carousel), bo tròn mềm mại
/// - Hỗ trợ nạp dữ liệu động từ API hoặc danh sách mặc định
class CustomerReviews extends StatelessWidget {
  final List<HomeReviewItem> reviews;

  const CustomerReviews({
    super.key,
    this.reviews = const [],
  });

  @override
  Widget build(BuildContext context) {
    final List<HomeReviewItem> displayList = reviews.isNotEmpty
        ? reviews
        : [
            HomeReviewItem(
              id: '1',
              name: 'Linh Mai',
              initials: 'LM',
              review: S.of(context).reviewLinhMai,
              stars: 5,
              timeAgo: '2 ngày trước',
            ),
            HomeReviewItem(
              id: '2',
              name: 'Thu Nga',
              initials: 'TN',
              review: S.of(context).reviewThuNga,
              stars: 4,
              timeAgo: '5 ngày trước',
            ),
            HomeReviewItem(
              id: '3',
              name: 'Hoàng Anh',
              initials: 'HA',
              review: S.of(context).reviewHoangAnh,
              stars: 5,
              timeAgo: '1 tuần trước',
            ),
            const HomeReviewItem(
              id: '4',
              name: 'Phương Thảo',
              initials: 'PT',
              review: 'Nhân viên tư vấn nhiệt tình, làm móng tay rất sạch sẽ và cẩn thận.',
              stars: 4,
              timeAgo: '2 tuần trước',
            ),
            const HomeReviewItem(
              id: '5',
              name: 'Bích Ngọc',
              initials: 'BN',
              review: 'Dịch vụ nhanh chóng, màu sơn tươi tắn đúng như thiết kế tôi chọn.',
              stars: 3,
              timeAgo: '3 tuần trước',
            ),
          ];

    final gradients = [
      [const Color(0xFFFF4B72), const Color(0xFFFF7E53)],
      [const Color(0xFFB39DDB), const Color(0xFF7E57C2)],
      [const Color(0xFF81D4FA), const Color(0xFF29B6F6)],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tiêu đề khối Reviews
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(
                Icons.favorite_rounded,
                color: Color(0xFFFF4B72),
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                S.of(context).reviewsTitle,
                style: const TextStyle(
                  color: Color(0xFFE02B6D),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        // Danh sách Card mini vuốt ngang (Social Media Review Style)
        SizedBox(
          height: 155,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: displayList.length,
            itemBuilder: (context, index) {
              final review = displayList[index];
              return _buildMiniReviewCard(
                context: context,
                initials: review.initials,
                name: review.name,
                reviewText: review.review,
                stars: review.stars,
                gradientColors: gradients[index % gradients.length],
                timeAgo: review.timeAgo,
                imageUrl: review.imageUrl,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildMiniReviewCard({
    required BuildContext context,
    required String initials,
    required String name,
    required String reviewText,
    required int stars,
    required List<Color> gradientColors,
    required String timeAgo,
    String? imageUrl,
  }) {
    final hasImage = imageUrl != null && imageUrl.trim().isNotEmpty;

    return Container(
      width: 255,
      margin: const EdgeInsets.only(right: 12.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFFE3ED), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Avatar + Tên + Badge xác minh
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: gradientColors.first.withValues(alpha: 0.25),
                      blurRadius: 4,
                    ),
                  ],
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.verified_rounded,
                          color: Color(0xFFFF4B72),
                          size: 13,
                        ),
                      ],
                    ),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.grey.shade500,
                      ),
                    ),
                  ],
                ),
              ),
              // Rating 5 sao (filled & outline)
              Row(
                children: List.generate(
                  5,
                  (index) => Icon(
                    index < stars ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: index < stars ? const Color(0xFFFFD54F) : Colors.grey.shade300,
                    size: 12,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          // Nội dung review + Ảnh đính kèm (nếu có)
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    '"$reviewText"',
                    style: TextStyle(
                      color: Colors.grey.shade800,
                      fontSize: 11,
                      fontStyle: FontStyle.italic,
                      height: 1.3,
                    ),
                    maxLines: 4,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (hasImage) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (_) => Dialog(
                          backgroundColor: Colors.transparent,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: Image.network(imageUrl, fit: BoxFit.contain),
                          ),
                        ),
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 54,
                        height: 54,
                        child: Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image_rounded, size: 20, color: Colors.grey),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


