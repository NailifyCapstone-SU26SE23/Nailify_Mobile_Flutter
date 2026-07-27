import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/duration_formatter.dart';

import '../../data/models/promotion_model.dart';
import '../cubit/nail_booking_cubit.dart';
import '../widgets/branch_selection_list.dart';
import '../widgets/booking_service_selection.dart';
import '../widgets/booking_date_selection.dart';
import '../widgets/booking_promotion_sheet.dart';
import '../widgets/booking_stylist_selection.dart';
import '../widgets/booking_time_selection.dart';

/// Entry point: bọc page trong BlocProvider.
class ServiceBookingPage extends StatelessWidget {
  final Map<String, dynamic> baseService;

  const ServiceBookingPage({super.key, required this.baseService});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NailBookingCubit(),
      child: _ServiceBookingView(baseService: baseService),
    );
  }
}

class _ServiceBookingView extends StatefulWidget {
  final Map<String, dynamic> baseService;

  const _ServiceBookingView({required this.baseService});

  @override
  State<_ServiceBookingView> createState() => _ServiceBookingViewState();
}

class _ServiceBookingViewState extends State<_ServiceBookingView> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  @override
  void initState() {
    super.initState();
    final cubit = context.read<NailBookingCubit>();
    cubit.loadSalons();
    cubit.loadServices();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  // ── Dịch vụ gốc helpers ──────────────────────────────────────────────────
  String get _baseServiceId =>
      widget.baseService['serviceId']?.toString() ?? '';
  String get _baseServiceName =>
      widget.baseService['name']?.toString() ?? 'Dịch vụ';
  int get _baseServicePrice =>
      (widget.baseService['price'] as num?)?.toInt() ?? 0;
  int get _baseServiceDuration =>
      (widget.baseService['duration'] as num?)?.toInt() ?? 0;

  /// Gộp dịch vụ gốc + dịch vụ thêm (hỗ trợ qty x2, x3)
  Map<String, int> _groupedServicesMap(List<String?> extraServices) {
    final map = <String, int>{};
    if (_baseServiceId.isNotEmpty) map[_baseServiceId] = 1;
    for (final id in extraServices.whereType<String>()) {
      map[id] = (map[id] ?? 0) + 1;
    }
    return map;
  }

  // ── Navigation ────────────────────────────────────────────────────────────
  Future<void> _handleNextAction(
    NailBookingState state,
    NailBookingCubit cubit,
  ) async {
    if (_currentStep == 0 && state.selectedBranch == null) {
      _showSnackBar('Vui lòng chọn 1 chi nhánh!');
      return;
    }
    if (_currentStep == 1 && state.selectedExtraServices.contains(null)) {
      _showSnackBar('Có ô dịch vụ đang bị bỏ trống!');
      return;
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
          final held = await cubit.holdSelectedSlot();
          if (!held || !mounted) return;
        }
      }
    }

    if (_currentStep < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _executeBooking(state, cubit);
    }
  }

  Future<void> _executeBooking(
    NailBookingState state,
    NailBookingCubit cubit,
  ) async {
    final promos = state.selectedPromotions
        .whereType<PromotionModel>()
        .toList();
    final grouped = _groupedServicesMap(state.selectedExtraServices);
    final formattedDate = cubit.formatBookingDate(state.selectedDate!);
    final formattedTime = state.selectedTime!.length == 5
        ? '${state.selectedTime}:00'
        : state.selectedTime!;

    final payload = {
      'salonId': state.selectedBranch!['salonId'],
      'bookingDate': formattedDate,
      'startTime': formattedTime,
      'nailArtistId': state.noArtistSelected
          ? null
          : state.selectedStylist!['nailArtistId'],
      'holdToken': null,
      'bookingItems': grouped.entries
          .map(
            (e) => {
              'nailVariantId': null,
              'serviceId': e.key,
              'customerNailId': null,
              'quantity': e.value,
            },
          )
          .toList(),
    };

    try {
      final response = await cubit.createServiceBookingFromState(
        payload: payload,
        selectedPromotionIds: promos.isEmpty
            ? null
            : promos.map((p) => p.promotionId).toList(),
      );
      if (!mounted) return;
      context.go(
        '/booking-success',
        extra: {
          'bookingId': response['bookingId']?.toString() ?? '',
          'serviceName': _baseServiceName,
          'date': state.selectedDate,
          'time': formattedTime,
          'stylistName': state.noArtistSelected
              ? 'Tự động phân công'
              : state.selectedStylist!['fullName'],
        },
      );
    } catch (_) {
      // Error đã được emit vào state.errorMessage và xử lý bởi BlocConsumer
    }
  }

  void _showSnackBar(String msg) {
    final isError =
        msg.contains('chọn') || msg.contains('Lỗi') || msg.contains('hết');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  // ── Price helpers ─────────────────────────────────────────────────────────
  int _totalPrice(NailBookingState state, NailBookingCubit cubit) {
    final grouped = _groupedServicesMap(state.selectedExtraServices);
    int total = 0;
    grouped.forEach((id, qty) {
      if (id == _baseServiceId) {
        total += _baseServicePrice * qty;
      } else {
        total += cubit.servicePriceById(id) * qty;
      }
    });
    return total;
  }

  Map<String, dynamic>? _getServiceDetail(String id, NailBookingCubit cubit) {
    if (id == _baseServiceId) return widget.baseService;
    final matches = cubit.availableServices.where(
      (s) => cubit.serviceIdOf(s) == id,
    );
    return matches.isNotEmpty ? matches.first : null;
  }

  @override
  Widget build(BuildContext context) {
    final dummyNailData = {'name': 'Danh sách dịch vụ thêm', 'price': 0};

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.primaryDark,
          ),
          onPressed: () => _currentStep > 0
              ? _pageController.previousPage(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                )
              : context.pop(),
        ),
        title: const Text(
          'Đặt Lịch Dịch Vụ',
          style: TextStyle(
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
            color: AppColors.primaryDark,
          ),
        ),
        backgroundColor: const Color(0xFFFDFBF7),
        elevation: 0,
        scrolledUnderElevation: 0,
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
          context.read<NailBookingCubit>().clearError();
        },
        builder: (context, state) {
          final cubit = context.read<NailBookingCubit>();
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
                    // ── STEP 0: SALON ──────────────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: BranchSelectionList(
                        salons: state.salons,
                        isLoading: state.isLoadingSalons,
                        selectedBranchId: state.selectedBranch?['salonId'],
                        onBranchSelected: (dynamic branch) =>
                            cubit.selectBranch(
                              Map<String, dynamic>.from(branch as Map),
                            ),
                      ),
                    ),

                    // ── STEP 1: GHẾ (Đã ẩn) ────────────────────────────────────
                    /*
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: BookingSeatSelection(
                        selectedSeatId: state.selectedSeatId,
                        onSeatSelected: (String? id) {
                          if (id != null) cubit.selectSeat(id);
                        },
                      ),
                    ),
                    */

                    // ── STEP 2: DỊCH VỤ ───────────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Dịch vụ đã chọn',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildBaseServiceCard(),
                          const SizedBox(height: 24),
                          const Divider(),
                          BookingServiceSelection(
                            nailData: dummyNailData,
                            services: state.services,
                            selectedExtraServices: state.selectedExtraServices,
                            onChanged: cubit.updateExtraServices,
                          ),
                        ],
                      ),
                    ),

                    // ── STEP 3: NGÀY → THỢ → GIỜ ─────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // 1. Chọn ngày
                          BookingDateSelection(
                            selectedDate: state.selectedDate,
                            onDateChanged: (date) => cubit.selectDate(
                              date: date,
                              nailVariantId: 0,
                              useSuggestedArtists: false,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 2. Chọn thợ (chỉ hiện sau khi chọn ngày)
                          BookingStylistSelection(
                            artists: state.artists,
                            isLoading: state.isLoadingArtists,
                            selectedStylistId:
                                state.selectedStylist?['nailArtistId'],
                            noArtistSelected: state.noArtistSelected,
                            isDateSelected: state.isDateSelected,
                            onStylistSelected: (artist) {
                              if (artist != null) cubit.selectStylist(artist);
                            },
                            onModeChanged: (isNoArtist) {
                              if (isNoArtist) {
                                cubit.setNoArtistMode();
                              } else {
                                cubit.setSelectArtistMode();
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
                                    salonId: state.selectedBranch?['salonId']
                                        ?.toString(),
                                    artistId: state.noArtistSelected
                                        ? null
                                        : state.selectedStylist?['nailArtistId']
                                              ?.toString(),
                                    onTimeChanged: cubit.selectTime,
                                    onRefreshSlots: cubit.refreshTimeSlots,
                                  )
                                : const SizedBox(key: ValueKey('time-hidden')),
                          ),
                        ],
                      ),
                    ),

                    // ── STEP 4: SUMMARY ───────────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildSummaryStep(context, state, cubit),
                    ),
                  ],
                ),
              ),
              _buildFooter(state, cubit),
            ],
          );
        },
      ),
    );
  }

  // ── SUMMARY ────────────────────────────────────────────────────────────────
  Widget _buildSummaryStep(
    BuildContext context,
    NailBookingState state,
    NailBookingCubit cubit,
  ) {
    final promos = state.selectedPromotions
        .whereType<PromotionModel>()
        .toList();
    final subtotal = _totalPrice(state, cubit);
    final discount = cubit.discountAmount(
      subtotal: subtotal,
      promotions: promos,
    );
    final finalPrice = (subtotal - discount).clamp(0, double.maxFinite).toInt();
    final grouped = _groupedServicesMap(state.selectedExtraServices);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Xác nhận thông tin',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        Container(
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
                'Chi nhánh',
                state.selectedBranch?['name'] ?? '',
              ),
              // _buildSummaryRow(
              //     Icons.chair,
              //     'Ghế',
              //     state.selectedSeatId != null
              //         ? 'Ghế ${state.selectedSeatId!.split('_').last}'
              //         : ''),
              _buildSummaryRow(
                Icons.calendar_month,
                'Ngày hẹn',
                state.selectedDate != null
                    ? '${state.selectedDate!.day}/${state.selectedDate!.month}/${state.selectedDate!.year}'
                    : '',
              ),
              _buildSummaryRow(
                Icons.access_time,
                'Thời gian',
                state.selectedTime ?? '',
              ),
              _buildSummaryRow(
                Icons.face,
                'Thợ thực hiện',
                state.noArtistSelected
                    ? 'Tự động phân công'
                    : (state.selectedStylist?['fullName'] ?? ''),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Chi tiết thanh toán',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ...grouped.entries.map((entry) {
                final svc = _getServiceDetail(entry.key, cubit);
                final name = svc?['name'] ?? cubit.serviceNameById(entry.key);
                final price =
                    (svc?['price'] as num?)?.toInt() ??
                    cubit.servicePriceById(entry.key);
                final qty = entry.value;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: Text(
                            '${qty}x $name',
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ),
                      Text(
                        PriceFormatter.format(price * qty),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 24),
              _buildPromotionSelector(context, state, cubit),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tạm tính:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    PriceFormatter.format(subtotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              if (discount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Giảm giá:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      Text(
                        '-${PriceFormatter.format(discount)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng cộng:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  Text(
                    PriceFormatter.format(finalPrice),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 18,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPromotionSelector(
    BuildContext context,
    NailBookingState state,
    NailBookingCubit cubit,
  ) {
    final promos = state.selectedPromotions
        .whereType<PromotionModel>()
        .toList();
    final hasPromos = promos.isNotEmpty;
    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BookingPromotionSheet(
          selectedPromotions: promos,
          onConfirm: (list) => cubit.selectPromotions(list),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: hasPromos
              ? AppColors.primary.withOpacity(0.06)
              : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: hasPromos
                ? AppColors.primary.withOpacity(0.5)
                : Colors.grey.shade300,
          ),
        ),
        child: Row(
          children: [
            Icon(
              Icons.local_offer_outlined,
              size: 18,
              color: hasPromos ? AppColors.primary : Colors.grey.shade500,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasPromos
                    ? 'Đã chọn ${promos.length} khuyến mãi'
                    : 'Chọn voucher / khuyến mãi',
                style: TextStyle(
                  color: hasPromos ? AppColors.primary : Colors.grey.shade600,
                  fontWeight: hasPromos ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: hasPromos ? AppColors.primary : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBaseServiceCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.spa_outlined,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _baseServiceName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  DurationFormatter.format(_baseServiceDuration),
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ),
          Text(
            PriceFormatter.format(_baseServicePrice),
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(IconData icon, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppColors.primary),
          const SizedBox(width: 12),
          Column(
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
    final steps = ['Chi nhánh', 'Dịch vụ', 'Thời gian', 'Xác nhận'];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: List.generate(steps.length, (index) {
          final isActive = index == _currentStep;
          final isCompleted = index < _currentStep;

          return Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 250),
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: isCompleted
                              ? AppColors.primary
                              : isActive
                              ? AppColors.primary
                              : Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isCompleted || isActive
                                ? AppColors.primary
                                : Colors.grey.shade300,
                            width: 2,
                          ),
                        ),
                        alignment: Alignment.center,
                        child: isCompleted
                            ? const Icon(
                                Icons.check_rounded,
                                color: Colors.white,
                                size: 14,
                              )
                            : Text(
                                '${index + 1}',
                                style: TextStyle(
                                  color: isCompleted || isActive
                                      ? Colors.white
                                      : Colors.grey.shade500,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        steps[index],
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: isActive
                              ? FontWeight.bold
                              : FontWeight.w500,
                          color: isActive
                              ? AppColors.primary
                              : isCompleted
                              ? AppColors.textPrimary
                              : Colors.grey.shade400,
                        ),
                      ),
                    ],
                  ),
                ),
                if (index < steps.length - 1)
                  Container(
                    width: 20,
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 18),
                    decoration: BoxDecoration(
                      color: isCompleted
                          ? AppColors.primary
                          : Colors.grey.shade200,
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
    );
  }

  Widget _buildFooter(NailBookingState state, NailBookingCubit cubit) {
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
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ElevatedButton(
            onPressed: state.isSubmitting
                ? null
                : () => _handleNextAction(state, cubit),
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
                    _currentStep == 3 ? 'Xác nhận Đặt lịch' : 'Tiếp tục',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ],
      ),
    );
  }
}
