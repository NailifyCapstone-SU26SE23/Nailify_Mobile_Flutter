import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n.dart';
import '../../../nail_booking/presentation/widgets/booking_promotion_sheet.dart';
import '../../../nail_booking/data/models/wallet_voucher_model.dart';
import '../../data/datasources/waitlist_api_service.dart';
import '../../data/datasources/my_booking_api_service.dart';
import '../../data/models/waitlist_model.dart';

class WaitlistCheckoutSheet extends StatefulWidget {
  final WaitlistModel waitlist;
  final VoidCallback onSuccess;

  const WaitlistCheckoutSheet({
    super.key,
    required this.waitlist,
    required this.onSuccess,
  });

  @override
  State<WaitlistCheckoutSheet> createState() => _WaitlistCheckoutSheetState();
}

class _WaitlistCheckoutSheetState extends State<WaitlistCheckoutSheet> {
  final WaitlistApiService _waitlistApi = WaitlistApiService();
  final MyBookingApiService _bookingApi = MyBookingApiService();

  bool _useWalletBalance = true;
  List<WalletVoucherModel> _selectedPromotions = [];
  bool _isConfirming = false;

  Future<void> _handleConfirm() async {
    setState(() => _isConfirming = true);

    try {
      final promotionIds = _selectedPromotions.map((v) => v.promotionId).toList();
      
      final convertedBookingId = await _waitlistApi.confirmWaitlist(
        widget.waitlist.id,
        useWalletBalance: _useWalletBalance,
        selectedPromotionIds: promotionIds,
      );

      if (convertedBookingId != null && convertedBookingId != "SUCCESS_NO_ID") {
        widget.onSuccess();
        
        final bookingDetails = await _bookingApi.getBookingDetails(convertedBookingId);
        final amountDue = bookingDetails['amountDue'];
        
        if (!mounted) return;
        Navigator.pop(context); // Đóng bottom sheet

        if (amountDue != null && (amountDue is num) && amountDue > 0) {
          // Tiền ví không đủ, cần thanh toán thêm qua PayOS
          context.push('/payment-qr', extra: {
            'bookingId': convertedBookingId,
            'amountDue': amountDue,
          });
        } else {
          // Trả đủ cọc hoặc áp voucher 100% -> Thành công luôn
          context.push('/booking-success', extra: {
            'bookingId': convertedBookingId,
          });
        }
      } else if (convertedBookingId == "SUCCESS_NO_ID") {
        if (!mounted) return;
        Navigator.pop(context);
        widget.onSuccess();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).waitlistConfirmSuccess)),
        );
      } else {
        throw Exception("Failed to convert booking");
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).waitlistConfirmError(e.toString()))),
      );
    } finally {
      if (mounted) setState(() => _isConfirming = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = "${widget.waitlist.date.day.toString().padLeft(2, '0')}/${widget.waitlist.date.month.toString().padLeft(2, '0')}/${widget.waitlist.date.year}";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Xác nhận Lịch hẹn',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Thêm tóm tắt thời gian
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.access_time_filled, color: AppColors.primary, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.waitlist.time} - $dateStr',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.waitlist.salonName,
                        style: const TextStyle(color: Colors.grey, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Chọn Voucher
          GestureDetector(
            onTap: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => BookingPromotionSheet(
                  selectedPromotions: _selectedPromotions,
                  onConfirm: (list) {
                    setState(() {
                      _selectedPromotions = list;
                    });
                  },
                ),
              );
            },
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFF0F5),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.confirmation_number_rounded,
                    size: 20,
                    color: Color(0xFFE02B6D),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    _selectedPromotions.isNotEmpty 
                        ? 'Đã chọn ${_selectedPromotions.length} voucher'
                        : 'Voucher giảm giá',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.grey),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(),
          const SizedBox(height: 12),

          // Toggle Wallet
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 20,
                  color: Colors.amber,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Sử dụng số dư ví',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Switch(
                value: _useWalletBalance,
                activeColor: AppColors.primary,
                onChanged: (val) {
                  setState(() {
                    _useWalletBalance = val;
                  });
                },
              ),
            ],
          ),
          
          const SizedBox(height: 32),
          
          // Nút Xác nhận
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _isConfirming ? null : _handleConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: _isConfirming
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    )
                  : const Text(
                      'Xác nhận & Tạo Lịch',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
