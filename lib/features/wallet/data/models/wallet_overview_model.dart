import 'loyalty_model.dart';
import 'wallet_voucher_model.dart';

/// Snapshot của toàn bộ màn hình Wallet Overview.
/// Không map trực tiếp từ một endpoint — gộp dữ liệu từ `/Loyalty/me`
/// và `/Promotions/my-wallet-vouchers` để giảm số lần render loading.
class WalletOverviewSnapshot {
  final LoyaltyModel loyalty;
  final List<WalletVoucherModel> vouchers;

  const WalletOverviewSnapshot({
    required this.loyalty,
    required this.vouchers,
  });

  int get usableVoucherCount =>
      vouchers.where((v) => v.isUsableNow).length;

  int get expiredVoucherCount =>
      vouchers.where((v) => v.isExpired).length;

  int get usedVoucherCount =>
      vouchers.where((v) => v.isFullyUsed).length;

  /// 3 voucher sắp hết hạn gần nhất (còn hiệu lực, sắp expire).
  List<WalletVoucherModel> get expiringSoon {
    final list = vouchers
        .where((v) => v.isUsableNow && v.endDate != null)
        .toList()
      ..sort((a, b) => (a.endDate ?? DateTime.now())
          .compareTo(b.endDate ?? DateTime.now()));
    return list.take(3).toList();
  }
}
