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
        'review': '"Absolutely love my nails! The team here is so talented and the designs are stunning. Will definitely be back!"',
        'gradientColors': [const Color(0xFFFF66C4), const Color(0xFFFFB347)], // Hồng sang Cam
      },
      {
        'initials': 'TN',
        'name': 'Thu Nga',
        'type': 'New client',
        'review': '"The chrome finish is breathtaking and the staff is so welcoming."',
        'gradientColors': [const Color(0xFFB39DDB), const Color(0xFF7E57C2)], // Tím nhạt sang Tím đậm
      },
      {
        'initials': 'HA',
        'name': 'Hoang Anh',
        'type': 'VIP client',
        'review': '"Best nail salon in town. The attention to detail is unmatched, and my nails last for weeks without chipping!"',
        'gradientColors': [const Color(0xFF81D4FA), const Color(0xFF29B6F6)], // Xanh dương
      },
    ];

    return Container(
      color: AppColors.secondary, // Màu nền tổng thể nhạt
      padding: const EdgeInsets.symmetric(vertical: 48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Phần Tiêu đề ---
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'HAPPY CLIENTS',
              style: TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.5,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 24.0),
            child: Text(
              'Our Valuable Customers',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 32,
                fontWeight: FontWeight.w600,
                fontFamily: 'Cormorant Garamond',
              ),
            ),
          ),
          const SizedBox(height: 32),

          // --- Carousel ---
          SizedBox(
            height: 260, // chiều cao  danh sách ngang
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(), // Hiệu ứng nảy mượt mà khi cuộn
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
      width: 280, //tạo hiệu ứng carousel
      margin: const EdgeInsets.only(right: 16.0),
      padding: const EdgeInsets.all(24.0),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primary, // Viền hồng nhạt
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 5 Ngôi sao
          Row(
            children: List.generate(
              5,
                  (index) => const Icon(
                Icons.star,
                color: Color(0xFFFFD54F),
                size: 20,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Nội dung đánh giá
          Expanded(
            child: Text(
              reviewText,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontStyle: FontStyle.italic,
                height: 1.5,
              ),
              overflow: TextOverflow.fade,
            ),
          ),
          const SizedBox(height: 16),

          // Thông tin khách hàng
          Row(
            children: [
              // Avatar Gradient
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: gradientColors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: AppColors.surface,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Tên và Loại khách hàng
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    type,
                    style: const TextStyle(
                      color: AppColors.textSecondary,
                      fontSize: 14,
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