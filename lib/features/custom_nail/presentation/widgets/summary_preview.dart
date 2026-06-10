import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SummaryPreview extends StatelessWidget {
  const SummaryPreview({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Image.asset(
          'assets/images/home-mid.jpg', // để cái ảnh cho vui vì tính năng chưa có
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(
            color: Colors.pink.shade50,
            child: const Icon(Icons.image, size: 48, color: AppColors.primary),
          ),
        ),
      ),
    );
  }
}