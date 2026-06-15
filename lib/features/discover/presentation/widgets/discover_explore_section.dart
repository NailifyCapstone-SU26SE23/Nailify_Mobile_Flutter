import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/discover_data.dart';
import 'discover_nail_card.dart';
import 'discover_section_header.dart';

class DiscoverExploreSection extends StatelessWidget {
  final DiscoverNailItem? featuredItem;

  const DiscoverExploreSection({super.key, this.featuredItem});

  @override
  Widget build(BuildContext context) {
    if (featuredItem == null) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const DiscoverSectionHeader(
          badge: 'DISCOVER',
          title: 'Try something new',
          subtitle: 'Different style',
          badgeColor: Color(0xFFFCE4EC),
        ),
        const SizedBox(height: 16),
        DiscoverNailCard(item: featuredItem!),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: () => context.go('/another-design'),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.textSecondary,
            side: const BorderSide(color: AppColors.borderLight),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('See more nail designs'),
              SizedBox(width: 6),
              Icon(Icons.arrow_forward, size: 16),
            ],
          ),
        ),
      ],
    );
  }
}
