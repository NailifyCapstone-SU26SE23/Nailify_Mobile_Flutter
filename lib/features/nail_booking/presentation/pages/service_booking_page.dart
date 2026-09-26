import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../generated/l10n.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/utils/duration_formatter.dart';

import '../../../../core/utils/auth_guard.dart';
import '../../data/datasources/booking_api_service.dart';
import '../../data/datasources/payment_api_service.dart';
import '../../data/models/wallet_voucher_model.dart';
import '../cubit/nail_booking_cubit.dart';
import '../widgets/branch_selection_list.dart';
import '../widgets/artist_selection_list.dart';
import '../widgets/booking_service_selection.dart';
import '../widgets/booking_date_selection.dart';
import '../widgets/booking_promotion_sheet.dart';
import '../widgets/booking_time_selection.dart';
import '../widgets/payment_detail_table.dart';

import '../widgets/sleek_booking_step_indicator.dart';

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
  final BookingApiService _apiService = BookingApiService();
  final PaymentApiService _paymentApiService = PaymentApiService();
  final PageController _pageController = PageController();
  int _currentStep = 0;
  bool _useWalletBalance = false;
  double? _walletAvailableBalance;
  bool _isLoadingWallet = false;

  bool _isReviewingPrice = false;
  String? _priceReviewKey;
  String? _inFlightPriceReviewKey;
  Future<void>? _inFlightPriceReview;
  Map<String, dynamic>? _priceReview;

  String get _priceReviewRequestKey {
    final state = context.read<NailBookingCubit>().state;
    final extraServices =
        state.selectedExtraServices.whereType<String>().toList()..sort();
    final promos =
        state.selectedPromotions
            .whereType<WalletVoucherModel>()
            .map((p) => p.promotionId)
            .toList()
          ..sort();
    final dateStr = state.selectedDate != null
        ? context.read<NailBookingCubit>().formatBookingDate(
            state.selectedDate!,
          )
        : '';
    final timeStr = state.selectedTime ?? '';
    final artistIdStr = state.noArtistSelected
        ? ''
        : (state.selectedStylist?['nailArtistId']?.toString() ?? '');
    final branchIdStr = state.selectedBranch?['salonId']?.toString() ?? '';

    return [
      branchIdStr,
      dateStr,
      timeStr,
      artistIdStr,
      _baseServiceId,
      extraServices.join(','),
      promos.join(','),
    ].join('|');
  }

  List<Map<String, dynamic>> get _discountBreakdown {
    final raw =
        _priceReview?['discountBreakdown'] ?? _priceReview?['discounts'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((discount) => Map<String, dynamic>.from(discount))
        .toList();
  }

  Future<void> _reviewPrice() async {
    final requestKey = _priceReviewRequestKey;
    if (_priceReview != null && _priceReviewKey == requestKey) return;
    if (_inFlightPriceReviewKey == requestKey && _inFlightPriceReview != null) {
      return _inFlightPriceReview;
    }

    final cubit = context.read<NailBookingCubit>();
    final state = cubit.state;
    final extraServices = state.selectedExtraServices
        .whereType<String>()
        .toList();
    final serviceIds = [_baseServiceId, ...extraServices];

    final promos = state.selectedPromotions
        .whereType<WalletVoucherModel>()
        .map((p) => p.promotionId)
        .toList();

    final dateStr = state.selectedDate != null
        ? cubit.formatBookingDate(state.selectedDate!)
        : '';
    final timeStr = state.selectedTime != null
        ? (state.selectedTime!.length == 5
              ? '${state.selectedTime}:00'
              : state.selectedTime!)
        : '';
    final artistIdStr = state.noArtistSelected
        ? null
        : state.selectedStylist?['nailArtistId']?.toString();
    final salonIdStr = state.selectedBranch?['salonId']?.toString() ?? '';

    if (mounted) setState(() => _isReviewingPrice = true);
    final reviewFuture = () async {
      try {
        final review = await _apiService.reviewBookingPrice(
          salonId: salonIdStr,
          bookingDate: dateStr,
          startTime: timeStr,
          artistId: artistIdStr,
          nailVariantId: 0,
          serviceIds: serviceIds,
          selectedPromotionIds: promos.isEmpty ? null : promos,
        );

        if (_priceReviewRequestKey != requestKey) return;
        if (mounted) {
          setState(() {
            _priceReview = review;
            _priceReviewKey = requestKey;
          });
        }
      } catch (e) {
        debugPrint('reviewBookingPrice error: $e');
      }
    }();

    _inFlightPriceReviewKey = requestKey;
    _inFlightPriceReview = reviewFuture;

    try {
      await reviewFuture;
    } finally {
      if (_inFlightPriceReviewKey == requestKey) {
        _inFlightPriceReviewKey = null;
        _inFlightPriceReview = null;
        if (mounted) setState(() => _isReviewingPrice = false);
      }
    }
  }

  Widget _buildDiscountInvoiceRow(Map<String, dynamic> discount) {
    final name = discount['name']?.toString() ?? 'Ưu đãi';
    String? description = discount['description']?.toString();
    if (description == null || description.isEmpty) {
      if (name == 'Perfect Match') {
        description = 'Giảm 15% tất cả thiết kế móng dòng SkinTone';
      }
    }
    final isAutoApplied = discount['isAutoApplied'] == true;
    final amount = discount['amount'];
    final amountDisplay = discount['amountDisplay']?.toString();
    final rawDisplay = (amountDisplay?.isNotEmpty == true)
        ? amountDisplay!
        : (amount != null ? PriceFormatter.format(amount) : '');

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Flexible(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontSize: 13.5,
                          color: Colors.grey.shade800,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isAutoApplied) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE02B6D).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: const Color(0xFFE02B6D).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Text(
                          'Tự động áp dụng',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFE02B6D),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                rawDisplay.startsWith('-') ? rawDisplay : '-$rawDisplay',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13.5,
                  color: Color(0xFFE02B6D),
                ),
              ),
            ],
          ),
          if (description != null && description.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              description,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFFE02B6D),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }

  List<Map<String, dynamic>> get _bookingSteps => [
    {
      'title': S.of(context).bookingStepSelectSalon,
      'icon': Icons.storefront_rounded,
    },
    {'title': S.of(context).bookingStepServices, 'icon': Icons.spa_rounded},
    {
      'title': S.of(context).bookingStepBook,
      'icon': Icons.calendar_month_rounded,
    },
    {
      'title': S.of(context).bookingStepArtist,
      'icon': Icons.person_pin_rounded,
    },
    {
      'title': S.of(context).bookingStepCompleted,
      'icon': Icons.check_circle_rounded,
    },
  ];

  @override
  void initState() {
    super.initState();
    final cubit = context.read<NailBookingCubit>();
    cubit.loadSalons();
    cubit.loadServices();
    // Truyền ID dịch vụ gốc vào cubit để cubit build bookingItems cho
    // API /Bookings/hold-slot (backend yêu cầu bookingItems không được rỗng).
    cubit.setBaseService(_baseServiceId);
    _fetchWalletBalance();
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

  Future<void> _fetchWalletBalance() async {
    setState(() => _isLoadingWallet = true);
    try {
      final response = await _apiService.getCustomerWalletSummary();
      if (!mounted) return;
      setState(() {
        _walletAvailableBalance = (response?['availableBalance'] as num?)
            ?.toDouble();
        _isLoadingWallet = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingWallet = false);
    }
  }

  // ── Navigation ────────────────────────────────────────────────────────────

  Future<void> _handleBackAction(NailBookingState state) async {
    if (_currentStep > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (state.holdToken != null) {
        context.read<NailBookingCubit>().cancelCurrentHold();
      }
      if (mounted) context.pop();
    }
  }

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
    if (_currentStep == 2 && state.selectedDate == null) {
      _showSnackBar('Vui lòng chọn ngày hẹn!');
      return;
    }
    if (_currentStep == 3) {
      if (!state.noArtistSelected && state.selectedStylist == null) {
        _showSnackBar('Vui lòng chọn thợ nail hoặc chọn "Để Nailify sắp xếp"!');
        return;
      }
      if (state.selectedTime == null) {
        _showSnackBar('Vui lòng chọn khung giờ rảnh!');
        return;
      }
      if (state.holdToken == null || !state.isHolding) {
        final held = await cubit.holdSelectedSlot();
        if (!held || !mounted) return;
      }
    }

    if (_currentStep < 4) {
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
    AuthGuard.check(context, () async {
      final promos = state.selectedPromotions
          .whereType<WalletVoucherModel>()
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
        'holdToken': state.holdToken,
        'selectedPromotionIds': promos.isEmpty
            ? null
            : promos.map((p) => p.promotionId).toList(),
        'useWalletBalance': _useWalletBalance,
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
        final paymentData = await _paymentApiService.createPaymentForRequest(
          payload,
        );
        if (!mounted) return;

        final status = paymentData['status']?.toString().toUpperCase() ?? '';
        final qrCode = paymentData['qrCode']?.toString() ?? '';
        final paymentUrl = paymentData['paymentUrl']?.toString() ?? '';

        if (status == 'PAID' ||
            status == 'SUCCESS' ||
            (qrCode.isEmpty && paymentUrl.isEmpty)) {
          context.go('/payment-success', extra: paymentData);
        } else {
          context.go('/payment-qr', extra: paymentData);
        }
      } catch (e) {
        _showSnackBar(S.of(context).bookingPaymentError(e.toString()));
      }
    });
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

  int _totalDuration(NailBookingState state, NailBookingCubit cubit) {
    final grouped = _groupedServicesMap(state.selectedExtraServices);
    int totalDur = 0;
    grouped.forEach((id, qty) {
      final detail = _getServiceDetail(id, cubit);
      final rawDur = detail?['duration'] ?? detail?['estimatedTime'];
      final int dur = (rawDur is num)
          ? rawDur.toInt()
          : (int.tryParse(rawDur?.toString() ?? '') ?? 0);
      totalDur += dur * qty;
    });
    return totalDur;
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
          onPressed: () {
            final state = context.read<NailBookingCubit>().state;
            _handleBackAction(state);
          },
        ),
        title: Text(
          S.of(context).bookServiceTitle,
          style: const TextStyle(
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
              SleekBookingStepIndicator(
                currentStep: _currentStep,
                steps: _bookingSteps,
              ),
              _buildHoldCountdownBanner(state),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (idx) {
                    setState(() => _currentStep = idx);
                    if (idx == 3 && state.selectedDate != null) {
                      if (state.noArtistSelected) {
                        cubit.loadSalonAvailableSlots();
                      } else {
                        cubit.fetchSuggestedArtists();
                        if (state.selectedStylist != null) {
                          cubit.refreshTimeSlots();
                        }
                      }
                    }
                  },
                  children: [
                    // ── STEP 0: CHỌN TIỆM ───────────────────────────
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

                    // ── STEP 1: DỊCH VỤ ───────────────────────────────
                    SingleChildScrollView(
                      padding: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 20,
                        bottom: 80,
                      ),
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

                    // ── STEP 2: NGÀY ─────────────────────────────────
                    _buildDateStep(context, state, cubit),

                    // ── STEP 3: PHÂN THỢ & CHỌN GIỜ ───────────────────
                    _buildArtistAndTimeStep(context, state, cubit),

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

  Widget _buildDateStep(
    BuildContext context,
    NailBookingState state,
    NailBookingCubit cubit,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingDateSelection(
            selectedDate: state.selectedDate,
            onDateChanged: (date) => cubit.selectDate(
              date: date,
              nailVariantId: 0,
              useSuggestedArtists: true,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistAndTimeStep(BuildContext context, NailBookingState state, NailBookingCubit cubit) {
    final grouped = _groupedServicesMap(state.selectedExtraServices);
    final bookingItems = grouped.entries
        .map((e) => {
              'nailVariantId': null,
              'serviceId': e.key,
              'customerNailId': null,
              'quantity': e.value,
            })
        .toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => cubit.setSelectArtistMode(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: !state.noArtistSelected
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: !state.noArtistSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          'Tự chọn thợ',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: !state.noArtistSelected
                                ? AppColors.primary
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => cubit.setNoArtistMode(),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      decoration: BoxDecoration(
                        color: state.noArtistSelected
                            ? Colors.white
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: state.noArtistSelected
                            ? [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          'Để Nailify sắp xếp',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: state.noArtistSelected
                                ? AppColors.primary
                                : Colors.grey.shade700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          if (!state.noArtistSelected) ...[
            ArtistSelectionList(
              artists: state.artists,
              isLoading: state.isLoadingArtists,
              selectedStylistId: state.selectedStylist?['nailArtistId'],
              noArtistSelected: false,
              hideAutoAssign: true,
              onStylistSelected: (artist) {
                if (artist != null) cubit.selectStylist(artist);
              },
              onModeChanged: (_) {},
            ),
            const SizedBox(height: 24),
            if (state.selectedStylist != null)
              BookingTimeSelection(
                timeSlots: state.timeSlots,
                isLoading: state.isLoadingTimes,
                selectedTime: state.selectedTime,
                canSelect: true,
                selectedDate: state.selectedDate,
                salonId: state.selectedBranch?['salonId']?.toString(),
                artistId: state.selectedStylist?['nailArtistId']?.toString(),
                waitlistItems: bookingItems,
                onTimeChanged: cubit.selectTime,
                onRefreshSlots: cubit.refreshTimeSlots,
              ),
          ] else ...[
            BookingTimeSelection(
              timeSlots: state.timeSlots,
              isLoading: state.isLoadingTimes,
              selectedTime: state.selectedTime,
              canSelect: true,
              selectedDate: state.selectedDate,
              salonId: state.selectedBranch?['salonId']?.toString(),
              artistId: null,
              waitlistItems: bookingItems,
              onTimeChanged: cubit.selectTime,
              onRefreshSlots: cubit.refreshTimeSlots,
            ),
          ],
        ],
      ),
    );
  }

  // ── SUMMARY ────────────────────────────────────────────────────────────────
  Widget _buildSummaryStep(
    BuildContext context,
    NailBookingState state,
    NailBookingCubit cubit,
  ) {
    if (_priceReviewKey != _priceReviewRequestKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _reviewPrice();
      });
    }

    final promos = state.selectedPromotions
        .whereType<WalletVoucherModel>()
        .toList();
    final subtotal = (_priceReview?['price'] is num)
        ? (_priceReview!['price'] as num).toInt()
        : _totalPrice(state, cubit);

    final localDiscount = cubit.discountAmountFromVouchers(
      subtotal: subtotal,
      vouchers: promos,
    );

    final totalPrice = (_priceReview?['totalPrice'] is num)
        ? (_priceReview!['totalPrice'] as num).toInt()
        : (subtotal - localDiscount).clamp(0, double.maxFinite).toInt();

    final grouped = _groupedServicesMap(state.selectedExtraServices);

    final depositInfo = PriceFormatter.getDepositInfo(
      state.selectedBranch?['depositConfig'],
      totalPrice,
    );
    final initialDepositAmount = depositInfo['amount'] as int;
    final walletDeduction =
        (_useWalletBalance &&
            _walletAvailableBalance != null &&
            _walletAvailableBalance! > 0)
        ? (_walletAvailableBalance! < initialDepositAmount
              ? _walletAvailableBalance!.round()
              : initialDepositAmount)
        : 0;

    final discountsList = _discountBreakdown;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Thẻ thông tin cuộc hẹn
        Container(
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
            children: [
              _buildSummaryRow(
                Icons.storefront_rounded,
                'Chi nhánh',
                state.selectedBranch?['name'] ?? '',
              ),
              _buildSummaryRow(
                Icons.calendar_month_rounded,
                'Ngày hẹn',
                state.selectedDate != null
                    ? '${state.selectedDate!.day}/${state.selectedDate!.month}/${state.selectedDate!.year}'
                    : '',
              ),
              _buildSummaryRow(
                Icons.access_time_rounded,
                'Thời gian',
                state.selectedTime ?? '',
              ),
              _buildSummaryRow(
                Icons.face_3_rounded,
                'Thợ thực hiện',
                state.noArtistSelected
                    ? 'Tự động phân công'
                    : (state.selectedStylist?['fullName'] ?? ''),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // 2. Thẻ Voucher & Ví Nailify
        _buildVoucherAndWalletCard(context, state, cubit),
        const SizedBox(height: 16),

        // 3. Thẻ Chi tiết thanh toán
        Container(
          padding: const EdgeInsets.all(18),
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
                  const Text(
                    'Chi tiết thanh toán',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  if (_isReviewingPrice) ...[
                    const SizedBox(width: 8),
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFFE02B6D),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 14),

              PaymentDetailTable(
                items: [
                  for (final entry in grouped.entries)
                    PaymentTableItem(
                      name:
                          _getServiceDetail(entry.key, cubit)?['name'] ??
                          cubit.serviceNameById(entry.key),
                      quantity: entry.value,
                      unitPrice:
                          (_getServiceDetail(entry.key, cubit)?['price']
                                  as num?)
                              ?.toInt() ??
                          cubit.servicePriceById(entry.key),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    S.of(context).bookingEstimatedTotal,
                    style: TextStyle(
                      fontSize: 13.5,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Text(
                    PriceFormatter.format(subtotal),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (discountsList.isNotEmpty) ...[
                for (final discountItem in discountsList)
                  _buildDiscountInvoiceRow(discountItem),
              ] else if (localDiscount > 0) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      S.of(context).bookingDiscount,
                      style: TextStyle(
                        fontSize: 13.5,
                        color: Colors.grey.shade700,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    Text(
                      '-${PriceFormatter.format(localDiscount)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFFE02B6D),
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 14),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tổng thanh toán',
                    style: TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    PriceFormatter.format(totalPrice),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE02B6D),
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
              if (state.selectedBranch != null) ...[
                const SizedBox(height: 12),
                const Divider(height: 1, color: Color(0xFFF0F0F0)),
                const SizedBox(height: 14),
                _buildDepositDetails(
                  totalPrice,
                  initialDepositAmount,
                  walletDeduction,
                  state.selectedBranch,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildVoucherAndWalletCard(
    BuildContext context,
    NailBookingState state,
    NailBookingCubit cubit,
  ) {
    final promos = state.selectedPromotions
        .whereType<WalletVoucherModel>()
        .toList();
    final selectedVoucher = promos.isNotEmpty ? promos.first : null;
    final hasSelected = selectedVoucher != null;

    final balance = _walletAvailableBalance;
    final hasBalance = balance != null && balance > 0;

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
        children: [
          // Voucher Row
          GestureDetector(
            onTap: () => showModalBottomSheet(
              context: context,
              isScrollControlled: true,
              backgroundColor: Colors.transparent,
              builder: (_) => BookingPromotionSheet(
                selectedPromotions: promos,
                onConfirm: (list) => cubit.selectPromotions(list),
              ),
            ),
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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Voucher giảm giá',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13.5,
                          color: AppColors.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        hasSelected
                            ? '${selectedVoucher.promotionName} (-${selectedVoucher.displayDiscount})'
                            : 'Chưa chọn voucher',
                        style: TextStyle(
                          color: hasSelected
                              ? const Color(0xFFE02B6D)
                              : Colors.grey.shade500,
                          fontSize: 12,
                          fontWeight: hasSelected
                              ? FontWeight.w700
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasSelected)
                  IconButton(
                    icon: const Icon(
                      Icons.close_rounded,
                      color: Color(0xFFE02B6D),
                      size: 20,
                    ),
                    onPressed: () => cubit.selectPromotions([]),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  )
                else
                  const Row(
                    children: [
                      Text(
                        'Chọn',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE02B6D),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        color: Color(0xFFE02B6D),
                        size: 16,
                      ),
                    ],
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 12),

          // Wallet Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  size: 20,
                  color: Color(0xFFE02B6D),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dùng số dư Ví Nailify',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (_isLoadingWallet)
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: const SizedBox(
                          height: 4,
                          width: 60,
                          child: LinearProgressIndicator(
                            backgroundColor: Color(0xFFFCE4EC),
                            valueColor: AlwaysStoppedAnimation(
                              Color(0xFFE02B6D),
                            ),
                          ),
                        ),
                      )
                    else
                      Text(
                        hasBalance
                            ? 'Số dư: ${PriceFormatter.format(balance.round())}'
                            : 'Số dư trống',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: hasBalance
                              ? Colors.grey.shade700
                              : Colors.grey.shade400,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(
                height: 30,
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: Switch(
                    value: _useWalletBalance,
                    onChanged: hasBalance && !_isLoadingWallet
                        ? (val) => setState(() => _useWalletBalance = val)
                        : null,
                    activeThumbColor: Colors.white,
                    activeTrackColor: const Color(0xFFE02B6D),
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: const Color(0xFFF0E6EA),
                    trackOutlineColor: WidgetStateProperty.all(
                      Colors.transparent,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionSelector(
    BuildContext context,
    NailBookingState state,
    NailBookingCubit cubit,
  ) {
    final promos = state.selectedPromotions
        .whereType<WalletVoucherModel>()
        .toList();
    final hasPromos = promos.isNotEmpty;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      tileColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: hasPromos
              ? AppColors.primary.withOpacity(0.5)
              : Colors.grey.shade200,
        ),
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: hasPromos
              ? AppColors.primary.withOpacity(0.1)
              : Colors.orange.shade50,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.local_offer_rounded,
          size: 20,
          color: hasPromos ? AppColors.primary : Colors.orange.shade700,
        ),
      ),
      title: Text(
        'Khuyến mãi',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 15.5,
          color: hasPromos ? AppColors.primaryDark : Colors.black87,
        ),
      ),
      subtitle: Text(
        hasPromos
            ? 'Đã chọn ${promos.length} khuyến mãi'
            : 'Chọn voucher / khuyến mãi',
        style: TextStyle(
          color: hasPromos ? AppColors.primary : Colors.grey.shade600,
          fontSize: 13,
        ),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: () => showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => BookingPromotionSheet(
          selectedPromotions: promos,
          onConfirm: (list) => cubit.selectPromotions(list),
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
                  DurationFormatter.format(
                    _baseServiceDuration,
                    context: context,
                  ),
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

  Widget _buildDepositDetails(
    int totalPrice,
    int initialDepositAmount,
    int walletDeduction,
    Map<String, dynamic>? branch,
  ) {
    final depositInfo = PriceFormatter.getDepositInfo(
      branch?['depositConfig'],
      totalPrice,
    );
    final depositConfigText = depositInfo['displayText'] as String;
    final depositAmountToPay = (initialDepositAmount - walletDeduction).clamp(
      0,
      initialDepositAmount,
    );
    final remainingAmountAtSalon = (totalPrice - walletDeduction).clamp(
      0,
      totalPrice,
    );

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              S.of(context).bookingDepositRatioLabel,
              style: TextStyle(fontSize: 13.5, color: Colors.grey.shade600),
            ),
            Text(
              depositConfigText,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 13.5,
              ),
            ),
          ],
        ),
        if (_useWalletBalance && walletDeduction > 0) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Khấu trừ Ví Nailify (cọc)',
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                '-${PriceFormatter.format(walletDeduction)}',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE02B6D),
                  fontSize: 13.5,
                ),
              ),
            ],
          ),
        ],
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              depositAmountToPay <= 0
                  ? 'Tiền cọc cần thanh toán:'
                  : S.of(context).bookingDepositAmountLabel,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            ),
            Text(
              PriceFormatter.format(depositAmountToPay),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                color: Color(0xFFE02B6D),
                fontSize: 16,
              ),
            ),
          ],
        ),
        if (_useWalletBalance && walletDeduction > 0) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Còn lại trả tại Salon:',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.bold,
                  color: Colors.grey.shade700,
                ),
              ),
              Text(
                PriceFormatter.format(remainingAmountAtSalon),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ],
      ],
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
                  ? S.of(context).reservationMayExpireIn(min, sec)
                  : S.of(context).slotHeldRemaining(min, sec),
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

  Widget _buildFooter(NailBookingState state, NailBookingCubit cubit) {
    final bool isFirstStep = _currentStep == 0;
    final int totalP = _totalPrice(state, cubit);
    final int totalD = _totalDuration(state, cubit);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 14,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((_currentStep == 1 || _currentStep == 2 || _currentStep == 3) &&
                (totalP > 0 || totalD > 0)) ...[
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    S.of(context).bookingEstimatedTotal,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  Row(
                    children: [
                      Text(
                        PriceFormatter.format(totalP),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primary,
                        ),
                      ),
                      if (totalD > 0) ...[
                        Text(
                          ' • ',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          DurationFormatter.format(totalD, context: context),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            isFirstStep
                ? SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(26),
                        gradient: LinearGradient(
                          colors: state.isSubmitting
                              ? [Colors.grey.shade400, Colors.grey.shade500]
                              : [
                                  const Color(0xFFFF4081),
                                  const Color(0xFFD81B60),
                                ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        boxShadow: [
                          if (!state.isSubmitting)
                            BoxShadow(
                              color: const Color(
                                0xFFD81B60,
                              ).withValues(alpha: 0.38),
                              blurRadius: 14,
                              offset: const Offset(0, 5),
                            ),
                        ],
                      ),
                      child: ElevatedButton(
                        onPressed: state.isSubmitting
                            ? null
                            : () => _handleNextAction(state, cubit),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: Colors.white,
                          shadowColor: Colors.transparent,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          elevation: 0,
                        ),
                        child: state.isSubmitting
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Text(
                                'Tiếp tục',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 0.2,
                                ),
                              ),
                      ),
                    ),
                  )
                : Row(
                    children: [
                      TextButton.icon(
                        onPressed: state.isSubmitting
                            ? null
                            : () => _handleBackAction(state),
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          size: 18,
                          color: AppColors.textPrimary,
                        ),
                        label: const Text(
                          'Quay lại',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 14.5,
                          ),
                        ),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 14,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Container(
                          height: 50,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(25),
                            gradient: LinearGradient(
                              colors: state.isSubmitting
                                  ? [Colors.grey.shade400, Colors.grey.shade500]
                                  : [
                                      const Color(0xFFFF4081),
                                      const Color(0xFFD81B60),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              if (!state.isSubmitting)
                                BoxShadow(
                                  color: const Color(
                                    0xFFD81B60,
                                  ).withValues(alpha: 0.35),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: state.isSubmitting
                                ? null
                                : () => _handleNextAction(state, cubit),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              foregroundColor: Colors.white,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(25),
                              ),
                              elevation: 0,
                            ),
                            child: state.isSubmitting
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2.5,
                                    ),
                                  )
                                : Text(
                                    _currentStep == 4
                                        ? 'Thanh toán cọc'
                                        : 'Tiếp tục',
                                    style: const TextStyle(
                                      fontSize: 15.5,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }
}
