import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
            child: const Text('Đóng', style: TextStyle(color: Colors.black87)),
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
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFF66C4), // Hồng
              Color(0xFFFDF7FA), // Vàng
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
                    color: Colors.white,
                  ),
                ),
                // TextButton(
                //   onPressed: () => _showPopup(context),
                //   child: const Text(
                //     'Xem tất cả',
                //     style: TextStyle(
                //       color: Colors.white, // Đổi sang màu trắng cho dễ đọc
                //       fontWeight: FontWeight.w600,
                //     ),
                //   ),
                // ),
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
                        color: Colors.white.withOpacity(0.3), // Nền báo lỗi mờ
                        child: const Icon(Icons.image, color: Colors.white),
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
                onPressed: () => context.push('/catalog'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF66C4),
                  foregroundColor: Colors.white,
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