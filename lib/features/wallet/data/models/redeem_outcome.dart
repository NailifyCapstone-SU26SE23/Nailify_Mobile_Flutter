import 'redeem_result_model.dart';

/// Bao bọc kết quả redeem kèm theo message từ response wrapper.
/// Message là phần user cần thấy ("Đổi voucher thành công! Đã trừ 100 điểm...").
class RedeemOutcome {
  final RedeemResultModel result;
  final String message;

  const RedeemOutcome({required this.result, required this.message});
}
