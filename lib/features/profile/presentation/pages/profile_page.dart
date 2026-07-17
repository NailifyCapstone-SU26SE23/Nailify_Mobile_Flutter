import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/profile_data.dart';
import '../widgets/profile_footer_actions.dart';
import '../widgets/profile_header_card.dart';
import '../widgets/profile_section_card.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final personalities = ProfileMockData.personalityOptions
        .where((o) => ProfileMockData.initialSelectedPersonalities.contains(o.id))
        .toList();
    final colors = ProfileMockData.colorSwatches
        .where((s) => ProfileMockData.initialSelectedColors.contains(s.id))
        .toList();
    final mainStyle = ProfileMockData.mainStyles.firstWhere(
      (s) => s.id == ProfileMockData.initialMainStyleId,
    );
    final occasions = ProfileMockData.occasions
        .where((o) => ProfileMockData.initialSelectedOccasions.contains(o.id))
        .toList();

    return Container(
      color: AppColors.surfaceLight,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 402),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ProfileHeaderCard(
                  user: ProfileMockData.user,
                  onEdit: () => context.push('/profile/edit'),
                ),
                const SizedBox(height: 20),
                ProfileSectionCard(
                  title: 'Personality & Style',
                  subtitle: '${personalities.length} traits selected',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: personalities
                        .map(
                          (item) => _ProfileChip(
                            label: item.title,
                            description: item.description,
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                ProfileSectionCard(
                  title: 'Favorite colors',
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: colors.map(_ColorPreview.new).toList(),
                  ),
                ),
                const SizedBox(height: 16),
                ProfileSectionCard(
                  title: 'Main style',
                  child: _MainStylePreview(style: mainStyle),
                ),
                const SizedBox(height: 16),
                ProfileSectionCard(
                  title: 'Occasions for frequent use',
                  subtitle: '${occasions.length} selected',
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: occasions
                        .map((o) => _ProfileTag(label: o.label))
                        .toList(),
                  ),
                ),
                const SizedBox(height: 16),
                ProfileSectionCard(
                  title: 'Personal notes',
                  child: Column(
                    children: ProfileMockData.personalNotes
                        .where((note) =>
                            note.content != null && note.content!.isNotEmpty)
                        .map(
                          (note) => Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: _NotePreview(
                              title: note.title,
                              content: note.content!,
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
                const SizedBox(height: 24),
                const ProfileViewActions(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileChip extends StatelessWidget {
  final String label;
  final String description;

  const _ProfileChip({required this.label, required this.description});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            description,
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _ColorPreview extends StatelessWidget {
  final ColorSwatchOption swatch;

  const _ColorPreview(this.swatch);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 56,
      height: 56,
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
        border: Border.all(color: AppColors.primary, width: 2),
      ),
    );
  }
}

class _MainStylePreview extends StatelessWidget {
  final MainStyleOption style;

  const _MainStylePreview({required this.style});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary),
      ),
      child: Row(
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: style.dotColor,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              style.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Text(
              style.tag,
              style: TextStyle(
                fontSize: 10,
                color: AppColors.primary.withOpacity(0.8),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileTag extends StatelessWidget {
  final String label;

  const _ProfileTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        gradient: AppColors.bannerGradient,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _NotePreview extends StatelessWidget {
  final String title;
  final String content;

  const _NotePreview({required this.title, required this.content});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.5,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.15)),
          ),
          child: Text(
            content,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textPrimary,
              height: 1.45,
            ),
          ),
        ),
      ],
    );
  }
}
