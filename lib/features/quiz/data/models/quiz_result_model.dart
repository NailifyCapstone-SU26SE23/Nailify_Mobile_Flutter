class MatchedCharacteristic {
  final String category;
  final String value;
  final String label;
  final bool isMatchingPreference;
  final String? description;

  const MatchedCharacteristic({
    required this.category,
    required this.value,
    required this.label,
    required this.isMatchingPreference,
    this.description,
  });

  factory MatchedCharacteristic.fromJson(Map<String, dynamic> json) {
    return MatchedCharacteristic(
      category: json['category'] as String? ?? '',
      value: json['value'] as String? ?? '',
      label: json['label'] as String? ?? '',
      isMatchingPreference: json['isMatchingPreference'] as bool? ?? false,
      description: json['description'] as String?,
    );
  }
}

class QuizResultModel {
  final String nailVariantId;
  final String nailDesignId;
  final String name;
  final String imageUrl;
  final double price;
  final int duration;
  final double score;
  final List<String> reasons;
  final List<MatchedCharacteristic> matchedCharacteristics;

  const QuizResultModel({
    required this.nailVariantId,
    required this.nailDesignId,
    required this.name,
    required this.imageUrl,
    required this.price,
    required this.duration,
    required this.score,
    required this.reasons,
    required this.matchedCharacteristics,
  });

  factory QuizResultModel.fromJson(Map<String, dynamic> json) {
    return QuizResultModel(
      nailVariantId: json['nailVariantId']?.toString() ?? '',
      nailDesignId: json['nailDesignId']?.toString() ?? '',
      name: json['name'] as String? ?? '',
      imageUrl: json['imageUrl'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      duration: (json['duration'] as num?)?.toInt() ?? 0,
      score: (json['score'] as num?)?.toDouble() ?? 0.0,
      reasons:
          (json['reasons'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      matchedCharacteristics:
          (json['matchedCharacteristics'] as List<dynamic>?)
              ?.map(
                (e) => MatchedCharacteristic.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [],
    );
  }
}
