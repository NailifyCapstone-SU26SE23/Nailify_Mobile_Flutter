import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class HomeServices extends StatelessWidget {
  const HomeServices({super.key});

  void _showPopup(BuildContext context, String serviceName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Thông báo'),
        content: Text('Chuyển hướng đến chi tiết dịch vụ: "$serviceName".\nTính năng này đang phát triển.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final services = [
      {'title': 'Cắt móng & Da', 'image': 'assets/images/image 1.png'},
      {'title': 'Sơn Gel', 'image': 'assets/images/image 2.png'},
      {'title': 'Vẽ Móng', 'image': 'assets/images/image 3.png'},
      {'title': 'Đắp Bột', 'image': 'assets/images/image 4.png'},
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          //Dòng tiêu đề
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Dịch vụ của chúng tôi',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              TextButton(
                onPressed: () => _showPopup(context, 'Xem tất cả dịch vụ'),
                child: const Text(
                  'Xem tất cả',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // 2. Lưới 2 cột chứa các hình ảnh dịch vụ
          GridView.builder(
            shrinkWrap: true, // Ép GridView cuộn chung với trang tổng
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2, // Chia 2 cột
              crossAxisSpacing: 16, // Khoảng cách giữa 2 cột
              mainAxisSpacing: 16, // Khoảng cách giữa các hàng
              childAspectRatio: 0.9, // Tỉ lệ chiều cao nhỉnh hơn chiều rộng một chút
            ),
            itemCount: services.length,
            itemBuilder: (context, index) {
              final service = services[index];
              return _buildServiceCard(context, service['title']!, service['image']!);
            },
          ),
        ],
      ),
    );
  }

  //dựng Layout xếp chồng cho từng ô (Card)
  Widget _buildServiceCard(BuildContext context, String title, String imagePath) {
    return GestureDetector(
      onTap: () => _showPopup(context, title),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16), // Bo tròn khung
        child: Stack(
          fit: StackFit.expand, // Cho phép các lớp mở rộng chiếm hết ô lưới
          children: [
            // HÌNH ẢNH SẢN PHẨM
            Image.asset(
              imagePath,
              fit: BoxFit.cover, // Cắt cúp ảnh cho vừa vặn không bị méo
              errorBuilder: (context, error, stackTrace) => Container(
                color: Colors.grey.shade200,
                child: const Icon(Icons.image, color: Colors.grey),
              ),
            ),

            // ==========================================
            // LỚP GIỮA: HIỆU ỨNG GRADIENT ĐEN MỜ
            // (Giúp chữ trắng không bị chìm nếu nền ảnh quá sáng)
            // ==========================================
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AppColors.primary.withOpacity(0.7),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.2, 1.0], // Bắt đầu đổ mờ
                ),
              ),
            ),

            // CHỮ TÊN DỊCH Vụ
            Positioned(
              bottom: 12,
              left: 12,
              right: 12,
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.surface,
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}