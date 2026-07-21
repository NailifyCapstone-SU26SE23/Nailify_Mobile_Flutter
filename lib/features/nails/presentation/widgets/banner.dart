import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

class QuizBanner extends StatelessWidget {
  const QuizBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.surface, size: 32),
          const SizedBox(height: 12),
          const Text(
            "If you haven't found a nail design that suits you yet, Bloom can help.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.surface, fontSize: 14, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.push('/quiz'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Take personality test', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 10),
          ElevatedButton(
            onPressed: () => context.push('/custom-nail'),
            // {
            //   ScaffoldMessenger.of(context).showSnackBar(
            //     const SnackBar(content: Text('Chức năng bài trắc nghiệm đang được phát triển.')),
            //   );
            // },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.surface,
              foregroundColor: AppColors.primary,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text('Customize your Nail', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}