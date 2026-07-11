import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/datasources/promotion_api_service.dart';
import '../../data/models/promotion_model.dart';

class BookingPromotionSheet extends StatefulWidget {
  final List<PromotionModel> selectedPromotions;
  final ValueChanged<List<PromotionModel>> onConfirm;

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
  List<PromotionModel> _allPromotions = [];
  bool _isLoading = true;
  String? _errorMessage;
  late List<PromotionModel> _tempSelected;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tempSelected = List<PromotionModel>.from(widget.selectedPromotions);
    _fetchPromotions();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchPromotions() async {
    try {
      final result = await _apiService.getPromotions(pageSize: 20);
      if (mounted) {
        setState(() {
          _allPromotions = result;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Không thể tải danh sách khuyến mãi';
          _isLoading = false;
        });
      }
    }
  }

  List<PromotionModel> get _discounts =>
      _allPromotions.where((p) => p.type == 'Discount').toList();

  List<PromotionModel> get _vouchers =>
      _allPromotions.where((p) => p.type == 'Voucher').toList();

  void _togglePromotion(PromotionModel promotion) {
    setState(() {
      if (_tempSelected.any((p) => p.promotionId == promotion.promotionId)) {
        _tempSelected.removeWhere(
          (p) => p.promotionId == promotion.promotionId,
        );
      } else {
        _tempSelected.add(promotion);
      }
    });
  }

  void _confirm() {
    widget.onConfirm(List<PromotionModel>.from(_tempSelected));
    Navigator.pop(context);
  }

  String _discountLabel(PromotionModel p) {
    if (p.discountType == 'Percentage') {
      final value = p.discountValue % 1 == 0
          ? p.discountValue.toInt().toString()
          : p.discountValue.toString();
      return 'Giảm $value%';
    } else {
      // FixedAmount
      final value = p.discountValue.round().toString().replaceAllMapped(
        RegExp(r'\B(?=(\d{3})+(?!\d))'),
        (_) => ',',
      );
      return 'Giảm $value đ';
    }
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
              Container(
                padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Chọn khuyến mãi',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (_tempSelected.isNotEmpty)
                      TextButton(
                        onPressed: () => setState(() => _tempSelected.clear()),
                        child: const Text(
                          'Bỏ chọn tất cả',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              // ──── TABS: Discount / Voucher ────
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  indicatorSize: TabBarIndicatorSize.tab,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.grey.shade700,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'Discount'),
                    Tab(text: 'Voucher'),
                  ],
                ),
              ),

              // ──── CONTENT ────
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
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
                                _fetchPromotions();
                              },
                              child: const Text('Thử lại'),
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _confirm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        _tempSelected.isEmpty
                            ? 'Không áp dụng khuyến mãi'
                            : 'Áp dụng (${_tempSelected.length})',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
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
    List<PromotionModel> list,
    ScrollController scrollController,
  ) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 56,
              color: Colors.grey.shade300,
            ),
            const SizedBox(height: 12),
            Text(
              'Không có khuyến mãi nào',
              style: TextStyle(color: Colors.grey.shade500),
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
        final promo = list[index];
        final isSelected = _tempSelected.any(
          (p) => p.promotionId == promo.promotionId,
        );
        final discountLabel = _discountLabel(promo);

        return GestureDetector(
          onTap: () => _togglePromotion(promo),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.05)
                  : Colors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Badge giảm giá
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary
                        : Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        promo.discountType == 'Percentage'
                            ? Icons.percent
                            : Icons.discount_outlined,
                        color: isSelected
                            ? Colors.white
                            : Colors.orange.shade700,
                        size: 20,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        discountLabel
                            .split(' ')
                            .last, // e.g. "10%" or "50,000 đ"
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: isSelected
                              ? Colors.white
                              : Colors.orange.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Tên & mô tả
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        promo.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      if (promo.description.isNotEmpty)
                        Text(
                          promo.description,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Text(
                          discountLabel,
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),

                // Checkbox
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => _togglePromotion(promo),
                  activeColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
