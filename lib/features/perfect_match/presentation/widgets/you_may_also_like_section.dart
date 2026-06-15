import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/perfect_match_mock_data.dart';
import 'recommendation_card.dart';

class YouMayAlsoLikeSection extends StatelessWidget {
  final List<NailRecommendation> recommendations;

  const YouMayAlsoLikeSection({super.key, required this.recommendations});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Text(
          'You may also like',
          style: TextStyle(
            fontSize: 20,
            fontFamily: 'serif',
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 20),
        ...recommendations.map(
          (item) => RecommendationCard(recommendation: item),
        ),
      ],
    );
  }
}
