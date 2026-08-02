import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/profile_data.dart';
import 'profile_section_card.dart';

class PersonalNotesSection extends StatelessWidget {
  final List<PersonalNoteItem> notes;
  final Map<String, TextEditingController> controllers;
  final bool readOnly;

  const PersonalNotesSection({
    super.key,
    required this.notes,
    required this.controllers,
    this.readOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    return ProfileSectionCard(
      title: 'Personal notes',
      child: Column(
        children: notes.map((note) {
          final controller = controllers[note.title]!;
          return Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  note.title,
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  enabled: !readOnly,
                  maxLines: note.isMultiline ? 3 : null,
                  decoration: InputDecoration(
                    hintText: note.placeholder,
                    hintStyle: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.6),
                      fontSize: 13,
                    ),
                    filled: true,
                    fillColor: AppColors.primary.withOpacity(0.06),
                    contentPadding: const EdgeInsets.all(14),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: AppColors.primary.withOpacity(0.2),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: AppColors.primary),
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
