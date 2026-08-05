import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n.dart';

class OurPromisePage extends StatelessWidget {
  const OurPromisePage({
    super.key,
  }); // hoặc const OurPromiseSection({Key? key}) : super(key: key);

  @override
  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(
        0xFFFCFCFC,
      ), // Nền xám/beige siêu nhẹ để tạo nhịp điệu tương phản
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 48.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(
                Icons.star_rounded,
                color: AppColors.primary,
                size: 16,
              ),
              const SizedBox(width: 6),
              Text(
                S.of(context).ourPromiseTitle,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 2.0,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context).ourPromiseHeading,
            style: const TextStyle(
              color: AppColors.textPrimary,
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            S.of(context).ourPromiseSubtitle,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 28),

          // --- Phần Danh sách Card ---
          _buildPromiseCard(
            icon: Icons.access_time_rounded,
            title: S.of(context).ourPromiseExpTitle,
            description: S.of(context).ourPromiseExpDesc,
          ),
          const SizedBox(height: 16),
          _buildPromiseCard(
            icon: Icons.people_outline_rounded,
            title: S.of(context).ourPromiseTechTitle,
            description: S.of(context).ourPromiseTechDesc,
          ),
          const SizedBox(height: 16),
          _buildPromiseCard(
            icon: Icons.star_border_rounded,
            title: S.of(context).ourPromiseQualityTitle,
            description: S.of(context).ourPromiseQualityDesc,
          ),
          const SizedBox(height: 16),
          _buildPromiseCard(
            icon: Icons.trending_up_rounded,
            title: S.of(context).ourPromiseTrendTitle,
            description: S.of(context).ourPromiseTrendDesc,
          ),
        ],
      ),
    );
  }

  Widget _buildPromiseCard({
    required IconData icon,
    required String title,
    required String description,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFF0F5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Icon container màu hồng nhạt, icon hồng đậm
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5), // primarySurface
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.12),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(icon, color: AppColors.primary, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
