import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class DesignGalleryHeader extends StatelessWidget {
  const DesignGalleryHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'NAIL INSPIRATION GALLERY',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.4,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 12),
        RichText(
          textAlign: TextAlign.center,
          text: const TextSpan(
            style: TextStyle(
              fontSize: 26,
              fontFamily: 'serif',
              color: AppColors.textPrimary,
              height: 1.25,
            ),
            children: [
              TextSpan(text: 'Find your next\n'),
              TextSpan(
                text: 'signature look',
                style: TextStyle(
                  fontSize: 32,
                  fontStyle: FontStyle.italic,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        const Text(
          'Explore curated nail designs from classics to trends.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}
