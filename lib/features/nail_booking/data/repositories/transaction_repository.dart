import '../../../../core/network/api_client.dart';
import '../../../../core/utils/api_response_parser.dart';
import '../../../../core/utils/paginated_response.dart';

class TransactionRepository {
  final ApiClient _apiClient;

  TransactionRepository(this._apiClient);

  Future<PaginatedResponse<Map<String, dynamic>>> getMyTransactions({
    required int page,
    int pageSize = 5,
    DateTime? startDate,
    DateTime? endDate,
    String? status,
  }) async {
    final response = await _apiClient.get<dynamic>(
      '/Transactions/me',
      queryParameters: {
        'pageNumber': page,
        'pageSize': pageSize,
        if (startDate != null) 'startDate': _formatDate(startDate),
        if (endDate != null) 'endDate': _formatDate(endDate),
        if (status != null && status.trim().isNotEmpty) 'status': status,
      },
    );
    return PaginatedResponse.fromJson(
      response.data,
      (json) => Map<String, dynamic>.from(json as Map),
    );
  }

  Future<List<Map<String, dynamic>>> getTransactionsByBooking(
    String bookingId,
  ) async {
    final response = await _apiClient.get<dynamic>(
      '/Transactions/booking/$bookingId',
    );
    return ApiResponseParser.unwrapList(response.data);
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}
