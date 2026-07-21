import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

class HomeGallery extends StatelessWidget {
  const HomeGallery({super.key});

  void _showPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Thông báo'),
        content: const Text('Chuyển hướng đến Thư viện ảnh đầy đủ.\nTính năng này đang được phát triển.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Đóng', style: TextStyle(color: AppColors.textPrimary)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Dữ liệu hình ảnh mẫu
    final galleryImages = [
      'assets/images/Rectangle 1.png',
      'assets/images/Rectangle 2.png',
      'assets/images/home-mid.jpg',
      'assets/images/image.png',
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),

      child: Container(
        // Thêm padding bên trong để nội dung không dính sát vào mép khung Gradient
        padding: const EdgeInsets.all(16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          // Mã màu Gradient
          gradient: LinearGradient(
            colors: [
              AppColors.primary,
              AppColors.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),

        child: Column(

          children: [
            const SizedBox(height: 5),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Thư viện mẫu Nail',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.surface,
                  ),
                ),

              ],
            ),
            const SizedBox(height: 12),

            // 2. Lưới hình ảnh bo tròn góc
            GridView.builder(
              shrinkWrap: true, // Cuộn chung với trang chính
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2, // Chia 2 cột
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.85, // Tỉ lệ khung ảnh
              ),
              itemCount: galleryImages.length,
              itemBuilder: (context, index) {
                return GestureDetector(
                  onTap: () => _showPopup(context), // hiện Popup
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.asset(
                      galleryImages[index],
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.white,
                        child: const Icon(Icons.image, color: AppColors.surface),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),

            // Nút xem thêm
            SizedBox(
              width: 302,
              height: 50,
              child: ElevatedButton(
                onPressed: () => context.go('/nails'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.surface,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Xem thêm ->',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}