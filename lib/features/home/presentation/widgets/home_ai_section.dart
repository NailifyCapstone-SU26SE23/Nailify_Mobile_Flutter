import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

/// Khối AI (Trọng tâm đề tài Nailify):
/// - 2 thẻ bo góc 20px kính mờ Glassmorphism viền mảnh
/// - Thẻ 1: Icon Camera AR 3D + "Thử móng AR" + tag "Hot"
/// - Thẻ 2: Icon Bảng màu + "AI Match Style" + tag "Gợi ý"
/// - Chạm trực tiếp vào toàn bộ thẻ (InkWell ripple effect)
class HomeAiSection extends StatelessWidget {
  const HomeAiSection({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Row(
        children: [
          // Thẻ 1: Thử móng AR 3D (Snapshot Try-On)
          Expanded(
            child: _buildGlassAiCard(
              context: context,
              icon: Icons.view_in_ar_rounded,
              iconGradient: const [Color(0xFFFF4B72), Color(0xFFFF7E53)],
              tagText: 'HOT',
              tagBgColor: const Color(0xFFFF4B72),
              title: 'Thử móng AR',
              subtitle: 'Trải nghiệm móng 3D',
              onTap: () => context.push('/snapshot-try-on'),
            ),
          ),

          const SizedBox(width: 12),

          // Thẻ 2: AI Match Style (Style Quiz)
          Expanded(
            child: _buildGlassAiCard(
              context: context,
              icon: Icons.palette_outlined,
              iconGradient: const [Color(0xFFE02B6D), Color(0xFFFF66C4)],
              tagText: 'GỢI Ý',
              tagBgColor: const Color(0xFFE02B6D),
              title: 'AI Match Style',
              subtitle: 'Gợi ý phong cách',
              onTap: () => context.push('/quiz'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGlassAiCard({
    required BuildContext context,
    required IconData icon,
    required List<Color> iconGradient,
    required String tagText,
    required Color tagBgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            spreadRadius: 1,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Material(
            color: Colors.white.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(20),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              splashColor: tagBgColor.withValues(alpha: 0.15),
              highlightColor: tagBgColor.withValues(alpha: 0.08),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: const Color(0xFFFFE3ED),
                    width: 1.2,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Icon + Tag nhỏ ở góc phải
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: iconGradient,
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: iconGradient.first.withValues(
                                  alpha: 0.3,
                                ),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Icon(icon, color: Colors.white, size: 20),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: tagBgColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: tagBgColor.withValues(alpha: 0.3),
                              width: 0.8,
                            ),
                          ),
                          child: Text(
                            tagText,
                            style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: tagBgColor,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    // Tiêu đề chính
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),

                    // Phụ đề mô tả ngắn
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 10,
                          color: tagBgColor.withValues(alpha: 0.7),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
