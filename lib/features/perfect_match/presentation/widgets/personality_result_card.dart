import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/perfect_match_mock_data.dart';

class PersonalityResultCard extends StatelessWidget {
  final PersonalityResult result;

  const PersonalityResultCard({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "We've unlocked your personality!",
            style: TextStyle(fontSize: 15, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              children: [
                const TextSpan(text: 'You are: '),
                TextSpan(
                  text: result.title,
                  style: const TextStyle(color: AppColors.primary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            result.description,
            style: const TextStyle(
              fontSize: 14,
              color: AppColors.textPrimary,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
