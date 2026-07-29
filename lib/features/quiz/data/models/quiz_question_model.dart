class QuizOptionModel {
  final String quizOptionId;
  final List<String> values;
  final String label;
  final String? description;

  const QuizOptionModel({
    required this.quizOptionId,
    required this.values,
    required this.label,
    this.description,
  });

  factory QuizOptionModel.fromJson(Map<String, dynamic> json) {
    return QuizOptionModel(
      quizOptionId: json['quizOptionId'] as String? ?? '',
      values:
          (json['values'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      label: json['label'] as String? ?? '',
      description: json['description'] as String?,
    );
  }
}

class QuizQuestionModel {
  final String quizQuestionId;
  final String questionText;
  final String type; // "single" | "multiple"
  final String categoryKey;
  final List<QuizOptionModel> options;

  const QuizQuestionModel({
    required this.quizQuestionId,
    required this.questionText,
    required this.type,
    required this.categoryKey,
    required this.options,
  });

  bool get isMultiple => type == 'multiple';

  factory QuizQuestionModel.fromJson(Map<String, dynamic> json) {
    return QuizQuestionModel(
      quizQuestionId: json['quizQuestionId'] as String? ?? '',
      questionText: json['questionText'] as String? ?? '',
      type: json['type'] as String? ?? 'single',
      categoryKey: json['categoryKey'] as String? ?? '',
      options:
          (json['options'] as List<dynamic>?)
              ?.map(
                (e) => QuizOptionModel.fromJson(
                  Map<String, dynamic>.from(e as Map),
                ),
              )
              .toList() ??
          [],
    );
  }
}
