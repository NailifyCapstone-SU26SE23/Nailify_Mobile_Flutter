import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class CustomerReviews extends StatelessWidget {
  const CustomerReviews({super.key});

  @override
  Widget build(BuildContext context) {
    // Dữ liệu mẫu (Mock data)
    final List<Map<String, dynamic>> reviews = [
      {
        'initials': 'LM',
        'name': 'Linh Mai',
        'type': 'Regular client',
        'review':
            '"Absolutely love my nails! The team here is so talented and the designs are stunning. Will definitely be back!"',
        'gradientColors': [
          const Color(0xFFFF66C4),
          const Color(0xFFFFB347),
        ], // Hồng sang Cam
      },
      {
        'initials': 'TN',
        'name': 'Thu Nga',
        'type': 'New client',
        'review':
            '"The chrome finish is breathtaking and the staff is so welcoming."',
        'gradientColors': [
          const Color(0xFFB39DDB),
          const Color(0xFF7E57C2),
        ], // Tím nhạt sang Tím đậm
      },
      {
        'initials': 'HA',
        'name': 'Hoang Anh',
        'type': 'VIP client',
        'review':
            '"Best nail salon in town. The attention to detail is unmatched, and my nails last for weeks without chipping!"',
        'gradientColors': [
          const Color(0xFF81D4FA),
          const Color(0xFF29B6F6),
        ], // Xanh dương
      },
    ];

    return Container(
      color: const Color(0xFFFFF5F8), // Màu nền hồng phấn cực kỳ dịu mắt
      padding: const EdgeInsets.symmetric(vertical: 48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Phần Tiêu đề ---
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Row(
              children: [
                Icon(Icons.favorite_rounded, color: AppColors.primary, size: 16),
                SizedBox(width: 6),
                Text(
                  'HAPPY CLIENTS',
                  style: TextStyle(
                    color: AppColors.primaryDark,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 2.0,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Our Valuable Customers',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // --- Carousel ---
          SizedBox(
            height: 250, // chiều cao danh sách ngang
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              itemCount: reviews.length,
              itemBuilder: (context, index) {
                final review = reviews[index];
                return _buildReviewCard(
                  initials: review['initials'],
                  name: review['name'],
                  type: review['type'],
                  reviewText: review['review'],
                  gradientColors: review['gradientColors'],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewCard({
    required String initials,
    required String name,
    required String type,
    required String reviewText,
    required List<Color> gradientColors,
  }) {
    return Container(
      width: 290,
      margin: const EdgeInsets.only(right: 18.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: const Color(0xFFFFF0F5),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Watermark Quote Icon trang nhã ở góc trên bên phải
          Positioned(
            top: -10,
            right: -10,
            child: Icon(
              Icons.format_quote_rounded,
              size: 70,
              color: AppColors.primary.withValues(alpha: 0.12),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 5 Ngôi sao
              Row(
                children: List.generate(
                  5,
                  (index) => const Icon(Icons.star_rounded,
                      color: Color(0xFFFFD54F), size: 18),
                ),
              ),
              const SizedBox(height: 14),

              // Nội dung đánh giá
              Expanded(
                child: Text(
                  reviewText,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                    height: 1.5,
                  ),
                  overflow: TextOverflow.fade,
                ),
              ),
              const SizedBox(height: 14),

              // Thông tin khách hàng
              Row(
                children: [
                  // Avatar Gradient bo tròn tinh tế
                  Container(
                    width: 44,
                    height: 44,
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
                          color: gradientColors.last.withValues(alpha: 0.3),
                          blurRadius: 6,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Tên và Loại khách hàng
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          name,
                          style: const TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          type,
                          style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
