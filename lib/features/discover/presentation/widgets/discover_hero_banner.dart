import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class DiscoverHeroBanner extends StatelessWidget {
  const DiscoverHeroBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: AppColors.bannerGradient,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.auto_awesome,
                size: 14,
                color: Colors.white.withOpacity(0.9),
              ),
              const SizedBox(width: 6),
              Text(
                'NAIL PERSONALITY MATCH',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.4,
                  color: Colors.white.withOpacity(0.95),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Find the nail style\nthat suits you',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 26,
              fontFamily: 'serif',
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'We make suggestions based on your personality, style, and personal profile.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.92),
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
