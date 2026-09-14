import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../../../generated/l10n.dart';

/// Hero Banner ngang tinh gọn cho Màn hình Trang Chủ (Height max ~135px):
/// - Bên trái: Tiêu đề thanh lịch & nút "Đặt Lịch" dạng pill gradient nhỏ gọn
/// - Bên phải: Ảnh móng tay chìm mượt vào nền
/// - Toàn bộ banner là vùng tương tác chạm (InkWell ripple effect)
class HomeBanner extends StatelessWidget {
  const HomeBanner({super.key});

  void _onBannerTap(BuildContext context) {
    AuthGuard.check(context, () {
      context.push('/home-booking');
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => _onBannerTap(context),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            height: 135,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: const LinearGradient(
                colors: [
                  Color(0xFFFFF5F7), // Hồng phấn thương hiệu
                  Color(0xFFFFE3ED), // Hồng san hô mượt
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                  offset: const Offset(0, 3),
                ),
              ],
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.9),
                width: 1.5,
              ),
            ),
            child: Stack(
              children: [
                // Ảnh bên phải chìm nhẹ vào nền
                Positioned(
                  right: -10,
                  top: -10,
                  bottom: -10,
                  width: 160,
                  child: ShaderMask(
                    shaderCallback: (rect) {
                      return const LinearGradient(
                        colors: [Colors.transparent, Colors.black],
                        stops: [0.0, 0.4],
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ).createShader(rect);
                    },
                    blendMode: BlendMode.dstIn,
                    child: Image.asset(
                      'assets/images/Ellipse 1.png',
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        color: Colors.pink.shade50.withValues(alpha: 0.5),
                        child: const Icon(
                          Icons.spa_outlined,
                          color: Color(0xFFFF527B),
                          size: 40,
                        ),
                      ),
                    ),
                  ),
                ),

                // Nội dung bên trái
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 150, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Tiêu đề thanh lịch
                      Text(
                        S.of(context).homeBannerTitle,
                        style: const TextStyle(
                          fontSize: 20,
                          fontFamily: 'serif',
                          fontStyle: FontStyle.italic,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE02B6D), // Màu hồng dâu thương hiệu
                          height: 1.15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        S.of(context).homeBannerSubtitle,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),

                      // Nút "Đặt Lịch" nhỏ gọn dạng pill
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(16),
                          gradient: const LinearGradient(
                            colors: [
                              Color(0xFFFF527B),
                              Color(0xFFFF7E53),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFFF527B).withValues(alpha: 0.3),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.calendar_month_rounded,
                              size: 13,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 5),
                            Text(
                              S.of(context).bookAppointment,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

