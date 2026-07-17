import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/profile_data.dart';
import '../widgets/favorite_color_section.dart';
import '../widgets/main_style_section.dart';
import '../widgets/occasions_section.dart';
import '../widgets/personal_notes_section.dart';
import '../widgets/personality_style_section.dart';
import '../widgets/profile_footer_actions.dart';
import '../widgets/profile_header_card.dart';

class UpdateProfilePage extends StatefulWidget {
  const UpdateProfilePage({super.key});

  @override
  State<UpdateProfilePage> createState() => _UpdateProfilePageState();
}

class _UpdateProfilePageState extends State<UpdateProfilePage> {
  late Set<String> _selectedPersonalities;
  late Set<String> _selectedColors;
  late Set<String> _selectedOccasions;
  late String _selectedMainStyle;
  late final Map<String, TextEditingController> _noteControllers;

  @override
  void initState() {
    super.initState();
    _selectedPersonalities =
        Set<String>.from(ProfileMockData.initialSelectedPersonalities);
    _selectedColors = Set<String>.from(ProfileMockData.initialSelectedColors);
    _selectedOccasions =
        Set<String>.from(ProfileMockData.initialSelectedOccasions);
    _selectedMainStyle = ProfileMockData.initialMainStyleId;
    _noteControllers = {
      for (final note in ProfileMockData.personalNotes)
        note.title: TextEditingController(text: note.content ?? ''),
    };
  }

  @override
  void dispose() {
    for (final controller in _noteControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _togglePersonality(String id) {
    setState(() {
      if (_selectedPersonalities.contains(id)) {
        _selectedPersonalities.remove(id);
      } else if (_selectedPersonalities.length <
          ProfileMockData.maxPersonalitySelections) {
        _selectedPersonalities.add(id);
      }
    });
  }

  void _toggleColor(String id) {
    setState(() {
      if (_selectedColors.contains(id)) {
        _selectedColors.remove(id);
      } else {
        _selectedColors.add(id);
      }
    });
  }

  void _toggleOccasion(String id) {
    setState(() {
      if (_selectedOccasions.contains(id)) {
        _selectedOccasions.remove(id);
      } else {
        _selectedOccasions.add(id);
      }
    });
  }

  void _onSave() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Profile updated successfully.')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
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
                Row(
                  children: [
                    IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                      color: AppColors.textPrimary,
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Edit profile',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ProfileHeaderCard(user: ProfileMockData.user),
                const SizedBox(height: 20),
                PersonalityStyleSection(
                  options: ProfileMockData.personalityOptions,
                  selectedIds: _selectedPersonalities,
                  maxSelections: ProfileMockData.maxPersonalitySelections,
                  onToggle: _togglePersonality,
                ),
                const SizedBox(height: 16),
                FavoriteColorSection(
                  swatches: ProfileMockData.colorSwatches,
                  selectedIds: _selectedColors,
                  onToggle: _toggleColor,
                ),
                const SizedBox(height: 16),
                MainStyleSection(
                  options: ProfileMockData.mainStyles,
                  selectedId: _selectedMainStyle,
                  onSelected: (id) => setState(() => _selectedMainStyle = id),
                ),
                const SizedBox(height: 16),
                OccasionsSection(
                  options: ProfileMockData.occasions,
                  selectedIds: _selectedOccasions,
                  onToggle: _toggleOccasion,
                ),
                const SizedBox(height: 16),
                PersonalNotesSection(
                  notes: ProfileMockData.personalNotes,
                  controllers: _noteControllers,
                ),
                const SizedBox(height: 24),
                ProfileEditActions(onSave: _onSave),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
