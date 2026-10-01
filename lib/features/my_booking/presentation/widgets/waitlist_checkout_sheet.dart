import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../generated/l10n.dart';
import '../../../nail_booking/data/datasources/booking_api_service.dart';
import '../../../nail_booking/data/models/wallet_voucher_model.dart';
import '../../../nail_booking/presentation/widgets/booking_promotion_sheet.dart';
import '../../../nail_booking/presentation/widgets/payment_detail_table.dart';
import '../../../wallet/data/datasources/wallet_api_service.dart';
import '../../data/datasources/my_booking_api_service.dart';
import '../../data/datasources/waitlist_api_service.dart';
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
  final BookingApiService _bookingPriceApi = BookingApiService();

  bool _useWalletBalance = true;
  List<WalletVoucherModel> _selectedPromotions = [];
  bool _isConfirming = false;

  Map<String, dynamic>? _priceReview;
  bool _isReviewingPrice = false;
  num? _walletAvailableBalance;

  @override
  void initState() {
    super.initState();
    _fetchWalletBalance();
    _fetchPriceReview();
  }

  Future<void> _fetchWalletBalance() async {
    try {
      final summary =
          await WalletApiService(getIt<ApiClient>()).getCustomerWalletSummary();
      final bal = summary['balance'] ?? summary['Balance'];
      if (bal is num && mounted) {
        setState(() => _walletAvailableBalance = bal);
      }
    } catch (_) {}
  }

  Future<void> _fetchPriceReview() async {
    final salonId = widget.waitlist.salonId;
    if (salonId == null || salonId.isEmpty) return;

    if (mounted) setState(() => _isReviewingPrice = true);

    try {
      final bookingItems = widget.waitlist.waitlistItems.map((item) {
        return {
          if (item.nailVariantId != null && item.nailVariantId! > 0)
            'nailVariantId': item.nailVariantId,
          if (item.serviceId != null && item.serviceId!.trim().isNotEmpty)
            'serviceId': item.serviceId,
          if (item.shapeMethodConfigId != null && item.shapeMethodConfigId! > 0)
            'shapeMethodConfigId': item.shapeMethodConfigId,
          if (item.customerNailId != null && item.customerNailId! > 0)
            'customerNailId': item.customerNailId,
          if (item.customerNailRequestId != null &&
              item.customerNailRequestId!.trim().isNotEmpty)
            'customerNailRequestId': item.customerNailRequestId,
          'quantity': (item.quantity != null && item.quantity! > 0) ? item.quantity : 1,
        };
      }).toList();

      final promotionIds = _selectedPromotions.map((v) => v.promotionId).toList();

      final dateStr =
          "${widget.waitlist.date.year}-${widget.waitlist.date.month.toString().padLeft(2, '0')}-${widget.waitlist.date.day.toString().padLeft(2, '0')}T00:00:00";
      final timeStr = widget.waitlist.time.length == 5
          ? "${widget.waitlist.time}:00"
          : widget.waitlist.time;

      final review = await _bookingPriceApi.reviewPriceWithItems(
        salonId: salonId,
        bookingDate: dateStr,
        startTime: timeStr,
        artistId: widget.waitlist.staffId,
        bookingItems: bookingItems,
        selectedPromotionIds: promotionIds,
      );

      if (mounted) {
        setState(() {
          _priceReview = review;
        });
      }
    } catch (e) {
      debugPrint('[WaitlistCheckoutSheet] _fetchPriceReview error: $e');
    } finally {
      if (mounted) setState(() => _isReviewingPrice = false);
    }
  }

  Future<void> _handleConfirm() async {
    setState(() => _isConfirming = true);

    try {
      final promotionIds = _selectedPromotions.map((v) => v.promotionId).toList();

      final bookingItems = widget.waitlist.waitlistItems.map((item) {
        return {
          if (item.nailVariantId != null && item.nailVariantId! > 0)
            'nailVariantId': item.nailVariantId,
          if (item.serviceId != null && item.serviceId!.trim().isNotEmpty)
            'serviceId': item.serviceId,
          if (item.shapeMethodConfigId != null && item.shapeMethodConfigId! > 0)
            'shapeMethodConfigId': item.shapeMethodConfigId,
          if (item.customerNailId != null && item.customerNailId! > 0)
            'customerNailId': item.customerNailId,
          if (item.customerNailRequestId != null &&
              item.customerNailRequestId!.trim().isNotEmpty)
            'customerNailRequestId': item.customerNailRequestId,
          'quantity': (item.quantity != null && item.quantity! > 0) ? item.quantity : 1,
        };
      }).toList();

      final convertedBookingId = await _waitlistApi.confirmWaitlist(
        widget.waitlist.id,
        useWalletBalance: _useWalletBalance,
        selectedPromotionIds: promotionIds,
        bookingItems: bookingItems,
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

  Future<void> _handleChangeServices(BuildContext context) async {
    final String waitlistId = widget.waitlist.id;
    if (waitlistId.isNotEmpty) {
      try {
        await _waitlistApi.cancelWaitlist(waitlistId);
      } catch (e) {
        debugPrint('[WaitlistCheckoutSheet] cancelWaitlist error before re-booking: $e');
      }
    }

    if (!context.mounted) return;
    Navigator.pop(context); // Đóng modal

    final items = widget.waitlist.waitlistItems;
    final String? salonId = widget.waitlist.salonId;
    final String salonName = widget.waitlist.salonName;
    final String? artistId = widget.waitlist.staffId;
    final String artistName = widget.waitlist.staffName;

    final List<String> serviceIds = items
        .map((e) => e.serviceId)
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();

    int? nailVariantId;
    String? nailVariantName;
    String? nailVariantImageUrl;
    for (final it in items) {
      if (it.nailVariantId != null && it.nailVariantId! > 0) {
        nailVariantId = it.nailVariantId;
        nailVariantName = it.nailVariantName;
        nailVariantImageUrl = it.nailVariantImageUrl;
        break;
      }
    }

    int? customerNailId;
    String? customerNailName;
    String? customerNailImageUrl;
    for (final it in items) {
      if (it.customerNailId != null && it.customerNailId! > 0) {
        customerNailId = it.customerNailId;
        customerNailName = it.customerNailName;
        customerNailImageUrl = it.customerNailImageUrl;
        break;
      }
    }

    String? customerNailRequestId;
    for (final it in items) {
      if (it.customerNailRequestId != null &&
          it.customerNailRequestId!.trim().isNotEmpty) {
        customerNailRequestId = it.customerNailRequestId;
        break;
      }
    }

    int? shapeConfigId;
    String? shapeConfigName;
    for (final it in items) {
      if (it.shapeMethodConfigId != null && it.shapeMethodConfigId! > 0) {
        shapeConfigId = it.shapeMethodConfigId;
        shapeConfigName = it.shapeMethodConfigName;
        break;
      }
    }

    final Map<String, dynamic> bookingExtra = {
      if (salonId != null && salonId.isNotEmpty)
        'salon': {
          'salonId': salonId,
          'name': salonName,
        },
      if (artistId != null && artistId.isNotEmpty)
        'artist': {
          'nailArtistId': artistId,
          'fullName': artistName,
          'salonId': salonId ?? '',
        },
      'date': widget.waitlist.date,
      'time': widget.waitlist.time,
      'serviceIds': serviceIds,
      'nailVariantId':? nailVariantId,
      'nailVariantName':? nailVariantName,
      'nailVariantImageUrl':? nailVariantImageUrl,
      'customerNailId':? customerNailId,
      'customerNailName':? customerNailName,
      'customerNailImageUrl':? customerNailImageUrl,
      'customerNailRequestId':? customerNailRequestId,
      'shapeMethodConfigId':? shapeConfigId,
      'shapeMethodName':? shapeConfigName,
      'waitlistItems': items.map((e) => e.toJson()).toList(),
    };

    context.push('/home-booking', extra: bookingExtra);
  }

  String _clean(String? s) {
    if (s == null) return '';
    final trimmed = s.trim();
    if (trimmed.toLowerCase() == 'string') return '';
    return trimmed;
  }

  String _getCleanTitle(WaitlistItemModel item) {
    final vName = _clean(item.nailVariantName);
    if (vName.isNotEmpty) return vName;

    final cName = _clean(item.customerNailName);
    if (cName.isNotEmpty) return cName;

    final sName = _clean(item.serviceName);
    if (sName.isNotEmpty) return sName;

    final shapeName = _clean(item.shapeMethodConfigName);
    if (shapeName.isNotEmpty) return 'Làm dáng móng: $shapeName';

    if (widget.waitlist.services.isNotEmpty) {
      return widget.waitlist.services.first;
    }

    return 'Dịch vụ làm móng';
  }

  String? _getCleanImgUrl(WaitlistItemModel item) {
    final vUrl = _clean(item.nailVariantImageUrl);
    if (vUrl.startsWith('http')) return vUrl;
    final cUrl = _clean(item.customerNailImageUrl);
    if (cUrl.startsWith('http')) return cUrl;
    return null;
  }

  List<PaymentTableItem> get _paymentTableItems {
    final List<PaymentTableItem> items = [];

    final rawItems = _priceReview?['items'] ?? _priceReview?['bookingItems'];
    if (rawItems is List && rawItems.isNotEmpty) {
      for (final raw in rawItems) {
        if (raw is Map) {
          final name = raw['serviceName']?.toString() ??
              raw['nailVariantName']?.toString() ??
              raw['name']?.toString() ??
              raw['title']?.toString() ??
              'Dịch vụ làm móng';
          final qty = (raw['quantity'] as num?)?.toInt() ?? 1;
          final unitPrice = (raw['unitPrice'] as num?) ?? (raw['price'] as num?) ?? 0;
          final totalPrice = (raw['totalPrice'] as num?) ?? (unitPrice * qty);
          items.add(PaymentTableItem(
            name: name,
            quantity: qty,
            unitPrice: unitPrice,
            totalPrice: totalPrice,
          ));
        }
      }
    }

    if (items.isEmpty) {
      for (final item in widget.waitlist.waitlistItems) {
        final name = _getCleanTitle(item);
        final qty = (item.quantity != null && item.quantity! > 0) ? item.quantity! : 1;
        items.add(PaymentTableItem(
          name: name,
          quantity: qty,
          unitPrice: 0,
          totalPrice: 0,
        ));
      }
    }

    return items;
  }

  Widget _buildPaymentDetailsCard() {
    final reviewTotal = _priceReview?['totalPrice'];
    final reviewSubtotal =
        _priceReview?['subTotal'] ?? _priceReview?['originalPrice'];

    final int subtotalPrice = (reviewSubtotal is num)
        ? reviewSubtotal.round()
        : (reviewTotal is num ? reviewTotal.round() : 0);

    final int totalPrice = (reviewTotal is num) ? reviewTotal.round() : subtotalPrice;

    final int depositAmount = totalPrice > 0
        ? (totalPrice < 50000 ? totalPrice : 50000)
        : 0;

    final walletDeduction = (_useWalletBalance &&
            _walletAvailableBalance != null &&
            _walletAvailableBalance! > 0)
        ? (_walletAvailableBalance! < depositAmount
            ? _walletAvailableBalance!.round()
            : depositAmount)
        : 0;

    final int amountDue = (depositAmount - walletDeduction).clamp(0, totalPrice);

    final discounts = _priceReview?['discountBreakdown'] ??
        _priceReview?['discounts'] ??
        [];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.receipt_long_rounded,
                  size: 18,
                  color: Color(0xFFE02B6D),
                ),
              ),
              const SizedBox(width: 10),
              const Expanded(
                child: Text(
                  'Chi tiết thanh toán & Tóm tắt',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              if (_isReviewingPrice)
                const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Color(0xFFE02B6D),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (_paymentTableItems.isNotEmpty) ...[
            PaymentDetailTable(items: _paymentTableItems),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),
          ],

          _buildInvoiceRow('Tạm tính', subtotalPrice, isNegative: false),

          if (discounts is List)
            for (final d in discounts)
              if (d is Map)
                _buildInvoiceRow(
                  d['title']?.toString() ?? d['name']?.toString() ?? 'Giảm giá',
                  (d['amount'] as num?)?.round() ?? 0,
                  isNegative: true,
                ),

          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 10),

          // Tổng tiền dịch vụ
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Tổng tiền dịch vụ',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                PriceFormatter.format(totalPrice),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE02B6D),
                  fontSize: 17,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 12),

          // Thông tin cọc
          _buildInvoiceRow('Tiền đặt cọc giữ chỗ', depositAmount, isNegative: false),
          if (_useWalletBalance && walletDeduction > 0)
            _buildInvoiceRow('Khấu trừ từ Ví Nailify', walletDeduction, isNegative: true),

          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFFFFF0F5),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFFFFD1DC)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cần thanh toán ngay',
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
                Text(
                  PriceFormatter.format(amountDue),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE02B6D),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceRow(
    String label,
    num amount, {
    required bool isNegative,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13,
              color: isNegative ? Colors.green.shade700 : Colors.grey.shade700,
            ),
          ),
          Text(
            isNegative
                ? '-${PriceFormatter.format(amount)}'
                : PriceFormatter.format(amount),
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isNegative ? Colors.green.shade700 : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = "${widget.waitlist.date.day.toString().padLeft(2, '0')}/${widget.waitlist.date.month.toString().padLeft(2, '0')}/${widget.waitlist.date.year}";
    final isOpened = widget.waitlist.status == WaitlistStatus.opened;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.88;

    return Container(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      padding: const EdgeInsets.all(20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  isOpened ? 'Xác nhận Lịch hẹn' : 'Chi tiết Lịch chờ',
                  style: const TextStyle(
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
            
            // Thêm tóm tắt thời gian & thợ
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
                          '${widget.waitlist.salonName} • Thợ: ${widget.waitlist.staffName}',
                          style: const TextStyle(color: Colors.grey, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // ── CHI TIẾT MẪU NAIL & DỊCH VỤ ĐÃ ĐẶT ───────────────────────────
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7F9),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFCE3EC)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.brush_rounded, size: 16, color: AppColors.primary),
                          SizedBox(width: 6),
                          Text(
                            'Dịch vụ & Mẫu nail đã chọn',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                      InkWell(
                        onTap: () => _handleChangeServices(context),
                        borderRadius: BorderRadius.circular(8),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                          child: Row(
                            children: [
                              Icon(Icons.edit_rounded, size: 14, color: AppColors.primary),
                              SizedBox(width: 4),
                              Text(
                                'Thay đổi dịch vụ',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Divider(height: 1, color: Color(0xFFFCE3EC)),
                  const SizedBox(height: 8),
                  if (widget.waitlist.waitlistItems.isNotEmpty)
                    ...widget.waitlist.waitlistItems.map((item) {
                      final imgUrl = _getCleanImgUrl(item);
                      final title = _getCleanTitle(item);
                      final shapeName = _clean(item.shapeMethodConfigName);

                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            if (imgUrl != null && imgUrl.isNotEmpty)
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(
                                  imgUrl,
                                  width: 28,
                                  height: 28,
                                  fit: BoxFit.cover,
                                  errorBuilder: (ctx, err, stack) => const Icon(Icons.spa_rounded, size: 18, color: AppColors.primary),
                                ),
                              )
                            else
                              const Icon(Icons.check_circle_outline_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: const TextStyle(
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                  ),
                                  if (shapeName.isNotEmpty)
                                    Text(
                                      'Phom: $shapeName',
                                      style: TextStyle(
                                        fontSize: 11,
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (item.quantity != null && item.quantity! > 1)
                              Text(
                                'x${item.quantity}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                ),
                              ),
                          ],
                        ),
                      );
                    })
                  else if (widget.waitlist.services.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: widget.waitlist.services.map((s) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFCE3EC)),
                          ),
                          child: Text(
                            s,
                            style: const TextStyle(fontSize: 11.5, color: AppColors.textPrimary),
                          ),
                        );
                      }).toList(),
                    )
                  else
                    Text(
                      'Chưa có thông tin dịch vụ chi tiết',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── FORM SUMMARY: TÓM TẮT CHI TIẾT THANH TOÁN & ĐẶT CỌC ────────────
            if (isOpened) ...[
              _buildPaymentDetailsCard(),
              const SizedBox(height: 16),
            ],

            if (isOpened) ...[
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
                        _fetchPriceReview();
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
                      color: Colors.amber.withValues(alpha: 0.15),
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
                    activeTrackColor: AppColors.primary,
                    onChanged: (val) {
                      setState(() {
                        _useWalletBalance = val;
                      });
                    },
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
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
            ] else ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: Colors.grey.shade300),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}
