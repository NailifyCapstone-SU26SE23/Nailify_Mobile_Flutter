import '../../../../core/network/api_client.dart';
import '../../../../core/utils/paginated_response.dart';
import '../models/loyalty_model.dart';
import '../models/loyalty_transaction_model.dart';
import '../models/redeem_outcome.dart';
import '../models/redeem_result_model.dart';
import '../models/redeemable_promotion_model.dart';
import '../models/wallet_voucher_model.dart';

/// Tầng giao tiếp thẳng với REST API cho Wallet feature.
/// Tách khỏi repository để dễ mock khi test.
class WalletApiService {
  final ApiClient _api;
  WalletApiService(this._api);

  /// GET /Loyalty/me
  Future<LoyaltyModel> getLoyalty() async {
    final response = await _api.get<dynamic>('/Loyalty/me');
    final data = response.data;
    final payload = _unwrapData(data);
    return LoyaltyModel.fromJson(Map<String, dynamic>.from(payload));
  }

  /// GET /Promotions/my-wallet-vouchers
  /// Response mới nhất: data là mảng các voucher khả dụng.
  Future<List<WalletVoucherModel>> getMyWalletVouchers() async {
    final response = await _api.get<dynamic>('/Promotions/my-wallet-vouchers');
    final payload = _unwrapData(response.data);

    List<dynamic> list;
    if (payload is List) {
      list = payload;
    } else if (payload is Map && payload['items'] is List) {
      list = payload['items'] as List;
    } else if (payload is Map && payload['vouchers'] is List) {
      list = payload['vouchers'] as List;
    } else {
      list = const [];
    }

    return list
        .whereType<Map>()
        .map(
          (json) => WalletVoucherModel.fromJson(Map<String, dynamic>.from(json)),
        )
        .toList();
  }

  /// GET /Promotions/redeemable?pageNumber=&pageSize=
  Future<PaginatedResponse<RedeemablePromotionModel>> getRedeemable({
    int page = 1,
    int pageSize = 10,
  }) async {
    final response = await _api.get<dynamic>(
      '/Promotions/redeemable',
      queryParameters: {
        'pageNumber': page,
        'pageSize': pageSize,
      },
    );
    return PaginatedResponse.fromJson(
      Map<String, dynamic>.from(response.data as Map),
      (raw) => RedeemablePromotionModel.fromJson(
        Map<String, dynamic>.from(raw as Map),
      ),
    );
  }

  /// POST /Promotions/{promotionId}/redeem
  /// Trả về [RedeemOutcome] gồm model typed + message BE trả về
  /// (ví dụ: "Đổi voucher thành công! Đã trừ 100 điểm...").
  Future<RedeemOutcome> redeem(int promotionId) async {
    final response = await _api.post<dynamic>(
      '/Promotions/$promotionId/redeem',
    );
    final raw = response.data;
    String message = '';
    Map<String, dynamic> payload;
    if (raw is Map && raw.containsKey('data')) {
      message = raw['message']?.toString() ?? '';
      final data = raw['data'];
      payload = data is Map
          ? Map<String, dynamic>.from(data)
          : <String, dynamic>{};
    } else if (raw is Map) {
      payload = Map<String, dynamic>.from(raw);
    } else {
      payload = <String, dynamic>{};
    }
    return RedeemOutcome(
      result: RedeemResultModel.fromJson(payload),
      message: message,
    );
  }

  /// Lấy `data` từ response chuẩn `{isSucceeded, message, data}`.
  /// Fallback về chính response.data nếu không đúng format.
  dynamic _unwrapData(dynamic raw) {
    if (raw is Map && raw.containsKey('data')) {
      return raw['data'];
    }
    return raw;
  }

  /// GET /LoyaltyTransactions/me?pageNumber=&pageSize=
  /// Lịch sử biến động điểm của khách hàng hiện tại.
  Future<PaginatedLoyaltyTransactions> getMyLoyaltyTransactions({
    int pageNumber = 1,
    int pageSize = 20,
  }) async {
    final response = await _api.get<dynamic>(
      '/LoyaltyTransactions/me',
      queryParameters: {
        'pageNumber': pageNumber,
        'pageSize': pageSize,
      },
    );

    final raw = response.data;
    if (raw is Map) {
      return PaginatedLoyaltyTransactions.fromJson(
        Map<String, dynamic>.from(raw),
      );
    }
    return const PaginatedLoyaltyTransactions(
      items: [],
      page: 1,
      hasNextPage: false,
      totalItems: 0,
    );
  }
}
