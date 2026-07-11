import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../../../core/utils/price_formatter.dart';

import '../../data/models/promotion_model.dart';
import '../cubit/nail_booking_cubit.dart';
import '../widgets/branch_selection_list.dart';
import '../widgets/booking_service_selection.dart';
import '../widgets/booking_date_selection.dart';
import '../widgets/booking_seat_selection.dart';
import '../widgets/booking_promotion_sheet.dart';
import '../widgets/booking_stylist_selection.dart';
import '../widgets/booking_time_selection.dart';

/// Entry point: bọc page trong BlocProvider.
class NailBookingPage extends StatelessWidget {
  final Map<String, dynamic>? nailData;

  const NailBookingPage({super.key, this.nailData});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NailBookingCubit(),
      child: _NailBookingView(nailData: nailData),
    );
  }
}

class _NailBookingView extends StatefulWidget {
  final Map<String, dynamic>? nailData;

  const _NailBookingView({this.nailData});

  @override
  State<_NailBookingView> createState() => _NailBookingViewState();
}

class _NailBookingViewState extends State<_NailBookingView> {
  final PageController _pageController = PageController();
  int _currentStep = 0;

  int get _nailVariantId =>
      int.tryParse(widget.nailData?['id']?.toString() ?? '0') ?? 0;

  int get _nailVariantPrice {
    final price = widget.nailData?['price'];
    if (price is num) return price.round();
    return int.tryParse(price?.toString() ?? '') ?? 0;
  }

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

  void _handleBackAction() {
    if (_currentStep > 0) {
      _pageController.previousPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      context.pop();
    }
  }

