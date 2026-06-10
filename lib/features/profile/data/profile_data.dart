import 'package:flutter/material.dart';

class ProfileUser {
  final String initials;
  final String fullName;
  final String memberSince;
  final String styleDescription;
  final List<String> interestTags;

  const ProfileUser({
    required this.initials,
    required this.fullName,
    required this.memberSince,
    required this.styleDescription,
    required this.interestTags,
  });
}

class PersonalityOption {
  final String id;
  final String title;
  final String description;

  const PersonalityOption({
    required this.id,
    required this.title,
    required this.description,
  });
}

class ColorSwatchOption {
  final String id;
  final Color? color;
  final List<Color>? gradientColors;

  const ColorSwatchOption({
    required this.id,
    this.color,
    this.gradientColors,
  });
}

class MainStyleOption {
  final String id;
  final String title;
  final Color dotColor;
  final String tag;

  const MainStyleOption({
    required this.id,
    required this.title,
    required this.dotColor,
    required this.tag,
  });
}

class OccasionOption {
  final String id;
  final String label;

  const OccasionOption({required this.id, required this.label});
}

class PersonalNoteItem {
  final String title;
  final String? content;
  final String? placeholder;
  final bool isMultiline;

  const PersonalNoteItem({
    required this.title,
    this.content,
    this.placeholder,
    this.isMultiline = false,
  });
}

class ProfileMockData {
  static const int maxPersonalitySelections = 8;

  static const ProfileUser user = ProfileUser(
    initials: 'TH',
    fullName: 'Thu Huong',
    memberSince: 'Member since March 2024',
    styleDescription: 'K-Beauty & Minimalist Style',
    interestTags: [
      'Lightly',
      'Romantic',
      'Luxurious',
      'Creative',
      'Personality',
    ],
  );

  static const List<PersonalityOption> personalityOptions = [
    PersonalityOption(
      id: 'gentle_cute',
      title: 'Gentle & Cute',
      description: 'Pastel, floral, soft tones',
    ),
    PersonalityOption(
      id: 'elegant',
      title: 'Elegant & Sophisticated',
      description: 'Nude, gold, minimalist',
    ),
    PersonalityOption(
      id: 'personality',
      title: 'Personality & Strength',
      description: 'Dark, bold, edgy',
    ),
    PersonalityOption(
      id: 'creativity',
      title: 'Creativity & Art',
      description: 'Dark, bold, edgy',
    ),
    PersonalityOption(
      id: 'professional',
      title: 'Professional & Courteous',
      description: 'Neutral, classic, subtle',
    ),
    PersonalityOption(
      id: 'natural',
      title: 'Natural & Organic',
      description: 'Dark, bold, edgy',
    ),
    PersonalityOption(
      id: 'party',
      title: 'Featured & Party',
      description: 'Dark, bold, edgy',
    ),
    PersonalityOption(
      id: 'minimal',
      title: 'Minimal & Clean',
      description: 'Simple lines, muted palette',
    ),
  ];

  static const Set<String> initialSelectedPersonalities = {
    'gentle_cute',
    'elegant',
    'professional',
    'natural',
  };

  static const List<ColorSwatchOption> colorSwatches = [
    ColorSwatchOption(id: 'pink', color: Color(0xFFF8BBD0)),
    ColorSwatchOption(id: 'beige', color: Color(0xFFD7CCC8)),
    ColorSwatchOption(
      id: 'purple',
      gradientColors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
    ),
    ColorSwatchOption(
      id: 'lavender',
      gradientColors: [Color(0xFFCE93D8), Color(0xFFBA68C8)],
    ),
    ColorSwatchOption(
      id: 'mint',
      gradientColors: [Color(0xFFA5D6A7), Color(0xFF81C784)],
    ),
    ColorSwatchOption(id: 'cream', color: Color(0xFFFFF8E1)),
    ColorSwatchOption(
      id: 'sky',
      gradientColors: [Color(0xFF90CAF9), Color(0xFF64B5F6)],
    ),
    ColorSwatchOption(
      id: 'rose',
      gradientColors: [Color(0xFFF06292), Color(0xFFE91E63)],
    ),
    ColorSwatchOption(
      id: 'grey',
      gradientColors: [Color(0xFFE0E0E0), Color(0xFFFAFAFA)],
    ),
    ColorSwatchOption(
      id: 'sunset',
      gradientColors: [Color(0xFFFFB74D), Color(0xFFF06292)],
    ),
  ];

  static const Set<String> initialSelectedColors = {'pink', 'mint', 'sunset'};

  static const List<MainStyleOption> mainStyles = [
    MainStyleOption(
      id: 'kbeauty',
      title: 'K-Beauty / Korean Nail',
      dotColor: Color(0xFFFF66C4),
      tag: 'Popular',
    ),
    MainStyleOption(
      id: 'minimalist',
      title: 'Minimalist Chic',
      dotColor: Color(0xFFD7CCC8),
      tag: 'Elegant',
    ),
    MainStyleOption(
      id: 'maximalist',
      title: 'Maximalist / Bold Art',
      dotColor: Color(0xFFE91E63),
      tag: 'Outstanding',
    ),
    MainStyleOption(
      id: 'dark',
      title: 'Dark & Moody',
      dotColor: Color(0xFF6A1B9A),
      tag: 'Personality',
    ),
    MainStyleOption(
      id: 'vintage',
      title: 'Vintage / Retro',
      dotColor: Color(0xFFFFDE59),
      tag: 'Nostalgic',
    ),
  ];

  static const String initialMainStyleId = 'kbeauty';

  static const List<OccasionOption> occasions = [
    OccasionOption(id: 'work', label: 'Go to work every day'),
    OccasionOption(id: 'party', label: 'Parties & events'),
    OccasionOption(id: 'wedding', label: 'Wedding'),
    OccasionOption(id: 'travel', label: 'Going out / traveling'),
    OccasionOption(id: 'photos', label: 'Take photos / content'),
    OccasionOption(id: 'graduate', label: 'Graduate'),
    OccasionOption(id: 'reward', label: 'Reward yourself'),
    OccasionOption(id: 'date', label: 'Date night'),
    OccasionOption(id: 'sport', label: 'Active / Sporty'),
    OccasionOption(id: 'perform', label: 'Perform'),
  ];

  static const Set<String> initialSelectedOccasions = {
    'work',
    'party',
    'photos',
  };

  static const List<PersonalNoteItem> personalNotes = [
    PersonalNoteItem(
      title: 'NAIL CONDITION',
      content:
          'Natural nails are quite thin, so a lightweight gel is usually chosen. I prefer medium-length, oval-shaped nails.',
    ),
    PersonalNoteItem(
      title: 'SPECIAL INTERESTS',
      content:
          'I like small floral patterns and minimalist designs. I don\'t like too much embellishment. I often choose pink and beige colors.',
    ),
    PersonalNoteItem(
      title: 'ALLERGY / TECHNICIAN\'S NOTE',
      placeholder: 'Ex: Sensitive to acrylic odor...',
      isMultiline: true,
    ),
  ];
}
