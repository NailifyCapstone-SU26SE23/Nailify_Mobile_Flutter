import 'package:flutter/material.dart';

enum DiscoverMatchTier { exclusive, highlySuitable, explore }

class DiscoverNailItem {
  final String id;
  final String name;
  final String image;
  final double matchPercent;
  final List<String> tags;
  final DiscoverMatchTier tier;
  final Set<String> personalityIds;
  final Set<String> colorIds;
  final String nailShape;
  final Set<String> occasionIds;

  const DiscoverNailItem({
    required this.id,
    required this.name,
    required this.image,
    required this.matchPercent,
    this.tags = const [],
    required this.tier,
    this.personalityIds = const {},
    this.colorIds = const {},
    this.nailShape = 'oval',
    this.occasionIds = const {},
  });

  Map<String, dynamic> toNailData() => {
        'id': id,
        'name': name,
        'image': image,
        'tags': tags,
      };
}

class DiscoverPersonalityFilter {
  final String id;
  final String label;
  final int count;

  const DiscoverPersonalityFilter({
    required this.id,
    required this.label,
    required this.count,
  });
}

class DiscoverColorFilter {
  final String id;
  final Color? color;
  final List<Color>? gradientColors;

  const DiscoverColorFilter({
    required this.id,
    this.color,
    this.gradientColors,
  });
}

class DiscoverShapeFilter {
  final String id;
  final String label;

  const DiscoverShapeFilter({required this.id, required this.label});
}

class DiscoverOccasionFilter {
  final String id;
  final String label;

  const DiscoverOccasionFilter({required this.id, required this.label});
}

class DiscoverMockData {
  static const String userName = 'Thu Huong';
  static const String personalitySummary = 'Gentle · Elegant · Creative';
  static const int totalMatchingStyles = 42;

  static const List<DiscoverNailItem> allDesigns = [
    DiscoverNailItem(
      id: 'd1',
      name: 'Marshmallow',
      image: 'assets/images/image 1.png',
      matchPercent: 98,
      tier: DiscoverMatchTier.exclusive,
      personalityIds: {'gentle_cute', 'elegant'},
      colorIds: {'pink', 'cream'},
      nailShape: 'oval',
      occasionIds: {'work', 'date'},
    ),
    DiscoverNailItem(
      id: 'd2',
      name: 'Candy Bloom',
      image: 'assets/images/Rectangle 1.png',
      matchPercent: 95,
      tier: DiscoverMatchTier.exclusive,
      personalityIds: {'gentle_cute', 'creativity'},
      colorIds: {'lavender', 'rose'},
      nailShape: 'almond',
      occasionIds: {'party', 'photos'},
    ),
    DiscoverNailItem(
      id: 'd3',
      name: 'Galaxy',
      image: 'assets/images/image 2.png',
      matchPercent: 82,
      tier: DiscoverMatchTier.highlySuitable,
      personalityIds: {'creativity', 'personality'},
      colorIds: {'purple', 'sky'},
      nailShape: 'coffin',
      occasionIds: {'party'},
    ),
    DiscoverNailItem(
      id: 'd4',
      name: 'Ruby',
      image: 'assets/images/image 3.png',
      matchPercent: 78,
      tier: DiscoverMatchTier.highlySuitable,
      personalityIds: {'elegant', 'professional'},
      colorIds: {'mint', 'grey'},
      nailShape: 'oval',
      occasionIds: {'work'},
    ),
    DiscoverNailItem(
      id: 'd5',
      name: 'Blossom Spring',
      image: 'assets/images/image 4.png',
      matchPercent: 72,
      tags: ['Floral', 'Minimal', 'Romantic'],
      tier: DiscoverMatchTier.explore,
      personalityIds: {'gentle_cute', 'natural'},
      colorIds: {'pink', 'cream'},
      nailShape: 'almond',
      occasionIds: {'wedding', 'travel'},
    ),
    DiscoverNailItem(
      id: 'd6',
      name: 'Pearl White',
      image: 'assets/images/pink 1.png',
      matchPercent: 68,
      tags: ['Elegant', 'Classic', 'Shine'],
      tier: DiscoverMatchTier.explore,
      personalityIds: {'elegant', 'professional'},
      colorIds: {'cream', 'grey'},
      nailShape: 'square',
      occasionIds: {'work', 'wedding'},
    ),
  ];

