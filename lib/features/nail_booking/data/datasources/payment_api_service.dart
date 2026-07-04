import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

class PaymentApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  Future<Map<String, dynamic>> createPayment(String bookingId) async {
    final response = await _apiClient.post('/payments/create/$bookingId');
    return Map<String, dynamic>.from(response.data['data'] ?? {});
  }

  Future<String> getPaymentStatus(int orderCode) async {
    final response = await _apiClient.get('/payments/status/$orderCode');
    final responseData = response.data;
    if (responseData is Map<String, dynamic>) {
      final data = responseData['data'];
      if (data is Map<String, dynamic>) {
        return data['status']?.toString() ?? '';
      }
      return responseData['status']?.toString() ?? '';
    }
    return '';
  }

  Future<void> cancelPayment(int orderCode) async {
    await _apiClient.post('/payments/cancel/$orderCode');
  }

  Future<Map<String, dynamic>> refundPayment({
    required String bookingId,
    required String accountNumber,
    required String accountName,
    required String bankCode,
  }) async {
    final response = await _apiClient.post(
      '/payments/refund/$bookingId',
      data: {
        'accountNumber': accountNumber,
        'accountName': accountName,
        'bankCode': bankCode,
      },
    );
    return Map<String, dynamic>.from(response.data['data'] ?? {});
  }
}
