import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/profile_data.dart';
import 'profile_section_card.dart';

class FavoriteColorSection extends StatelessWidget {
  final List<ColorSwatchOption> swatches;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  const FavoriteColorSection({
    super.key,
    required this.swatches,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'Favorite color',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'CHOOSE THE COLOR TONE YOU USUALLY CHOOSE.',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: swatches.map((swatch) {
              final isSelected = selectedIds.contains(swatch.id);
              return GestureDetector(
                onTap: () => onToggle(swatch.id),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: swatch.color,
                    gradient: swatch.gradientColors != null
                        ? LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: swatch.gradientColors!,
                          )
                        : null,
                    border: isSelected
                        ? Border.all(color: AppColors.primary, width: 3)
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
