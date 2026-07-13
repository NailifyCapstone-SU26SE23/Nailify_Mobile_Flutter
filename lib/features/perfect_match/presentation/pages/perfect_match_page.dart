import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/perfect_match_mock_data.dart';
import '../widgets/gradient_action_button.dart';
import '../widgets/main_nail_result_card.dart';
import '../widgets/personality_header.dart';
import '../widgets/personality_result_card.dart';
import '../widgets/style_attribute_tags.dart';
import '../widgets/you_may_also_like_section.dart';

class PerfectMatchPage extends StatelessWidget {
  final List<int> answers;

  const PerfectMatchPage({super.key, this.answers = const []});

  @override
  Widget build(BuildContext context) {
    final personality = PerfectMatchMockData.resolveFromAnswers(answers);

    return Container(
      color: AppColors.surfaceLight,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 402),
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Column(
              children: [
                const PersonalityHeader(),
                const SizedBox(height: 28),
                PersonalityResultCard(result: personality),
                const SizedBox(height: 20),
                StyleAttributeTags(attributes: personality.attributes),
                const SizedBox(height: 16),
                Align(
                  alignment: Alignment.centerRight,
                  child: GradientActionButton(
                    label: 'Edit',
                    onPressed: () => context.go('/quiz'),
                  ),
                ),
                const SizedBox(height: 36),
                MainNailResultCard(
                  result: PerfectMatchMockData.mainResult,
                  onBookPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Booking feature coming soon.'),
                      ),
                    );
                  },
                  onTryAnotherAnalysis: () => context.go('/quiz'),
                ),
                const SizedBox(height: 36),
                YouMayAlsoLikeSection(
                  recommendations: PerfectMatchMockData.recommendations,
                ),
                const SizedBox(height: 28),
                GradientActionButton(
                  label: 'Try another design',
                  width: double.infinity,
                  onPressed: () => context.go('/another-design'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
