import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../nails/data/models/nail_variant_model.dart';
import '../../../nails/data/repositories/nail_variant_repository.dart';
import '../../data/models/promotion_model.dart';
import '../cubit/nail_booking_cubit.dart';
import '../widgets/booking_date_selection.dart';
import '../widgets/booking_service_selection.dart';
import '../widgets/booking_stylist_selection.dart';
import '../widgets/booking_time_selection.dart';
import '../widgets/branch_selection_list.dart';

class NailBookingPage extends StatefulWidget {
  final Map<String, dynamic>? nailData;

  const NailBookingPage({super.key, this.nailData});

  @override
  State<NailBookingPage> createState() => _NailBookingPageState();
}

class _NailBookingPageState extends State<NailBookingPage> {
  final PageController _pageController = PageController();
  final NailBookingCubit _cubit = NailBookingCubit();

  int _currentStep = 0;
  bool _isPromotionExpanded = false;
  bool _isReviewingPrice = false;

  Map<String, dynamic>? _priceReview;
  NailVariantModel? _nailVariantDetail;

  // ── Getters từ nailData ──────────────────────────────────────────────────

  int get _nailVariantId {
    return int.tryParse(widget.nailData?['id']?.toString() ?? '0') ?? 0;
  }

  int get _nailVariantPrice {
    final price = widget.nailData?['price'];
    if (price is num) return price.round();
    return int.tryParse(price?.toString() ?? '') ?? 0;
  }

  String? get _shapeMethodName {
    final value = widget.nailData?['shapeMethodName']?.toString().trim();
    return value == null || value.isEmpty ? null : value;
  }

