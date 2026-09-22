import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n.dart';
import '../../data/datasources/promotion_api_service.dart';
import '../../data/models/wallet_voucher_model.dart';
import 'ticket_voucher_widget.dart';

class BookingPromotionSheet extends StatefulWidget {
  /// Danh sách voucher đã chọn trước đó.
  final List<WalletVoucherModel> selectedPromotions;

  /// Callback khi user confirm chọn voucher.
  final ValueChanged<List<WalletVoucherModel>> onConfirm;

  const BookingPromotionSheet({
    super.key,
    required this.selectedPromotions,
    required this.onConfirm,
  });

  @override
  State<BookingPromotionSheet> createState() => _BookingPromotionSheetState();
}

class _BookingPromotionSheetState extends State<BookingPromotionSheet>
    with SingleTickerProviderStateMixin {
  final PromotionApiService _apiService = PromotionApiService();

  late TabController _tabController;
  List<WalletVoucherModel> _allVouchers = [];
  bool _isLoading = true;
  String? _errorMessage;
  late List<WalletVoucherModel> _tempSelected;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tempSelected = List<WalletVoucherModel>.from(widget.selectedPromotions);
    _fetchVouchers();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchVouchers() async {
    try {
      final vouchers = await _apiService.getMyWalletVouchers();
      if (!mounted) return;
      setState(() {
        _allVouchers = vouchers
            .where((v) => v.isValidForUse && v.hasUsagesLeft && !v.isExpired)
            .toList();
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = S.of(context).bookingNoPromotions;
        _isLoading = false;
      });
    }
  }

  // Phân chia: giảm theo % → tab "Discount"; giảm cố định VND → tab "Voucher"
  List<WalletVoucherModel> get _discounts => _allVouchers
      .where((v) => v.discountType.toLowerCase() == 'percentage')
      .toList();

  List<WalletVoucherModel> get _vouchers => _allVouchers
      .where((v) => v.discountType.toLowerCase() != 'percentage')
      .toList();

  void _togglePromotion(WalletVoucherModel voucher) {
    setState(() {
      if (_tempSelected.any((v) => v.promotionId == voucher.promotionId)) {
        _tempSelected.clear();
      } else {
        _tempSelected.clear();
        _tempSelected.add(voucher);
      }
    });
  }

  void _confirm() {
    widget.onConfirm(List<WalletVoucherModel>.from(_tempSelected));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 1.0,
      minChildSize: 0.6,
      maxChildSize: 1.0,
      expand: false,
      builder: (_, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // ──── HEADER ────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                child: Column(
                  children: [
                    // Drag Handle
                    Container(
                      width: 48,
                      height: 5,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Voucher trong ví của bạn',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primaryDark,
                            letterSpacing: -0.3,
                          ),
                        ),
                        if (_tempSelected.isNotEmpty)
                          TextButton(
                            onPressed: () =>
                                setState(() => _tempSelected.clear()),
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.redAccent,
                              padding: EdgeInsets.zero,
                              minimumSize: const Size(0, 0),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Bỏ chọn',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          )
                        else
                          IconButton(
                            icon: Icon(
                              Icons.close,
                              color: Colors.grey.shade600,
                            ),
                            onPressed: () => Navigator.pop(context),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // ──── TABS: Discount / Voucher ────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                height: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFF2F4F7), // Rất nhạt
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(4.0),
                  child: TabBar(
                    controller: _tabController,
                    indicatorSize: TabBarIndicatorSize.tab,
                    indicator: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    labelColor: AppColors.primary,
                    unselectedLabelColor: Colors.grey.shade600,
                    labelStyle: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    unselectedLabelStyle: const TextStyle(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                    dividerColor: Colors.transparent,
                    tabs: const [
                      Tab(text: 'Giảm %'),
                      Tab(text: 'Giảm tiền'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // ──── CONTENT ────
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                        ),
                      )
                    : _errorMessage != null
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.error_outline,
                              color: Colors.grey.shade400,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              _errorMessage!,
                              style: const TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            FilledButton(
                              onPressed: () {
                                setState(() {
                                  _isLoading = true;
                                  _errorMessage = null;
                                });
                                _fetchVouchers();
                              },
                              child: Text(S.of(context).bookingRetry),
                            ),
                          ],
                        ),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: [
                          _buildList(_discounts, scrollController),
                          _buildList(_vouchers, scrollController),
                        ],
                      ),
              ),

              // ──── FOOTER ────
              SafeArea(
                child: Container(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 10,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _tempSelected.isEmpty
                            ? Colors.grey.shade100
                            : AppColors.primary,
                        foregroundColor: _tempSelected.isEmpty
                            ? Colors.grey.shade600
                            : Colors.white,
                        elevation: _tempSelected.isEmpty ? 0 : 2,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        _tempSelected.isEmpty
                            ? 'Bỏ qua (Không áp dụng)'
                            : 'Xác nhận áp dụng',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          color: _tempSelected.isEmpty
                              ? Colors.grey.shade700
                              : Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList(
    List<WalletVoucherModel> list,
    ScrollController scrollController,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.local_activity_outlined,
                size: 56,
                color: Colors.grey.shade300,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Chưa có mã khuyến mãi',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.w600,
                fontSize: 15,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Mục này hiện tại chưa có voucher nào.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 13),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: scrollController,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      itemCount: list.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final voucher = list[index];
        final isSelected = _tempSelected.any(
          (v) => v.promotionId == voucher.promotionId,
        );

        return TicketVoucherWidget(
          voucher: voucher,
          isSelected: isSelected,
          onTap: () => _togglePromotion(voucher),
        );
      },
    );
  }
}
