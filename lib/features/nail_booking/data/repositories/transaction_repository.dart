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
    try {
                  final response = await _apiClient.get<dynamic>(
        '/Transactions/booking/$bookingId/payment-history',
      );
      final list = ApiResponseParser.unwrapList(response.data);
      if (list.isNotEmpty) {
        return list.map((e) => {
          'transactionId': e['id'],
          'amount': e['amount'],
          'status': e['status'],
          'orderCode': e['description'],
          'salonName': e['paymentMethod'] == 'Ví' ? 'Ví Nailify' : 'Chuyển khoản / PayOS',
          'createdAt': e['createdAt'],
        }).toList();
      }
    } catch (_) {}

    try {
      final myTxs = await getMyTransactions(page: 1, pageSize: 50);
      final filtered = myTxs.items.where((tx) {
        final txBookingId = tx['bookingId']?.toString().toLowerCase().trim();
        final targetBookingId = bookingId.toLowerCase().trim();
        if (txBookingId != null && txBookingId == targetBookingId) return true;
        return false;
      }).toList();
      if (filtered.isNotEmpty) return filtered;
    } catch (_) {}

    return [];
  }

  String _formatDate(DateTime date) {
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }
}



