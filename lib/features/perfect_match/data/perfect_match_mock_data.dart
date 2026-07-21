class PersonalityResult {
  final String title;
  final String description;
  final List<String> attributes;

  const PersonalityResult({
    required this.title,
    required this.description,
    required this.attributes,
  });
}

class NailRecommendation {
  final String title;
  final String description;
  final String image;
  final List<String> tags;

  const NailRecommendation({
    required this.title,
    required this.description,
    required this.image,
    required this.tags,
  });
}

class PerfectMatchMockData {
  static const PersonalityResult personality = PersonalityResult(
    title: 'Soft Girl',
    description:
        'You love elegance, soft tones, and delicate beauty. Pink shades and gentle designs reflect your vibe best.',
    attributes: ['Medium', 'Squoval', 'Nude Pink', 'Gel Gloss'],
  );

  static const NailRecommendation mainResult = NailRecommendation(
    title: 'Soft Lady',
    description:
        'A delicate blend of minimalist elegance and feminine charm.',
    image: 'assets/images/Rectangle 1.png',
    tags: [],
  );

  static const List<NailRecommendation> recommendations = [
    NailRecommendation(
      title: 'Blossom Spring',
      description: '',
      image: 'assets/images/image 1.png',
      tags: ['Floral', 'Minimal', 'Romantic'],
    ),
    NailRecommendation(
      title: 'Pearl White',
      description: '',
      image: 'assets/images/image 2.png',
      tags: ['Elegant', 'Classic', 'Shine'],
    ),
  ];

  /// Maps quiz answers to a personality result (mock logic).
  static PersonalityResult resolveFromAnswers(Map<String, List<String>> answers) {
    if (answers.isEmpty) return personality;

    // Placeholder: always return default personality until API integration
    final dominant = answers.length % 4;
    switch (dominant) {
      case 0:
        return const PersonalityResult(
          title: 'Power Boss',
          description:
              'You value efficiency and strength. Clean lines and durable finishes match your confident energy.',
          attributes: ['Short', 'Square', 'Neutral', 'Gel Matte'],
        );
      case 1:
        return personality;
      case 2:
        return const PersonalityResult(
          title: 'Free Spirit',
          description:
              'You embrace creativity and individuality. Bold accents and unique designs express your personality.',
          attributes: ['Long', 'Coffin', 'Pastel Mix', 'Chrome'],
        );
      case 3:
        return const PersonalityResult(
          title: 'Pure Minimalist',
          description:
              'You appreciate simplicity and balance. Subtle nude tones and refined shapes suit you perfectly.',
          attributes: ['Medium', 'Almond', 'Nude Beige', 'Glossy'],
        );
      default:
        return personality;
    }
  }
}

