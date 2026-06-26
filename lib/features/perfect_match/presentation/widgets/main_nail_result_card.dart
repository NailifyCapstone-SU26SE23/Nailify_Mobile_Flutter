import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/perfect_match_mock_data.dart';
import 'gradient_action_button.dart';

class MainNailResultCard extends StatelessWidget {
  final NailRecommendation result;
  final VoidCallback? onBookPressed;
  final VoidCallback? onTryAnotherAnalysis;

  const MainNailResultCard({
    super.key,
    required this.result,
    this.onBookPressed,
    this.onTryAnotherAnalysis,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            child: Image.asset(
              result.image,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Container(
                height: 200,
                color: AppColors.surfaceLight,
                child: const Icon(Icons.image, size: 48, color: AppColors.textSecondary),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Text(
                  '"${result.title}"',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  result.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),
                GradientActionButton(
                  label: 'Book this look',
                  width: double.infinity,
                  onPressed: onBookPressed,
                ),
                const SizedBox(height: 12),
                GestureDetector(
                  onTap: onTryAnotherAnalysis,
                  child: const Text(
                    'Try another analysis',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