  static const List<DiscoverPersonalityFilter> personalityFilters = [
    DiscoverPersonalityFilter(id: 'gentle_cute', label: 'Gentle & Cute', count: 24),
    DiscoverPersonalityFilter(id: 'elegant', label: 'Elegant & Sophisticated', count: 18),
    DiscoverPersonalityFilter(id: 'personality', label: 'Personality & Strength', count: 15),
    DiscoverPersonalityFilter(id: 'creativity', label: 'Creativity & Art', count: 20),
    DiscoverPersonalityFilter(id: 'natural', label: 'Natural & Organic', count: 12),
    DiscoverPersonalityFilter(id: 'party', label: 'Featured & Party', count: 16),
    DiscoverPersonalityFilter(id: 'professional', label: 'Professional', count: 10),
  ];

  static const List<DiscoverColorFilter> colorFilters = [
    DiscoverColorFilter(
      id: 'sunset',
      gradientColors: [Color(0xFFFFB74D), Color(0xFFF06292)],
    ),
    DiscoverColorFilter(id: 'pink', color: Color(0xFFF8BBD0)),
    DiscoverColorFilter(id: 'beige', color: Color(0xFFD7CCC8)),
    DiscoverColorFilter(
      id: 'purple',
      gradientColors: [Color(0xFF6A1B9A), Color(0xFF4A148C)],
    ),
    DiscoverColorFilter(id: 'lavender', color: Color(0xFFCE93D8)),
    DiscoverColorFilter(
      id: 'rose_grad',
      gradientColors: [Color(0xFFFCE4EC), Color(0xFFF06292)],
    ),
    DiscoverColorFilter(id: 'sky', color: Color(0xFF90CAF9)),
    DiscoverColorFilter(id: 'rose', color: Color(0xFFF06292)),
    DiscoverColorFilter(id: 'grey', color: Color(0xFFE0E0E0)),
    DiscoverColorFilter(id: 'yellow', color: Color(0xFFFFDE59)),
  ];

  static const List<DiscoverShapeFilter> shapeFilters = [
    DiscoverShapeFilter(id: 'oval', label: 'Oval'),
    DiscoverShapeFilter(id: 'almond', label: 'Almond'),
    DiscoverShapeFilter(id: 'square', label: 'Square'),
    DiscoverShapeFilter(id: 'coffin', label: 'Coffin'),
    DiscoverShapeFilter(id: 'stiletto', label: 'Stiletto'),
    DiscoverShapeFilter(id: 'round', label: 'Round'),
  ];

  static const List<DiscoverOccasionFilter> occasionFilters = [
    DiscoverOccasionFilter(id: 'work', label: 'Go to work'),
    DiscoverOccasionFilter(id: 'party', label: 'Party / event'),
    DiscoverOccasionFilter(id: 'wedding', label: 'Wedding'),
    DiscoverOccasionFilter(id: 'photos', label: 'Take a photo'),
    DiscoverOccasionFilter(id: 'travel', label: 'Tourism'),
    DiscoverOccasionFilter(id: 'date', label: 'Date night'),
  ];

  static Set<String> initialPersonalities = {
    'gentle_cute',
    'elegant',
    'creativity',
  };

  static Set<String> initialColors = {'pink', 'rose_grad'};

  static const String initialShape = 'oval';

  static Set<String> initialOccasions = {'work', 'party'};

  static List<DiscoverNailItem> filterDesigns({
    required List<DiscoverNailItem> designs,
    required Set<String> personalities,
    required Set<String> colors,
    required String shape,
    required Set<String> occasions,
  }) {
    return designs.where((item) {
      if (personalities.isNotEmpty &&
          !item.personalityIds.any(personalities.contains)) {
        return false;
      }
      if (colors.isNotEmpty && !item.colorIds.any(colors.contains)) {
        return false;
      }
      if (shape.isNotEmpty && item.nailShape != shape) {
        return false;
      }
      if (occasions.isNotEmpty &&
          !item.occasionIds.any(occasions.contains)) {
        return false;
      }
      return true;
    }).toList();
  }
}
