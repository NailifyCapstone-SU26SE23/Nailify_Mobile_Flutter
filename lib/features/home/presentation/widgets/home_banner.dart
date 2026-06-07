// lib/features/home/presentation/widgets/home_banner.dart
import 'package:flutter/material.dart';

class HomeBanner extends StatelessWidget {
  const HomeBanner({super.key});

  // chưa có page booking nên chèn đỡ
  void _showBookingPopup(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.event_available, color: Color(0xFFFF66C4)),
            SizedBox(width: 8),
            Text('Thông báo'),
          ],
        ),
        content: const Text('Tính năng "Book Now" đang được phát triển. Vui lòng quay lại sau!'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng', style: TextStyle(color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        // Cấu hình khung và bo góc
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          // Mã màu Gradient
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFF66C4), // Hồng
              Color(0xFFFFFFFF), // Vàng
            ],
            // Với bố cục dọc
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFFF66C4).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 24.0),
        // SỬ DỤNG COLUMN ĐỂ CHIA 2 MẢNG TRÊN/DƯỚI VÀ KÉO DÀI BANNER
        child: Column(
          mainAxisSize: MainAxisSize.min, // Tự động kéo dài theo nội dung
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
          //ảnh
            ClipRRect(
              borderRadius: BorderRadius.circular(20), // Bo góc cho ảnh
              child: Image.asset(
                'assets/images/Ellipse 1.png',
                width: 140, //banner dọc
                height: 140,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  width: 140,
                  height: 140,
                  color: Colors.white.withOpacity(0.3),
                  child: const Icon(Icons.image_not_supported, color: Colors.white, size: 40),
                ),
              ),
            ),

            const SizedBox(height: 24), // Khoảng cách giữa hình và chữ

            // 2. MẢNG DƯỚI: Chữ
            const Text(
              'Beauty on\nyour\nfingerlips',
              textAlign: TextAlign.center, // Căn giữa chữ
              style: TextStyle(
                fontSize: 42,
                fontFamily: "Dancing Script",
                //fontWeight: FontWeight.bold,
                color: const Color(0xFFFF66C4),
                height: 1.3,
              ),
            ),

            const SizedBox(height: 12),

            const Text(
              'Discover effortless elegance\nwith every touch',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black,
                height: 1.4, // Tạo khoảng cách dòng
              ),
            ),
            const SizedBox(height: 32),

            // Nút Book Now
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => _showBookingPopup(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFFF66C4),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(25),
                  ),
                ),
                child: const Text(
                  'Book Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
          ],

        ),
      ),
    );
  }
}