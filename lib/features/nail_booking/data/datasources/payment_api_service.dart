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
    return response.data['status']?.toString() ?? '';
  }

  Future<void> cancelPayment(int orderCode) async {
    await _apiClient.post('/payments/cancel/$orderCode');
  }
}
