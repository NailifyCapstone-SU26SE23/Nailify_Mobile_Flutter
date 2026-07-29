import 'package:flutter/material.dart';

/// Stub widget for PersonalNotesSection
/// TODO: Implement full personal notes functionality
class PersonalNotesSection extends StatelessWidget {
  final List<dynamic> notes;
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
    return const SizedBox.shrink();
  }
}
