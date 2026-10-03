import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/profile_data.dart';
import 'profile_section_card.dart';

class PersonalityStyleSection extends StatelessWidget {
  final List<PersonalityOption> options;
  final Set<String> selectedIds;
  final int maxSelections;
  final ValueChanged<String> onToggle;

  const PersonalityStyleSection({
    super.key,
    required this.options,
    required this.selectedIds,
    required this.maxSelections,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'Personality & Style',
      subtitle: 'Choose what best describes you.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${selectedIds.length}/$maxSelections selected',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Container(height: 1, color: AppColors.primary.withOpacity(0.3)),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.15,
            ),
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options[index];
              final isSelected = selectedIds.contains(option.id);
              return _PersonalityCard(
                option: option,
                isSelected: isSelected,
                onTap: () => onToggle(option.id),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _PersonalityCard extends StatelessWidget {
  final PersonalityOption option;
  final bool isSelected;
  final VoidCallback onTap;

  const _PersonalityCard({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.08)
              : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.borderLight,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.topRight,
              child: isSelected
                  ? Container(
                      width: 22,
                      height: 22,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: AppColors.bannerGradient,
                      ),
                      child: const Icon(
                        Icons.check,
                        size: 14,
                        color: Colors.white,
                      ),
                    )
                  : Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.primary),
                      ),
                    ),
            ),
            Text(
              option.title,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              option.description,
              style: TextStyle(
                fontSize: 11,
                color: isSelected
                    ? AppColors.primary.withOpacity(0.8)
                    : AppColors.textSecondary,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
