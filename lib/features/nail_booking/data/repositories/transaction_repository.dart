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
      (json) {
        final map = Map<String, dynamic>.from(json as Map);
        final method = map['paymentMethod']?.toString() ?? '';
        final linkId = map['paymentLinkId']?.toString();
        final walletId = map['walletId']?.toString();

        String label = 'Chuyển khoản / PayOS';
        if (method == 'Ví' || linkId?.toUpperCase() == 'WALLET_PAYMENT') {
          label = 'Ví Nailify';
        } else if (method == 'Tiền mặt' || ((linkId == null || linkId.isEmpty) && (walletId == null || walletId.isEmpty))) {
          label = 'Tiền mặt';
        } else if (method == 'Nạp tiền vào ví' || (linkId != null && linkId.isNotEmpty && walletId != null && walletId.isNotEmpty)) {
          label = 'Nạp tiền vào ví';
        }

        map['paymentMethodName'] = label;
        if (map['salonName'] == null || map['salonName'].toString().isEmpty) {
          map['salonName'] = label;
        }
        return map;
      },
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
        return list.map((e) {
          final method = e['paymentMethod']?.toString() ?? '';
          String label = 'Chuyển khoản / PayOS';
          if (method == 'Ví') {
            label = 'Ví Nailify';
          } else if (method == 'Tiền mặt') {
            label = 'Tiền mặt';
          } else if (method == 'Nạp tiền vào ví') {
            label = 'Nạp tiền vào ví';
          }
          return {
            'transactionId': e['id'],
            'amount': e['amount'],
            'status': e['status'],
            'orderCode': e['description'],
            'salonName': label,
            'createdAt': e['createdAt'],
          };
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



