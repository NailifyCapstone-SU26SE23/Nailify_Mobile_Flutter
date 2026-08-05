import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../../../generated/l10n.dart';

class HomeBanner extends StatelessWidget {
  const HomeBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        // Cấu hình khung và bo góc
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          // Mã màu Gradient mềm mại hơn, sang trọng
          gradient: const LinearGradient(
            colors: [
              Color(0xFFFFF0F5), // primarySurface - hồng nhạt tinh khôi
              Color(0xFFFFE0EC), // primaryLight
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.15),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 36.0, horizontal: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Ảnh oval nghệ thuật có viền trắng dày sang trọng
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(100),
                child: Image.asset(
                  'assets/images/Ellipse 1.png',
                  width: 130,
                  height: 130,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: 130,
                    height: 130,
                    color: Colors.white,
                    child: const Icon(
                      Icons.spa_outlined,
                      color: AppColors.primary,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Tiêu đề với font chữ Serif nghiêng cao cấp kiểu tạp chí thời trang
            Text(
              S.of(context).homeBannerTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 44,
                fontFamily: 'serif',
                fontStyle: FontStyle.italic,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark, // Màu hồng mận chín sang trọng
                height: 1.15,
                letterSpacing: 0.5,
                shadows: [
                  Shadow(
                    color: Colors.white54,
                    offset: Offset(0, 1),
                    blurRadius: 2,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            Text(
              S.of(context).homeBannerSubtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 28),

            // Nút Book Now cao cấp dạng Gradient
            Container(
              width: double.infinity,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(26),
                gradient: const LinearGradient(
                  colors: [AppColors.primary, AppColors.primaryDark],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryDark.withValues(alpha: 0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton(
                onPressed: () {
                  AuthGuard.check(context, () {
                    context.push('/nail-booking');
                  });
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  foregroundColor: Colors.white,
                  shadowColor: Colors.transparent,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
                child: Text(
                  S.of(context).bookNowButton,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.5,
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