  Future<void> _handleNextAction(NailBookingState state) async {
    final cubit = context.read<NailBookingCubit>();

    if (_currentStep == 0 && state.selectedBranch == null) {
      _showSnackBar('Vui lòng chọn một chi nhánh salon!');
      return;
    }
    if (_currentStep == 1) {
      if (state.selectedExtraServices.contains(null)) {
        _showSnackBar(
            'Có ô dịch vụ đang bị bỏ trống. Vui lòng chọn hoặc xóa nó đi!');
        return;
      }
      final validServices =
          state.selectedExtraServices.whereType<String>().toList();
      if (widget.nailData == null && validServices.isEmpty) {
        _showSnackBar('Vui lòng chọn ít nhất 1 dịch vụ để tiếp tục!');
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
      // Giữ chỗ trước khi sang trang xác nhận
      final held = await cubit.holdSelectedSlot(nailVariantId: _nailVariantId);
      if (!held || !mounted) return; // errorMessage đã được emit và hiện qua BlocConsumer
    }

    if (_currentStep < 3) {
      _pageController.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
    } else {
      _executeBooking(state, cubit);
    }
  }


  Future<void> _executeBooking(
      NailBookingState state, NailBookingCubit cubit) async {
    AuthGuard.check(context, () async {
      final promos =
          state.selectedPromotions.whereType<PromotionModel>().toList();
      final serviceIds =
          state.selectedExtraServices.whereType<String>().toList();
      final formattedTime = state.selectedTime!.length == 5
          ? '${state.selectedTime}:00'
          : state.selectedTime!;

      try {
        final booking = await cubit.createNailVariantBooking(
          nailVariantId: _nailVariantId,
          serviceIds: serviceIds,
          selectedPromotionIds: promos.isEmpty
              ? null
              : promos.map((p) => p.promotionId).toList(),
        );

        if (!mounted) return;

        context.go('/booking-success', extra: {
          'bookingId': booking['bookingId']?.toString() ?? '',
          'serviceName': widget.nailData?['name'] ?? 'Làm móng',
          'date': state.selectedDate,
          'time': formattedTime,
          'stylistName': state.noArtistSelected
              ? 'Tự động phân công'
              : (state.selectedStylist?['fullName'] ?? 'Bất kỳ'),
        });
      } catch (_) {
        // Error đã được emit vào state.errorMessage và xử lý bởi BlocConsumer
      }
    });
  }


  void _showSnackBar(String msg) {
    final isError = msg.contains('chọn') || msg.contains('Lỗi') || msg.contains('hết');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: _handleBackAction),
        title: const Text('Đặt Lịch Hẹn',
            style: TextStyle(
                fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
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
            _pageController.animateToPage(2,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut);
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
                    // ── BƯỚC 1: CHỌN SALON ──────────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: BranchSelectionList(
                        salons: state.salons,
                        isLoading: state.isLoadingSalons,
                        selectedBranchId: state.selectedBranch?['salonId'],
                        onBranchSelected: (dynamic branch) =>
                            cubit.selectBranch(
                                Map<String, dynamic>.from(branch as Map)),
                      ),
                    ),

                    // ── BƯỚC 2: CHỌN GHẾ (Đã ẩn) ────────────────────────────────
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

                    // ── BƯỚC 3: CHỌN DỊCH VỤ ───────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: BookingServiceSelection(
                        nailData: widget.nailData,
                        services: state.services,
                        selectedExtraServices: state.selectedExtraServices,
                        onChanged: cubit.updateExtraServices,
                      ),
                    ),

                    // ── BƯỚC 4: NGÀY → THỢ → GIỜ ───────────────────────
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
                              nailVariantId: _nailVariantId,
                              useSuggestedArtists: true,
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
                                    salonId: state.selectedBranch?['salonId']?.toString(),
                                    artistId: state.noArtistSelected ? null : state.selectedStylist?['nailArtistId']?.toString(),
                                    onTimeChanged: cubit.selectTime,
                                    onRefreshSlots: cubit.refreshTimeSlots,
                                  )
                                : const SizedBox(key: ValueKey('time-hidden')),
                          ),
                        ],
                      ),
                    ),

                    // ── BƯỚC 5: SUMMARY ─────────────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.all(20),
                      child: _buildSummaryStep(context, state, cubit),
                    ),
                  ],
                ),
              ),
              _buildFooter(state),
            ],
          );
        },
      ),
    );
  }

  // ── SUMMARY STEP ────────────────────────────────────────────────────────────
  Widget _buildSummaryStep(
      BuildContext context, NailBookingState state, NailBookingCubit cubit) {
    final promos =
        state.selectedPromotions.whereType<PromotionModel>().toList();
    final extraTotal =
        cubit.extraServicesTotal(state.selectedExtraServices);
    final subtotal = _nailVariantPrice + extraTotal;
    final discount = cubit.discountAmount(subtotal: subtotal, promotions: promos);
    final finalPrice = (subtotal - discount).clamp(0, double.maxFinite).toInt();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Xác nhận thông tin đặt lịch',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
              _buildSummaryRow(Icons.storefront, 'Chi nhánh',
                  state.selectedBranch?['name'] ?? ''),
              // _buildSummaryRow(Icons.chair, 'Ghế',
              //     state.selectedSeatId != null
              //         ? 'Ghế ${state.selectedSeatId!.split('_').last}'
              //         : ''),
              _buildSummaryRow(
                  Icons.calendar_month,
                  'Ngày hẹn',
                  state.selectedDate != null
                      ? '${state.selectedDate!.day}/${state.selectedDate!.month}/${state.selectedDate!.year}'
                      : ''),
              _buildSummaryRow(
                  Icons.access_time,
                  'Thời gian',
                  state.selectedTime != null
                      ? state.selectedTime!.substring(0, 5)
                      : ''),
              _buildSummaryRow(
                  Icons.face,
                  'Thợ thực hiện',
                  state.noArtistSelected
                      ? 'Tự động phân công'
                      : (state.selectedStylist?['fullName'] ?? '')),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _buildPromotionSelector(context, state, cubit),
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
              const Text('Chi tiết thanh toán',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              if (widget.nailData != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          'Biến thể Nail: ${widget.nailData!['name']}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                      Text(
                        PriceFormatter.format(widget.nailData?['price']),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ...state.selectedExtraServices.whereType<String>().map((id) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 12.0),
                          child: Text(
                            'Dịch vụ thêm: ${cubit.serviceNameById(id)}',
                            style: const TextStyle(
                                fontSize: 14, color: Colors.grey),
                          ),
                        ),
                      ),
                      Text(
                        PriceFormatter.format(cubit.servicePriceById(id)),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                );
              }),
              const Divider(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tạm tính:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    PriceFormatter.format(subtotal),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ],
              ),
              if (discount > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Giảm giá:',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.green)),
                      Text(
                        '-${PriceFormatter.format(discount)}',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                            fontSize: 16),
                      ),
                    ],
                  ),
                ),
              const Divider(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Tổng cộng:',
                      style: TextStyle(fontWeight: FontWeight.bold)),
                  Text(
                    PriceFormatter.format(finalPrice),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                        fontSize: 18),
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
      BuildContext context, NailBookingState state, NailBookingCubit cubit) {
    final promos =
        state.selectedPromotions.whereType<PromotionModel>().toList();
    final hasPromos = promos.isNotEmpty;
    return GestureDetector(
      onTap: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => BookingPromotionSheet(
            selectedPromotions: promos,
            onConfirm: (list) => cubit.selectPromotions(list),
          ),
        );
      },
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
            Icon(Icons.local_offer_outlined,
                size: 18,
                color: hasPromos ? AppColors.primary : Colors.grey.shade500),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                hasPromos
                    ? 'Đã chọn ${promos.length} khuyến mãi'
                    : 'Chọn voucher / khuyến mãi',
                style: TextStyle(
                  color: hasPromos ? AppColors.primary : Colors.grey.shade600,
                  fontWeight:
                      hasPromos ? FontWeight.w600 : FontWeight.normal,
                  fontSize: 14,
                ),
              ),
            ),
            Icon(Icons.chevron_right,
                color: hasPromos ? AppColors.primary : Colors.grey.shade400),
          ],
        ),
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
              Text(title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary)),
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
                  color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
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
                child: Text('${index + 1}',
                    style: const TextStyle(color: Colors.white, fontSize: 11)),
              ),
              if (index < 3)
                Container(
                    width: 30,
                    height: 2,
                    color: index < _currentStep
                        ? AppColors.primary
                        : Colors.grey.shade300),
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
              offset: const Offset(0, -5))
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
                    horizontal: 24, vertical: 15),
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              child: const Text('Quay lại',
                  style: TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.bold)),
            )
          else
            const SizedBox.shrink(),
          ElevatedButton(
            onPressed: state.isSubmitting
                ? null
                : () => _handleNextAction(state),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(
                  horizontal: 32, vertical: 15),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
            ),
            child: state.isSubmitting
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2))
                : Text(
                    _currentStep == 3 ? 'Xác nhận Đặt lịch' : 'Tiếp tục',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
