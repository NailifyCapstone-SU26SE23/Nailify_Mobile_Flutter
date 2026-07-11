import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/profile_data.dart';
import 'profile_section_card.dart';

class OccasionsSection extends StatelessWidget {
  final List<OccasionOption> options;
  final Set<String> selectedIds;
  final ValueChanged<String> onToggle;

  const OccasionsSection({
    super.key,
    required this.options,
    required this.selectedIds,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'Occasions for frequent use',
      subtitle: 'Select multiple answers',
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: options.map((option) {
          final isSelected = selectedIds.contains(option.id);
          return GestureDetector(
            onTap: () => onToggle(option.id),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                gradient: isSelected ? AppColors.bannerGradient : null,
                color: isSelected ? null : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected
                      ? Colors.transparent
                      : AppColors.borderLight,
                ),
              ),
              child: Text(
                option.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected ? Colors.white : AppColors.textSecondary,
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
