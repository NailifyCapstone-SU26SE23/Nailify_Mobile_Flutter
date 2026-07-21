import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_response_parser.dart';
import '../models/quiz_question_model.dart';
import '../models/quiz_result_model.dart';

class QuizRepository {
  final ApiClient _apiClient;

  QuizRepository(this._apiClient);

  Future<List<QuizQuestionModel>> getQuizQuestions() async {
    final response = await _apiClient.get<dynamic>('/Quizzes/questions');
    final items = ApiResponseParser.unwrapList(response.data);
    return items.map(QuizQuestionModel.fromJson).toList();
  }

  Future<List<QuizResultModel>> getPersonalizedRecommendations() async {
    final response = await _apiClient.get<dynamic>('/Recommendations/for-me');
    final items = ApiResponseParser.unwrapList(response.data);
    return items.map(QuizResultModel.fromJson).toList();
  }

  Future<List<QuizResultModel>> submitQuiz(
      List<String> selectedOptionIds) async {
    final response = await _apiClient.post<dynamic>(
      '/Quizzes/submit',
      data: {'selectedOptionIds': selectedOptionIds},
    );
    final items = ApiResponseParser.unwrapList(response.data);
    return items.map(QuizResultModel.fromJson).toList();
  }
}
