import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class PersonalityHeader extends StatelessWidget {
  const PersonalityHeader({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'TAILORED FOR YOU',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.2,
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
              height: 1.3,
            ),
            children: [
              TextSpan(text: 'Your '),
              TextSpan(
                text: 'perfect match',
                style: TextStyle(
                  color: AppColors.primary,
                  fontStyle: FontStyle.italic,
                ),
              ),
              TextSpan(text: ' is here'),
            ],
          ),
        ),
      ],
    );
  }
}