  int? get _shapeMethodConfigId {
    final value = widget.nailData?['shapeMethodConfigId'];
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  num get _shapeMethodPrice {
    final value = widget.nailData?['shapeMethodPrice'];
    if (value is num) return value;
    return num.tryParse(value?.toString() ?? '') ?? 0;
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  int get _estimatedTotalPrice {
    final state = _cubit.state;
    return _nailVariantPrice +
        _shapeMethodPrice.round() +
        _cubit.extraServicesTotal(state.selectedExtraServices);
  }

  List<Map<String, dynamic>> get _discountBreakdown {
    final raw = _priceReview?['discountBreakdown'] ?? _priceReview?['discounts'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((d) => Map<String, dynamic>.from(d))
        .toList();
  }

  @override
  void initState() {
    super.initState();
    _cubit.loadSalons();
    _cubit.loadServices();
    _fetchNailVariantDetail();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _fetchNailVariantDetail() async {
    final id = _nailVariantId;
    if (id <= 0) return;
    try {
      final variant = await getIt<NailVariantRepository>().getNailVariantById(id);
      if (!mounted) return;
      setState(() => _nailVariantDetail = variant);
    } catch (e) {
      debugPrint('Failed to load nail variant detail: $e');
    }
  }

  Future<void> _reviewPrice() async {
    final state = _cubit.state;
    if (state.selectedBranch == null ||
        state.selectedDate == null ||
        state.selectedTime == null) return;

    setState(() => _isReviewingPrice = true);
    try {
      // Dùng cubit để tính giá nếu có method, nếu không dùng local estimate
      // (Giá chính xác sẽ từ API khi createBooking trả về)
    } finally {
      if (mounted) setState(() => _isReviewingPrice = false);
    }
  }

  void _handleBackAction() {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      context.pop();
    }
  }

  Future<void> _handleNextAction() async {
    final state = _cubit.state;

    if (_currentStep == 0 && state.selectedBranch == null) {
      _showSnackBar('Vui lòng chọn một chi nhánh salon!');
      return;
    }
    if (_currentStep == 1) {
      if (state.selectedExtraServices.contains(null)) {
        _showSnackBar('Vui long chon hoac xoa dich vu dang bo trong.');
        return;
      }
      final validServices = state.selectedExtraServices.whereType<String>().toList();
      if (widget.nailData == null && validServices.isEmpty) {
        _showSnackBar('Vui long chon it nhat mot dich vu.');
        return;
      }
    }
    if (_currentStep == 2) {
      if (state.selectedDate == null) {
        _showSnackBar('Vui lòng chọn ngày hẹn!');
        return;
      }
      if (state.selectedStylist == null && !state.noArtistSelected) {
        _showSnackBar('Vui lòng chọn thợ hoặc chọn "Không chọn thợ"!');
        return;
      }
      if (state.selectedTime == null) {
        _showSnackBar('Vui lòng chọn khung giờ!');
        return;
      }
      // Chỉ tạo hold mới nếu chưa có token (tránh reset timer khi back/forward)
      if (!state.noArtistSelected) {
        if (state.holdToken == null || !state.isHolding) {
          final held = await _cubit.holdSelectedSlot(nailVariantId: _nailVariantId);
          if (!held || !mounted) return;
        }
      }
    }

    if (_currentStep < 3) {
      if (_currentStep == 2) {
        _reviewPrice();
      }
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _executeBooking();
    }
  }

  void _executeBooking() {
    AuthGuard.check(context, () async {
      final state = _cubit.state;
      final promos = state.selectedPromotions.whereType<PromotionModel>().toList();
      final serviceIds = state.selectedExtraServices.whereType<String>().toList();

      try {
        final booking = await _cubit.createNailVariantBooking(
          nailVariantId: _nailVariantId,
          serviceIds: serviceIds,
          selectedPromotionIds:
              promos.isEmpty ? null : promos.map((p) => p.promotionId).toList(),
          shapeMethodConfigId: _shapeMethodConfigId,
        );

        if (!mounted) return;

        final formattedTime = state.selectedTime!.length == 5
            ? '${state.selectedTime}:00'
            : state.selectedTime!;

        context.go('/booking-success', extra: {
          'bookingId': booking['bookingId']?.toString() ?? '',
          'serviceName': widget.nailData?['name'] ?? 'Làm móng',
          'date': state.selectedDate,
          'time': formattedTime,
          'price': booking['price'] ?? _priceReview?['price'],
          'discount': booking['discount'] ?? _priceReview?['discount'],
          'totalPrice': booking['totalPrice'] ?? _priceReview?['totalPrice'],
          'discounts':
              booking['discounts'] ??
              booking['discountBreakdown'] ??
              _priceReview?['discounts'] ??
              _priceReview?['discountBreakdown'],
          'stylistName': state.noArtistSelected
              ? 'Tự động phân công'
              : (state.selectedStylist?['fullName'] ?? 'Bất kỳ'),
        });
      } catch (_) {
        // Lỗi đã được emit vào state.errorMessage và xử lý bởi BlocConsumer
      }
    });
  }

  void _showSnackBar(String msg) {
    final isError = msg.contains('chọn') ||
        msg.contains('Lỗi') ||
        msg.contains('hết') ||
        msg.contains('lỗi');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // BUILD
  // ══════════════════════════════════════════════════════════════

  @override
  Widget build(BuildContext context) {
    return BlocProvider<NailBookingCubit>(
      create: (_) => _cubit,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: _handleBackAction,
          ),
          title: const Text(
            'Dat Lich Hen',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          backgroundColor: Colors.white,
          elevation: 0,
          centerTitle: true,
        ),
        body: BlocConsumer<NailBookingCubit, NailBookingState>(
          listenWhen: (prev, curr) =>
              curr.errorMessage != null && prev.errorMessage != curr.errorMessage,
          listener: (context, state) {
            _showSnackBar(state.errorMessage!);
            if (state.errorMessage!.contains('hết') && _currentStep > 1) {
              _pageController.animateToPage(
                2,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
            _cubit.clearError();
          },
          builder: (context, state) {
            return Column(
              children: [
                _buildStepIndicator(),
                _buildHoldCountdownBanner(state),
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    onPageChanged: (idx) => setState(() => _currentStep = idx),
                    children: [
                      _buildSalonStep(state),
                      _buildServiceStep(state),
                      _buildScheduleStep(state),
                      _buildSummaryStep(state),
                    ],
                  ),
                ),
                _buildFooter(state),
              ],
            );
          },
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // STEP WIDGETS
  // ══════════════════════════════════════════════════════════════

  Widget _buildSalonStep(NailBookingState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: BranchSelectionList(
        salons: state.salons,
        isLoading: state.isLoadingSalons,
        selectedBranchId: state.selectedBranch?['salonId'],
        onBranchSelected: (dynamic branch) =>
            _cubit.selectBranch(Map<String, dynamic>.from(branch as Map)),
      ),
    );
  }

  Widget _buildServiceStep(NailBookingState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: BookingServiceSelection(
        nailData: widget.nailData,
        services: state.services,
        selectedExtraServices: state.selectedExtraServices,
        onChanged: _cubit.updateExtraServices,
      ),
    );
  }

  Widget _buildScheduleStep(NailBookingState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. Chọn ngày
          BookingDateSelection(
            selectedDate: state.selectedDate,
            onDateChanged: (date) => _cubit.selectDate(
              date: date,
              nailVariantId: _nailVariantId,
              shapeMethodConfigId: _shapeMethodConfigId,
              useSuggestedArtists: true,
            ),
          ),
          const SizedBox(height: 24),

          // 2. Chọn thợ (chỉ hiện sau khi chọn ngày)
          BookingStylistSelection(
            artists: state.artists,
            isLoading: state.isLoadingArtists,
            selectedStylistId: state.selectedStylist?['nailArtistId'],
            noArtistSelected: state.noArtistSelected,
            isDateSelected: state.isDateSelected,
            onStylistSelected: (artist) {
              if (artist != null) _cubit.selectStylist(artist);
            },
            onModeChanged: (isNoArtist) {
              if (isNoArtist) {
                _cubit.setNoArtistMode();
              } else {
                _cubit.setSelectArtistMode();
              }
            },
          ),
          const SizedBox(height: 24),

          // 3. Chọn giờ (chỉ hiện sau khi chọn thợ/mode)
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: state.canSelectTime
                ? BookingTimeSelection(
                    key: const ValueKey('time-visible'),
                    timeSlots: state.timeSlots,
                    isLoading: state.isLoadingTimes,
                    selectedTime: state.selectedTime,
                    canSelect: true,
                    selectedDate: state.selectedDate,
                    salonId: state.selectedBranch?['salonId']?.toString(),
                    artistId: state.noArtistSelected
                        ? null
                        : state.selectedStylist?['nailArtistId']?.toString(),
                    onTimeChanged: _cubit.selectTime,
                    onRefreshSlots: _cubit.refreshTimeSlots,
                  )
                : const SizedBox(key: ValueKey('time-hidden')),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStep(NailBookingState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBookingSummaryCard(state),
          const SizedBox(height: 24),
          _buildPromotionSelector(state),
          const SizedBox(height: 24),
          _buildPaymentDetails(state),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SUMMARY CARD
  // ══════════════════════════════════════════════════════════════

  Widget _buildBookingSummaryCard(NailBookingState state) {
    final time = state.selectedTime;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          _buildSummaryRow(
            Icons.storefront,
            'Chi nhanh',
            state.selectedBranch?['name']?.toString() ?? '',
          ),
          _buildSummaryRow(
            Icons.calendar_month,
            'Ngay hen',
            state.selectedDate == null
                ? ''
                : '${state.selectedDate!.day}/${state.selectedDate!.month}/${state.selectedDate!.year}',
          ),
          _buildSummaryRow(
            Icons.access_time,
            'Thoi gian',
            time == null ? '' : time.substring(0, 5),
          ),
          _buildSummaryRow(
            Icons.face,
            'Tho thuc hien',
            state.noArtistSelected
                ? 'Tu dong phan cong'
                : (state.selectedStylist?['fullName']?.toString() ?? ''),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PAYMENT DETAILS
  // ══════════════════════════════════════════════════════════════

  Widget _buildPaymentDetails(NailBookingState state) {
    final reviewTotal = _priceReview?['totalPrice'];
    final totalPrice = reviewTotal is num
        ? reviewTotal.round()
        : int.tryParse(reviewTotal?.toString() ?? '') ?? _estimatedTotalPrice;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Chi tiet thanh toan',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              if (_isReviewingPrice)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (widget.nailData != null) _buildNailVariantPaymentItem(),
          ...state.selectedExtraServices.whereType<String>().map((serviceId) {
            return _buildPaymentRow(
              'Dich vu them: ${_cubit.serviceNameById(serviceId)}',
              _cubit.servicePriceById(serviceId),
              muted: true,
            );
          }),
          const Divider(height: 24),
          _buildPaymentRow('Tam tinh', _estimatedTotalPrice, strong: true),
          ..._discountBreakdown.map(_buildDiscountRow),
          const Divider(height: 16),
          _buildPaymentRow(
            'Tong cong',
            totalPrice,
            strong: true,
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _buildNailVariantPaymentItem() {
    final variant = _nailVariantDetail;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildPaymentRow(
            widget.nailData!['name']?.toString() ?? 'Bien the nail',
            _nailVariantPrice + _shapeMethodPrice.round(),
          ),
          if (variant != null) ...[
            const SizedBox(height: 4),
            if (variant.nailSurface != null)
              _buildVariantDetailLine(
                'Be mat ${variant.nailSurface!.name}',
                variant.nailSurface!.price,
              ),
            if (variant.nailShape != null)
              _buildVariantDetailLine(
                _shapeMethodName ?? variant.nailShape!.name,
                _shapeMethodPrice,
              ),
            ...variant.nailComponents.map((component) {
              final detail = component.component;
              return _buildVariantDetailLine(
                detail?.name ?? 'Thanh phan nail',
                detail?.price ?? 0,
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _buildPaymentRow(
    String label,
    num price, {
    bool strong = false,
    bool muted = false,
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                label,
                style: TextStyle(
                  fontSize: highlight ? 16 : 14,
                  color: muted ? Colors.grey : AppColors.textPrimary,
                  fontWeight: strong ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          ),
          Text(
            PriceFormatter.format(price),
            style: TextStyle(
              fontWeight: strong ? FontWeight.bold : FontWeight.w600,
              color: highlight ? AppColors.primary : AppColors.textPrimary,
              fontSize: highlight ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVariantDetailLine(String label, num price) {
    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Text(
                label,
                style: const TextStyle(fontSize: 13, color: Colors.grey),
              ),
            ),
          ),
          Text(
            PriceFormatter.format(price),
            style: const TextStyle(
              fontSize: 13,
              color: Colors.grey,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiscountRow(Map<String, dynamic> discount) {
    final name = discount['name']?.toString() ?? 'Giam gia';
    final amount = discount['amount'] ?? 0;
    final amountDisplay = discount['amountDisplay']?.toString();
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Text(
              name,
              style: const TextStyle(fontSize: 14, color: Colors.green),
            ),
          ),
          Text(
            amountDisplay?.isNotEmpty == true
                ? amountDisplay!
                : '-${PriceFormatter.format(amount)}',
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: Colors.green,
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // PROMOTION SELECTOR
  // ══════════════════════════════════════════════════════════════

  Widget _buildPromotionSelector(NailBookingState state) {
    final selectedPromotions =
        state.selectedPromotions.whereType<PromotionModel>().toList();
    final selectedLabel = selectedPromotions.isEmpty
        ? 'Khong ap dung khuyen mai'
        : selectedPromotions.first.name;

    // Dùng PromotionModel list từ cubit
    // promotions cần được load vào state — hiện chưa có trong NailBookingState
    // Tạm thời dùng list rỗng, có thể mở rộng sau
    final promotions = <PromotionModel>[];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer_outlined, color: AppColors.primary),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Khuyen mai',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      selectedLabel,
                      style: const TextStyle(color: Colors.grey, fontSize: 13),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: () =>
                    setState(() => _isPromotionExpanded = !_isPromotionExpanded),
                icon: Icon(
                  _isPromotionExpanded
                      ? Icons.keyboard_arrow_up
                      : Icons.keyboard_arrow_down,
                ),
              ),
            ],
          ),
          if (_isPromotionExpanded) ...[
            const SizedBox(height: 8),
            if (promotions.isEmpty)
              const Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  'Khong co khuyen mai kha dung.',
                  style: TextStyle(color: Colors.grey, fontSize: 13),
                ),
              ),
            ...promotions.map(
              (promotion) => CheckboxListTile(
                value: selectedPromotions
                    .any((p) => p.promotionId == promotion.promotionId),
                onChanged: (checked) {
                  final current = List<dynamic>.from(state.selectedPromotions);
                  if (checked == true) {
                    current.add(promotion);
                  } else {
                    current.removeWhere(
                      (p) =>
                          p is PromotionModel &&
                          p.promotionId == promotion.promotionId,
                    );
                  }
                  _cubit.selectPromotions(current);
                },
                title: Text(promotion.name),
                subtitle: Text(
                  promotion.description.isNotEmpty
                      ? '${promotion.discountLabel} - ${promotion.description}'
                      : promotion.discountLabel,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                dense: true,
                contentPadding: EdgeInsets.zero,
                activeColor: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════
  // SHARED WIDGETS
  // ══════════════════════════════════════════════════════════════

  Widget _buildSummaryRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHoldCountdownBanner(NailBookingState state) {
    if (!state.isHolding) return const SizedBox.shrink();
    final secs = state.holdRemainingSeconds;
    final min = (secs ~/ 60).toString().padLeft(2, '0');
    final sec = (secs % 60).toString().padLeft(2, '0');
    final isUrgent = secs <= 60;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: isUrgent ? Colors.red.shade600 : Colors.orange.shade700,
      child: Row(
        children: [
          const Icon(Icons.lock_clock, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isUrgent
                  ? 'Chỗ có thể bị hủy sau $min:$sec giây!'
                  : 'Slot đang được giữ chỗ cho bạn – còn $min:$sec để hoàn tất',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      color: Colors.white,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(4, (index) {
          final isCompleted = index <= _currentStep;
          return Row(
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor:
                    isCompleted ? AppColors.primary : Colors.grey.shade300,
                child: Text(
                  '${index + 1}',
                  style: const TextStyle(color: Colors.white, fontSize: 11),
                ),
              ),
              if (index < 3)
                Container(
                  width: 30,
                  height: 2,
                  color: index < _currentStep
                      ? AppColors.primary
                      : Colors.grey.shade300,
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildFooter(NailBookingState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, -5),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          if (_currentStep > 0)
            OutlinedButton(
              onPressed: state.isSubmitting ? null : _handleBackAction,
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 15,
                ),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Quay lai',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
          else
            const SizedBox.shrink(),
          ElevatedButton(
            onPressed: state.isSubmitting ? null : _handleNextAction,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: state.isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : Text(
                    _currentStep == 3 ? 'Xac nhan dat lich' : 'Tiep tuc',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
