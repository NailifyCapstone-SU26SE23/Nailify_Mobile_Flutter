enum DiscoverMatchTier { exclusive, highlySuitable, explore }

class DiscoverNailItem {
  final String id;
  final String name;
  final String image;
  final double matchPercent;
  final List<String> tags;
  final DiscoverMatchTier tier;
  final Set<String> categoryIds;
  final Set<String> styleIds;
  final Set<String> themeIds;
  final Set<String> designIds;
  final Set<String> variantIds;
  final Set<String> detailIds;
  final Set<String> elementIds;
  final Set<String> occasionIds;

  const DiscoverNailItem({
    required this.id,
    required this.name,
    required this.image,
    required this.matchPercent,
    this.tags = const [],
    required this.tier,
    this.categoryIds = const {},
    this.styleIds = const {},
    this.themeIds = const {},
    this.designIds = const {},
    this.variantIds = const {},
    this.detailIds = const {},
    this.elementIds = const {},
    this.occasionIds = const {},
  });

  Map<String, dynamic> toNailData() => {
        'id': id,
        'name': name,
        'image': image,
        'tags': tags,
      };
}

class DiscoverFilterOption {
  final String id;
  final String label;
  final int count;

  const DiscoverFilterOption({
    required this.id,
    required this.label,
    this.count = 0,
  });
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
      categoryIds: {'classic', 'casual'},
      styleIds: {'minimalist', 'kbeauty'},
      themeIds: {'floral', 'pastel'},
      designIds: {'french', 'solid'},
      variantIds: {'oval', 'short'},
      detailIds: {'matte'},
      elementIds: {'flowers'},
      occasionIds: {'work', 'date'},
    ),
    DiscoverNailItem(
      id: 'd2',
      name: 'Candy Bloom',
      image: 'assets/images/Rectangle 1.png',
      matchPercent: 95,
      tier: DiscoverMatchTier.exclusive,
      categoryIds: {'artistic', 'seasonal'},
      styleIds: {'kbeauty', 'maximalist'},
      themeIds: {'floral', 'spring'},
      designIds: {'gradient', 'hand_painted'},
      variantIds: {'almond', 'medium'},
      detailIds: {'glitter', 'hand_painted'},
      elementIds: {'flowers', 'hearts'},
      occasionIds: {'party', 'photos'},
    ),
    DiscoverNailItem(
      id: 'd3',
      name: 'Galaxy',
      image: 'assets/images/image 2.png',
      matchPercent: 82,
      tier: DiscoverMatchTier.highlySuitable,
      categoryIds: {'modern', 'artistic'},
      styleIds: {'maximalist', 'gothic'},
      themeIds: {'galaxy', 'abstract'},
      designIds: {'ombre', 'marble'},
      variantIds: {'coffin', 'long'},
      detailIds: {'chrome', 'foil'},
      elementIds: {'stars'},
      occasionIds: {'party'},
    ),
    DiscoverNailItem(
      id: 'd4',
      name: 'Ruby',
      image: 'assets/images/image 3.png',
      matchPercent: 78,
      tier: DiscoverMatchTier.highlySuitable,
      categoryIds: {'classic', 'bridal'},
      styleIds: {'minimalist', 'elegant'},
      themeIds: {'nature', 'pastel'},
      designIds: {'solid', 'french'},
      variantIds: {'oval', 'medium'},
      detailIds: {'glossy'},
      elementIds: {'pearls'},
      occasionIds: {'work'},
    ),
    DiscoverNailItem(
      id: 'd5',
      name: 'Blossom Spring',
      image: 'assets/images/image 4.png',
      matchPercent: 72,
      tags: ['Floral', 'Minimal', 'Romantic'],
      tier: DiscoverMatchTier.explore,
      categoryIds: {'seasonal', 'casual'},
      styleIds: {'kbeauty', 'vintage'},
      themeIds: {'floral', 'spring'},
      designIds: {'hand_painted', 'gradient'},
      variantIds: {'almond', 'medium'},
      detailIds: {'hand_painted', 'matte'},
      elementIds: {'flowers', 'butterflies'},
      occasionIds: {'wedding', 'travel'},
    ),
    DiscoverNailItem(
      id: 'd6',
      name: 'Pearl White',
      image: 'assets/images/pink 1.png',
      matchPercent: 68,
      tags: ['Elegant', 'Classic', 'Shine'],
      tier: DiscoverMatchTier.explore,
      categoryIds: {'classic', 'bridal'},
      styleIds: {'elegant', 'minimalist'},
      themeIds: {'pastel', 'nature'},
      designIds: {'french', 'solid'},
      variantIds: {'square', 'short'},
      detailIds: {'glossy', 'rhinestone'},
      elementIds: {'pearls', 'lace'},
      occasionIds: {'work', 'wedding'},
    ),
  ];

  static const List<DiscoverFilterOption> occasionFilters = [
    DiscoverFilterOption(id: 'work', label: 'Go to work'),
    DiscoverFilterOption(id: 'party', label: 'Party / event'),
    DiscoverFilterOption(id: 'wedding', label: 'Wedding'),
    DiscoverFilterOption(id: 'photos', label: 'Take a photo'),
    DiscoverFilterOption(id: 'travel', label: 'Tourism'),
    DiscoverFilterOption(id: 'date', label: 'Date night'),
  ];

  static const List<DiscoverFilterOption> categoryFilters = [
    DiscoverFilterOption(id: 'classic', label: 'Classic', count: 18),
    DiscoverFilterOption(id: 'modern', label: 'Modern', count: 14),
    DiscoverFilterOption(id: 'artistic', label: 'Artistic', count: 22),
    DiscoverFilterOption(id: 'seasonal', label: 'Seasonal', count: 12),
    DiscoverFilterOption(id: 'bridal', label: 'Bridal', count: 9),
    DiscoverFilterOption(id: 'casual', label: 'Casual', count: 16),
  ];

  static const List<DiscoverFilterOption> styleFilters = [
    DiscoverFilterOption(id: 'minimalist', label: 'Minimalist', count: 20),
    DiscoverFilterOption(id: 'kbeauty', label: 'K-Beauty', count: 24),
    DiscoverFilterOption(id: 'maximalist', label: 'Maximalist', count: 15),
    DiscoverFilterOption(id: 'vintage', label: 'Vintage', count: 11),
    DiscoverFilterOption(id: 'elegant', label: 'Elegant', count: 17),
    DiscoverFilterOption(id: 'gothic', label: 'Gothic', count: 8),
  ];

  static const List<DiscoverFilterOption> themeFilters = [
    DiscoverFilterOption(id: 'floral', label: 'Floral', count: 26),
    DiscoverFilterOption(id: 'pastel', label: 'Pastel', count: 19),
    DiscoverFilterOption(id: 'galaxy', label: 'Galaxy', count: 10),
    DiscoverFilterOption(id: 'abstract', label: 'Abstract', count: 13),
    DiscoverFilterOption(id: 'nature', label: 'Nature', count: 14),
    DiscoverFilterOption(id: 'spring', label: 'Spring', count: 12),
  ];

  static const List<DiscoverFilterOption> designFilters = [
    DiscoverFilterOption(id: 'french', label: 'French Tip', count: 16),
    DiscoverFilterOption(id: 'ombre', label: 'Ombre', count: 14),
    DiscoverFilterOption(id: 'marble', label: 'Marble', count: 9),
    DiscoverFilterOption(id: 'solid', label: 'Solid Color', count: 22),
    DiscoverFilterOption(id: 'gradient', label: 'Gradient', count: 18),
    DiscoverFilterOption(id: 'hand_painted', label: 'Hand-painted', count: 11),
  ];

  static const List<DiscoverFilterOption> variantFilters = [
    DiscoverFilterOption(id: 'oval', label: 'Oval', count: 20),
    DiscoverFilterOption(id: 'almond', label: 'Almond', count: 16),
    DiscoverFilterOption(id: 'square', label: 'Square', count: 12),
    DiscoverFilterOption(id: 'coffin', label: 'Coffin', count: 10),
    DiscoverFilterOption(id: 'short', label: 'Short Length', count: 18),
    DiscoverFilterOption(id: 'medium', label: 'Medium Length', count: 15),
    DiscoverFilterOption(id: 'long', label: 'Long Length', count: 8),
  ];

  static const List<DiscoverFilterOption> detailFilters = [
    DiscoverFilterOption(id: 'matte', label: 'Matte Finish', count: 14),
    DiscoverFilterOption(id: 'glossy', label: 'Glossy Finish', count: 20),
    DiscoverFilterOption(id: 'glitter', label: 'Glitter', count: 16),
    DiscoverFilterOption(id: 'foil', label: 'Foil', count: 9),
    DiscoverFilterOption(id: 'chrome', label: 'Chrome', count: 7),
    DiscoverFilterOption(id: 'rhinestone', label: 'Rhinestone', count: 12),
    DiscoverFilterOption(id: 'hand_painted', label: 'Hand-painted Detail', count: 11),
  ];

  static const List<DiscoverFilterOption> elementFilters = [
    DiscoverFilterOption(id: 'flowers', label: 'Flowers', count: 22),
    DiscoverFilterOption(id: 'hearts', label: 'Hearts', count: 14),
    DiscoverFilterOption(id: 'stars', label: 'Stars', count: 10),
    DiscoverFilterOption(id: 'butterflies', label: 'Butterflies', count: 8),
    DiscoverFilterOption(id: 'pearls', label: 'Pearls', count: 13),
    DiscoverFilterOption(id: 'lace', label: 'Lace', count: 6),
  ];

  static Set<String> initialCategories = {'classic', 'artistic'};
  static Set<String> initialStyles = {'kbeauty', 'minimalist'};
  static Set<String> initialThemes = {'floral', 'pastel'};
  static Set<String> initialDesigns = {'french', 'gradient'};
  static Set<String> initialVariants = {'oval'};
  static Set<String> initialDetails = {'matte', 'glossy'};
  static Set<String> initialElements = {'flowers'};
  static Set<String> initialOccasions = {'work', 'party'};

  static List<DiscoverNailItem> filterDesigns({
    required List<DiscoverNailItem> designs,
    required Set<String> categories,
    required Set<String> styles,
    required Set<String> themes,
    required Set<String> selectedDesigns,
    required Set<String> variants,
    required Set<String> details,
    required Set<String> elements,
    required Set<String> occasions,
  }) {
    return designs.where((item) {
      if (categories.isNotEmpty &&
          !item.categoryIds.any(categories.contains)) {
        return false;
      }
      if (styles.isNotEmpty && !item.styleIds.any(styles.contains)) {
        return false;
      }
      if (themes.isNotEmpty && !item.themeIds.any(themes.contains)) {
        return false;
      }
      if (selectedDesigns.isNotEmpty &&
          !item.designIds.any(selectedDesigns.contains)) {
        return false;
      }
      if (variants.isNotEmpty && !item.variantIds.any(variants.contains)) {
        return false;
      }
      if (details.isNotEmpty && !item.detailIds.any(details.contains)) {
        return false;
      }
      if (elements.isNotEmpty && !item.elementIds.any(elements.contains)) {
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
