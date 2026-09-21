import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../generated/l10n.dart';

import '../../data/datasources/booking_api_service.dart';
import '../../data/models/wallet_voucher_model.dart';
import '../cubit/warranty_booking_cubit.dart';
import '../widgets/artist_selection_list.dart';
import '../widgets/booking_date_selection.dart';
import '../widgets/booking_promotion_sheet.dart';
import '../widgets/booking_time_selection.dart';
import '../widgets/payment_detail_table.dart';

/// Entry point: bọc page trong BlocProvider.
class WarrantyBookingPage extends StatelessWidget {
  final Map<String, dynamic> warrantyData;

  const WarrantyBookingPage({super.key, required this.warrantyData});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WarrantyBookingCubit(),
      child: _WarrantyBookingView(warrantyData: warrantyData),
    );
  }
}

class _WarrantyBookingView extends StatefulWidget {
  final Map<String, dynamic> warrantyData;

  const _WarrantyBookingView({required this.warrantyData});

  @override
  State<_WarrantyBookingView> createState() => _WarrantyBookingViewState();
}

class _WarrantyBookingViewState extends State<_WarrantyBookingView> {
  final BookingApiService _apiService = BookingApiService();
  late final PageController _pageController;

  int _currentStep = 0;

  // ============== Step 1 (Artist) ==============
  String? _selectedStylistId;
  bool _noArtistSelected = false;

  // ============== Step 3 (Schedule) ==============
  DateTime? _selectedDate;
  String? _selectedTime;
  List<dynamic> _timeSlots = [];
  bool _isHolding = false;
  int _holdRemainingSeconds = 0;
  Timer? _holdTimer;

  // ============== Wallet & Vouchers ==============
  bool _useWalletBalance = true;
  double? _walletAvailableBalance;
  bool _isLoadingWallet = false;

  bool _isLoadingPromotions = false;
  List<WalletVoucherModel> _promotions = [];
  int? _selectedPromotionId;

  List<Map<String, dynamic>> get _bookingSteps => [
        {
          'title': S.of(context).warrantyStepArtist,
          'icon': Icons.person_pin_rounded,
        },
        {
          'title': S.of(context).warrantyStepServices,
          'icon': Icons.spa_rounded,
        },
        {
          'title': S.of(context).warrantyStepSchedule,
          'icon': Icons.calendar_month_rounded,
        },
        {
          'title': S.of(context).warrantyStepConfirm,
          'icon': Icons.check_circle_rounded,
        },
      ];

  @override
  void initState() {
    super.initState();
    _currentStep = 0;
    _pageController = PageController(initialPage: _currentStep);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<WarrantyBookingCubit>().loadWarrantyContext(
            widget.warrantyData,
          );
      _fetchWalletBalance();
    });
  }

  Future<void> _fetchWalletBalance() async {
    setState(() => _isLoadingWallet = true);
    try {
      final response = await _apiService.getCustomerWalletSummary();
      if (!mounted) return;
      setState(() {
        _walletAvailableBalance =
            (response?['availableBalance'] as num?)?.toDouble();
        _isLoadingWallet = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoadingWallet = false);
    }
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
    // Bug fix: Gọi cancelCurrentHold() để notify backend hủy hold slot.
    // Trước đây chỉ cancel timer cục bộ, phụ thuộc vào BlocProvider close cubit.
    // Việc gọi trực tiếp ở đây đảm bảo backend nhận cancel ngay khi page dispose,
    // tránh hold slot treo trên backend nếu BlocProvider close chậm.
    if (mounted) {
      // mounted check để tránh lỗi "Tried to call BlocProvider.of() in a
      // dispose callback" — context vẫn hợp lệ trong dispose của StatefulWidget.
      try {
        context.read<WarrantyBookingCubit>().cancelCurrentHold();
      } catch (_) {
        // Ignore nếu context đã invalid (hiếm khi xảy ra).
      }
    }
    _pageController.dispose();
    super.dispose();
  }

  void _onStepChanged(int step) {
    setState(() => _currentStep = step);
    if (step == 2 && _selectedDate != null) {
      _fetchTimeSlots();
    }
  }

  // ── Artist step handlers ─────────────────────────────────────────
  void _handleStylistSelected(Map<String, dynamic>? stylist) {
    setState(() {
      _selectedStylistId = stylist?['nailArtistId']?.toString() ??
          stylist?['id']?.toString();
      _noArtistSelected = stylist == null;
      _selectedTime = null;
      _timeSlots = [];
    });
    _cancelHold();
  }

  void _handleArtistModeChanged(bool isNoArtist) {
    setState(() => _noArtistSelected = isNoArtist);
    if (isNoArtist) {
      setState(() {
        _selectedStylistId = null;
        _selectedTime = null;
        _timeSlots = [];
      });
      _cancelHold();
    }
  }

  // ── Schedule step handlers ───────────────────────────────────────
  Future<void> _handleDateChanged(DateTime date) async {
    setState(() {
      _selectedDate = date;
      _selectedTime = null;
      _timeSlots = [];
    });
    _cancelHold();
    await _fetchTimeSlots();
  }

  Future<void> _fetchTimeSlots() async {
    if (_selectedDate == null) return;
    final cubit = context.read<WarrantyBookingCubit>();
    final state = cubit.state;
    final salonId = state.selectedBranch?['salonId']?.toString() ?? '';
    final artistId = _noArtistSelected
        ? null
        : (_selectedStylistId ??
            state.selectedStylist?['nailArtistId']?.toString());
    if (salonId.isEmpty) return;
    if (!_noArtistSelected && (artistId == null || artistId.isEmpty)) return;

    setState(() => _timeSlots = []);
    final slots = await cubit.loadTimeSlots(
      salonId: salonId,
      artistId: artistId,
      date: _selectedDate!,
    );
    if (!mounted) return;
    setState(() => _timeSlots = slots);
  }

  Future<void> _handleRetryTimes() async {
    await _fetchTimeSlots();
  }

  Future<void> _handleTimeChanged(String time) async {
    // Lưu hold token CŨ trước khi chọn giờ mới.
    // Bug fix: KHÔNG cancel hold cũ NGAY LẬP TỨC. Nếu cancel rồi hold mới
    // thất bại → user MẤT SLOT vì hold cũ đã bị cancel.
    // Fix: Chỉ cancel hold cũ SAU KHI hold mới THÀNH CÔNG.
    final oldToken = _holdTimer != null
        ? context.read<WarrantyBookingCubit>().state.holdToken
        : null;

    setState(() {
      _selectedTime = time;
    });
    final cubit = context.read<WarrantyBookingCubit>();
    final state = cubit.state;
    final stylistId = _selectedStylistId ??
        state.selectedStylist?['nailArtistId']?.toString();
    final artistObj = _noArtistSelected
        ? null
        : _findArtistById(state.artists, stylistId);
    cubit.selectDateForHolder(_selectedDate!);
    cubit.selectStylistForHolder(artistObj, noArtist: _noArtistSelected);
    cubit.selectTimeForHolder(time);
    final ok = await cubit.holdSelectedSlot();
    if (!mounted) return;

    if (ok) {
      // ✅ Hold mới thành công → Cancel hold CŨ (nếu có và khác token mới).
      if (oldToken != null && oldToken.isNotEmpty) {
        final newToken = cubit.state.holdToken;
        // Chỉ cancel nếu token mới khác token cũ (tránh cancel chính mình).
        if (newToken != oldToken) {
          cubit.cancelCurrentHold();
        }
      }
      _startHoldCountdown();
    } else {
      // ❌ Hold mới thất bại → GIỮ NGUYÊN hold CŨ (user vẫn có slot).
      // Reset UI chỉ khi không có hold cũ nào.
      if (oldToken == null || oldToken.isEmpty) {
        setState(() {
          _selectedTime = null;
        });
      }
      _showSnackBar(
        'Khung giờ này vừa có người chọn. Vui lòng chọn giờ khác.',
        isError: true,
      );
    }
  }

  Map<String, dynamic>? _findArtistById(List<dynamic> artists, String? id) {
    if (id == null) return null;
    for (final a in artists) {
      if (a is Map &&
          (a['nailArtistId']?.toString() == id ||
              a['id']?.toString() == id)) {
        return Map<String, dynamic>.from(a);
      }
    }
    return null;
  }

  void _startHoldCountdown() {
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final s = context.read<WarrantyBookingCubit>().state;
      if (s.holdToken == null) {
        _holdTimer?.cancel();
        if (_selectedTime != null) {
          setState(() => _selectedTime = null);
          _showSnackBar(
            'Thời gian giữ chỗ đã hết. Vui lòng chọn lại khung giờ.',
          );
        }
        return;
      }
      setState(() {
        _holdRemainingSeconds = s.holdRemainingSeconds;
        _isHolding = s.isHolding;
      });
      if (s.holdRemainingSeconds <= 0) {
        _holdTimer?.cancel();
      }
    });
  }

  void _cancelHold() {
    _holdTimer?.cancel();
    final cubit = context.read<WarrantyBookingCubit>();
    if (cubit.state.holdToken != null) {
      cubit.cancelCurrentHold();
    }
    setState(() {
      _isHolding = false;
      _holdRemainingSeconds = 0;
    });
  }

  // ── Extra services handlers (Step 2) ────────────────────────────
  void _handleExtraServiceIncrement(String serviceId) {
    final cubit = context.read<WarrantyBookingCubit>();
    final next = List<String?>.from(cubit.state.selectedExtraServices)
      ..add(serviceId);
    cubit.setExtraServices(next);
  }

  void _handleExtraServiceDecrement(String serviceId) {
    final cubit = context.read<WarrantyBookingCubit>();
    final next = List<String?>.from(cubit.state.selectedExtraServices);
    final idx = next.lastIndexOf(serviceId);
    if (idx >= 0) next.removeAt(idx);
    cubit.setExtraServices(next);
  }

  void _handleExtraServiceRemoveAll(String serviceId) {
    final cubit = context.read<WarrantyBookingCubit>();
    final next = List<String?>.from(cubit.state.selectedExtraServices)
      ..removeWhere((id) => id == serviceId);
    cubit.setExtraServices(next);
  }

  // ── Submit ───────────────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (_selectedTime == null || _selectedDate == null) return;
    final cubit = context.read<WarrantyBookingCubit>();
    try {
      final result = await cubit.submitWarrantyBooking(
        useWalletBalance: _useWalletBalance,
        selectedPromotionIds:
            _selectedPromotionId != null ? [_selectedPromotionId!] : null,
      );
      if (!mounted) return;
      final state = cubit.state;
      final time = _selectedTime!;
      final formattedTime = time.length == 5 ? '$time:00' : time;
      final stylistName = _noArtistSelected
          ? 'Tự động phân công'
          : (state.selectedStylist?['fullName']?.toString() ?? '');
      final mode = result['__mode']?.toString() ?? 'free';
      final totalPrice = cubit.estimatedTotalPrice;

      if (mode == 'paid') {
        // Có phát sinh phí → qua payment-qr.
        context.go('/payment-qr', extra: result);
        return;
      }

      // Free flow → success.
      final serviceName = _buildWarrantyServiceSummary(state);
      context.go(
        '/booking-success',
        extra: {
          'bookingId': result['bookingId']?.toString() ?? '',
          'serviceName': serviceName,
          'date': _selectedDate,
          'time': formattedTime,
          'stylistName': stylistName,
          'totalPrice': totalPrice,
        },
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Đặt lịch thất bại: $e', isError: true);
    }
  }

  String _buildWarrantyServiceSummary(WarrantyBookingState state) {
    final items = state.selectedWarrantyItems;
    if (items.isEmpty) return S.of(context).warrantyServiceDefault;
    final first = items.first;
    final name = first['nailVariantName']?.toString().trim() ??
        first['customerNailName']?.toString().trim() ??
        first['serviceName']?.toString().trim() ??
        '';
    if (name.isEmpty) return S.of(context).warrantyServiceDefault;
    if (items.length > 1) return '$name +${items.length - 1}';
    return name;
  }

  // ── UI helpers ───────────────────────────────────────────────────
  void _showSnackBar(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Colors.red : null,
      ),
    );
  }

  // ── BUILD ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WarrantyBookingCubit, WarrantyBookingState>(
      listenWhen: (prev, curr) =>
          curr.errorMessage != null && prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        _showSnackBar(state.errorMessage!, isError: true);
        context.read<WarrantyBookingCubit>().clearError();
      },
      builder: (context, state) {
        // ── Guard: quá 7 ngày → block toàn bộ flow ──────────────
        if (!state.isWithinWarrantyWindow) {
          return Scaffold(
            backgroundColor: AppColors.background,
            appBar: AppBar(
              leading: IconButton(
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 20,
                  color: AppColors.primaryDark,
                ),
                onPressed: () => context.pop(),
              ),
              title: Text(
                S.of(context).warrantyBookingTitle,
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontFamily: 'Georgia',
                  color: AppColors.primaryDark,
                ),
              ),
              backgroundColor: const Color(0xFFFDFBF7),
              elevation: 0,
              centerTitle: true,
            ),
            body: _buildExpiredView(),
          );
        }
        final canProceed = _canProceedForStep(state);
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
            title: Text(
              S.of(context).warrantyBookingTitle,
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
          body: Column(
            children: [
              _buildStepIndicator(),
              _buildHoldCountdownBanner(),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: _onStepChanged,
                  children: [
                    _buildArtistStep(state),
                    _buildServiceStep(state),
                    _buildScheduleStep(state),
                    _buildSummaryStep(state),
                  ],
                ),
              ),
              _buildBottomBar(canProceed, state),
            ],
          ),
        );
      },
    );
  }

  Widget _buildExpiredView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.access_time_filled_rounded,
              size: 72,
              color: Colors.orange,
            ),
            const SizedBox(height: 20),
            Text(
              S.of(context).warrantyExpiredTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              S.of(context).warrantyExpiredDesc,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade700,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () => context.pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  S.of(context).warrantyExpiredBackBtn,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool _canProceedForStep(WarrantyBookingState state) {
    if (state.isSubmitting) return false;
    switch (_currentStep) {
      case 0:
        return _noArtistSelected || _selectedStylistId != null;
      case 1:
        return state.selectedWarrantyItems.isNotEmpty;
      case 2:
        return _selectedTime != null;
      case 3:
        return !state.isSubmitting && state.selectedWarrantyItems.isNotEmpty;
      default:
        return false;
    }
  }

  Widget _buildStepIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
      color: const Color(0xFFFDFBF7),
      child: Row(
        children: List.generate(_bookingSteps.length, (i) {
          final isActive = i == _currentStep;
          final isDone = i < _currentStep;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive || isDone
                          ? AppColors.primary
                          : const Color(0xFFF2ECE6),
                      boxShadow: isActive
                          ? [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Icon(
                      isDone ? Icons.check_rounded : _bookingSteps[i]['icon'],
                      size: 18,
                      color: isActive || isDone
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _bookingSteps[i]['title'],
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight:
                          isActive ? FontWeight.bold : FontWeight.w500,
                      color: isActive
                          ? AppColors.primaryDark
                          : AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildHoldCountdownBanner() {
    if (!_isHolding) return const SizedBox.shrink();
    final minutes =
        (_holdRemainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds =
        (_holdRemainingSeconds % 60).toString().padLeft(2, '0');
    final isUrgent = _holdRemainingSeconds <= 60;
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
                  ? 'Chỗ có thể bị hủy sau $minutes:$seconds'
                  : 'Slot đang được giữ cho bạn - còn $minutes:$seconds để hoàn tất',
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

  // ── Step 1: Artist ────────────────────────────────────────────────
  Widget _buildArtistStep(WarrantyBookingState state) {
    if (state.artistsStatus == WarrantyLoadStatus.loading) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }
    if (state.artistsStatus == WarrantyLoadStatus.error) {
      return _buildRetryView(
        message: 'Không tải được danh sách thợ.',
        onRetry: () => context.read<WarrantyBookingCubit>().reloadArtists(),
      );
    }
    if (state.artists.isEmpty) {
      return Center(
        child: Text(
          'Không có thợ nào trong salon này.',
          style: TextStyle(color: Colors.grey.shade600),
        ),
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: ArtistSelectionList(
        artists: state.artists,
        isLoading: state.isLoadingArtists,
        selectedStylistId: _selectedStylistId,
        noArtistSelected: _noArtistSelected,
        onStylistSelected: _handleStylistSelected,
        onModeChanged: _handleArtistModeChanged,
        pinnedArtistId: state.sourceArtistId,
      ),
    );
  }

  Widget _buildRetryView({
    required String message,
    required Future<void> Function() onRetry,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.cloud_off_rounded,
              size: 64,
              color: Colors.grey,
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(S.of(context).bookingRetry),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Step 2: Service ───────────────────────────────────────────────
  Widget _buildServiceStep(WarrantyBookingState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context).warrantyStepServices,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.primaryDark,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            S.of(context).warrantyServiceNote,
            style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 16),
          if (state.warrantyItems.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade200),
              ),
              child: Text(
                'Không có dịch vụ bảo hành.',
                style: TextStyle(color: Colors.grey.shade700),
              ),
            )
          else
            ...state.warrantyItems.map((item) => _buildWarrantyItemTile(item, state)),
          const SizedBox(height: 24),
          _buildExtraServicesSection(state),
        ],
      ),
    );
  }

  Widget _buildWarrantyItemTile(
    Map<String, dynamic> item,
    WarrantyBookingState state,
  ) {
    bool isSame(Map<String, dynamic> a, Map<String, dynamic> b) {
      const keys = [
        'nailVariantId',
        'serviceId',
        'customerNailId',
        'shapeMethodConfigId',
      ];
      for (final k in keys) {
        if (a[k]?.toString() != b[k]?.toString()) return false;
      }
      return true;
    }

    final isSelected =
        state.selectedWarrantyItems.any((s) => isSame(s, item));

    final names = [
      item['nailVariantName']?.toString().trim() ?? '',
      item['customerNailName']?.toString().trim() ?? '',
      item['serviceName']?.toString().trim() ?? '',
    ].where((n) => n.isNotEmpty).toList();
    final name = names.isEmpty
        ? S.of(context).bookingWarrantyDefault
        : names.join(' & ');

    final qty = (item['quantity'] is num)
        ? (item['quantity'] as num).toInt()
        : (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isSelected
            ? AppColors.primary.withValues(alpha: 0.04)
            : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSelected
              ? AppColors.primary.withValues(alpha: 0.3)
              : const Color(0xFFF3EFEA),
          width: 1.2,
        ),
      ),
      child: CheckboxListTile(
        value: isSelected,
        activeColor: AppColors.primary,
        selectedTileColor: Colors.transparent,
        title: Text(
          name,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14.5,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          '${S.of(context).warrantyFree} • SL: $qty',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        onChanged: (val) {
          context.read<WarrantyBookingCubit>().toggleWarrantyItem(
                item,
                val == true,
              );
        },
      ),
    );
  }

  Widget _buildExtraServicesSection(WarrantyBookingState state) {
    if (state.services.isEmpty && !state.isLoadingServices) {
      return const SizedBox.shrink();
    }
    if (state.isLoadingServices) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final selected = state.selectedExtraServices;
    final counts = <String, int>{};
    for (final id in selected.whereType<String>()) {
      counts[id] = (counts[id] ?? 0) + 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3EFEA), width: 1.2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.add_circle_outline_rounded,
                      color: AppColors.primary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    S.of(context).bookingAddonServices,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
              if (counts.isNotEmpty)
                Text(
                  S.of(context).bookingSelectedCount(
                    counts.values
                        .fold<int>(0, (s, c) => s + c)
                        .toString(),
                  ),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            S.of(context).warrantyAddonNote,
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 12),
          // ── Nút mở bottom sheet (giống luồng booking khác) ────────
          _buildAddServiceButton(state),
          // ── Danh sách dịch vụ đã chọn (chip-style) ─────────────────
          if (counts.isNotEmpty) ...[
            const SizedBox(height: 12),
            ...counts.entries.map((e) => _buildSelectedServiceChip(e.key, e.value)),
          ],
        ],
      ),
    );
  }

  /// Nút "+ Thêm dịch vụ" mở bottom sheet liệt kê tất cả services khả
  /// dụng. Pattern giống `BookingServiceSelection` của home_booking /
  /// nail_booking.
  Widget _buildAddServiceButton(WarrantyBookingState state) {
    return InkWell(
      onTap: () => _showServicesBottomSheet(state),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.3),
            width: 1.2,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: Color(0xFFFFF5F8),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.add_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                S.of(context).bookingAddServiceBtn,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: AppColors.primary,
                ),
              ),
            ),
            const Icon(
              Icons.chevron_right_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  /// Chip hiển thị 1 dịch vụ đã chọn (tên + SL + giá + nút xoá).
  Widget _buildSelectedServiceChip(String serviceId, int count) {
    final cubit = context.read<WarrantyBookingCubit>();
    final name = cubit.serviceNameById(serviceId);
    final unit = cubit.servicePriceById(serviceId);
    final lineTotal = unit * count;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  count > 1 ? '$name × $count' : name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  PriceFormatter.format(lineTotal),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.remove_circle_outline_rounded,
                size: 22, color: AppColors.primary),
            onPressed: () => _handleExtraServiceDecrement(serviceId),
          ),
          IconButton(
            icon: const Icon(Icons.add_circle_rounded,
                size: 22, color: AppColors.primary),
            onPressed: () => _handleExtraServiceIncrement(serviceId),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline_rounded,
                size: 20, color: Colors.red),
            onPressed: () => _handleExtraServiceRemoveAll(serviceId),
          ),
        ],
      ),
    );
  }

  /// Hiện bottom sheet liệt kê toàn bộ services khả dụng. Pattern
  /// giống `BookingServiceSelection._showServicesBottomSheet`.
  void _showServicesBottomSheet(WarrantyBookingState state) {
    final cubit = context.read<WarrantyBookingCubit>();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Text(
                  S.of(sheetCtx).bookingAddServiceTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
              const Divider(color: Color(0xFFFFF0F5)),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight:
                      MediaQuery.of(sheetCtx).size.height * 0.5,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: ListView.separated(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    itemCount: state.services.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: Color(0xFFFFF5F8)),
                    itemBuilder: (ctx, index) {
                      final s = state.services[index];
                      final sId =
                          s['serviceId']?.toString() ??
                              s['id']?.toString() ??
                              '';
                      final name = cubit.serviceNameById(sId);
                      final price = cubit.servicePriceById(sId);
                      return ListTile(
                        contentPadding:
                            const EdgeInsets.symmetric(vertical: 8),
                        title: Text(
                          name,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              PriceFormatter.format(price),
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: AppColors.primary,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(
                                color: Color(0xFFFFF5F8),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.add_rounded,
                                size: 18,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                        onTap: () {
                          Navigator.pop(sheetCtx);
                          _handleExtraServiceIncrement(sId);
                        },
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── Step 3: Schedule ──────────────────────────────────────────────
  Widget _buildScheduleStep(WarrantyBookingState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          BookingDateSelection(
            selectedDate: _selectedDate,
            onDateChanged: _handleDateChanged,
          ),
          const SizedBox(height: 28),
          if (state.timeSlotsStatus == WarrantyLoadStatus.error &&
              _timeSlots.isEmpty &&
              _selectedDate != null)
            _buildRetryView(
              message: state.timeSlotsLoadError ??
                  'Không tải được khung giờ. Vui lòng thử lại.',
              onRetry: _handleRetryTimes,
            )
          else
            BookingTimeSelection(
              timeSlots: _timeSlots,
              isLoading: state.timeSlotsStatus == WarrantyLoadStatus.loading,
              selectedTime: _selectedTime,
              canSelect: _selectedDate != null,
              selectedDate: _selectedDate,
              salonId: state.selectedBranch?['salonId'],
              artistId: _noArtistSelected
                  ? null
                  : (_selectedStylistId ??
                      state.selectedStylist?['nailArtistId']),
              onTimeChanged: _handleTimeChanged,
            ),
        ],
      ),
    );
  }

  // ── Step 4: Summary ───────────────────────────────────────────────
  Widget _buildSummaryStep(WarrantyBookingState state) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildBookingSummaryCard(state),
          const SizedBox(height: 16),
          _buildPromotionsAndWalletCard(),
          const SizedBox(height: 16),
          _buildPaymentDetailsCard(state),
        ],
      ),
    );
  }

  Widget _buildBookingSummaryCard(WarrantyBookingState state) {
    final branchName = state.selectedBranch?['name']?.toString() ??
        state.selectedBranch?['salonName']?.toString() ??
        'Chi nhánh Nailify';
    final dateStr = _selectedDate == null
        ? ''
        : '${_selectedDate!.day.toString().padLeft(2, '0')}/${_selectedDate!.month.toString().padLeft(2, '0')}/${_selectedDate!.year}';
    final timeStr =
        _selectedTime == null ? '' : _selectedTime!.substring(0, 5);
    final dateTimeText = dateStr.isEmpty ? '--' : '$dateStr • $timeStr';

    final artistName = _noArtistSelected
        ? S.of(context).bookingAutoAssign
        : (state.selectedStylist?['fullName']?.toString() ??
            state.sourceArtistName);
    final artistAvatar = state.selectedStylist?['avatarUrl']?.toString();

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
          // Dòng 1: Icon Salon + Tên chi nhánh + Nút Đổi lịch
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  size: 18,
                  color: Color(0xFFE02B6D),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  branchName,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.primaryDark,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              InkWell(
                onTap: () {
                  _pageController.animateToPage(
                    2,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: const [
                      Text(
                        'Đổi lịch',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFFE02B6D),
                        ),
                      ),
                      SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: Color(0xFFE02B6D),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF5F5F5)),
          const SizedBox(height: 12),

          // Dòng 2: 2 cột ngang (Lịch hẹn & Thợ phụ trách)
          Row(
            children: [
              // Cột trái: Lịch hẹn
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF0F5),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.access_time_filled_rounded,
                        size: 16,
                        color: Color(0xFFE02B6D),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Lịch hẹn',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateTimeText,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Container(width: 1, height: 32, color: const Color(0xFFF0F0F0)),
              const SizedBox(width: 12),
              // Cột phải: Thợ phụ trách
              Expanded(
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 14,
                      backgroundColor: const Color(0xFFFFF0F5),
                      backgroundImage:
                          artistAvatar != null && artistAvatar.isNotEmpty
                              ? NetworkImage(artistAvatar)
                              : null,
                      child: artistAvatar == null || artistAvatar.isEmpty
                          ? const Icon(
                              Icons.person_rounded,
                              size: 16,
                              color: Color(0xFFE02B6D),
                            )
                          : null,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Thợ phụ trách',
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade600,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            artistName,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPromotionsAndWalletCard() {
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
          _buildVoucherRow(),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFF5F5F5)),
          ),
          _buildWalletToggleRow(),
        ],
      ),
    );
  }

  Widget _buildVoucherRow() {
    final selectedPromotion =
        _promotions.where((v) => v.promotionId == _selectedPromotionId);
    final hasSelected = selectedPromotion.isNotEmpty;
    final count = _promotions.length;
    final selectedVoucher = hasSelected ? selectedPromotion.first : null;

    return GestureDetector(
      onTap: _isLoadingPromotions
          ? null
          : () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => BookingPromotionSheet(
                  selectedPromotions: selectedPromotion.toList(),
                  onConfirm: (list) {
                    setState(() {
                      _selectedPromotionId =
                          list.isNotEmpty ? list.first.promotionId : null;
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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text(
                      'Voucher giảm giá',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    if (count > 0 && !hasSelected) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0F5),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0xFFFFD1DC)),
                        ),
                        child: Text(
                          '$count có sẵn',
                          style: const TextStyle(
                            color: Color(0xFFE02B6D),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 3),
                if (_isLoadingPromotions)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: const SizedBox(
                      height: 4,
                      width: 60,
                      child: LinearProgressIndicator(
                        backgroundColor: Color(0xFFFCE4EC),
                        valueColor: AlwaysStoppedAnimation(Color(0xFFE02B6D)),
                      ),
                    ),
                  )
                else if (hasSelected)
                  Text(
                    '${selectedVoucher!.promotionName} (-${selectedVoucher.displayDiscount})',
                    style: const TextStyle(
                      color: Color(0xFFE02B6D),
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    count > 0 ? 'Chọn voucher' : 'Chưa chọn voucher',
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              onPressed: () => setState(() => _selectedPromotionId = null),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            )
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFFFD1DC)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
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
            ),
        ],
      ),
    );
  }

  Widget _buildWalletToggleRow() {
    final balance = _walletAvailableBalance;
    final hasBalance = balance != null && balance > 0;

    return Row(
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
                      valueColor: AlwaysStoppedAnimation(Color(0xFFE02B6D)),
                    ),
                  ),
                )
              else
                Text(
                  hasBalance
                      ? 'Số dư: ${PriceFormatter.format(balance!.round())}'
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
              activeColor: Colors.white,
              activeTrackColor: const Color(0xFFE02B6D),
              inactiveThumbColor: Colors.white,
              inactiveTrackColor: const Color(0xFFF0E6EA),
              trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPaymentDetailsCard(WarrantyBookingState state) {
    final cubit = context.read<WarrantyBookingCubit>();
    final int totalPrice = cubit.estimatedTotalPrice;
    final int extraTotal = cubit.extraServicesTotal;

    final depositInfo = PriceFormatter.getDepositInfo(
      state.selectedBranch?['depositConfig'],
      totalPrice,
    );
    final initialDepositAmount = depositInfo['amount'] as int;

    final walletDeduction = (_useWalletBalance &&
            _walletAvailableBalance != null &&
            _walletAvailableBalance! > 0)
        ? (_walletAvailableBalance! < initialDepositAmount
            ? _walletAvailableBalance!.round()
            : initialDepositAmount)
        : 0;

    return Container(
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
              Expanded(
                child: Text(
                  S.of(context).bookingPaymentDetails,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    fontFamily: 'Georgia',
                    color: AppColors.primaryDark,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          PaymentDetailTable(items: _paymentTableItems(state)),

          const SizedBox(height: 14),
          CustomPaint(
            size: const Size(double.infinity, 1),
            painter:
                _HorizontalDashedLinePainter(color: const Color(0xFFE5E7EB)),
          ),
          const SizedBox(height: 14),

          _buildInvoiceRow('Tạm tính (dịch vụ phát sinh)', extraTotal,
              isNegative: false),

          const SizedBox(height: 6),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),
          const SizedBox(height: 14),

          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
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
          ),

          if (state.selectedBranch != null && totalPrice > 0) ...[
            const SizedBox(height: 4),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 14),
            _buildDepositDetails(totalPrice, initialDepositAmount, walletDeduction, state),
          ],
        ],
      ),
    );
  }

  List<PaymentTableItem> _paymentTableItems(WarrantyBookingState state) {
    final items = <PaymentTableItem>[];
    for (final item in state.selectedWarrantyItems) {
      final names = [
        item['nailVariantName']?.toString().trim() ?? '',
        item['customerNailName']?.toString().trim() ?? '',
        item['serviceName']?.toString().trim() ?? '',
      ].where((n) => n.isNotEmpty).toList();
      final name = names.isEmpty
          ? S.of(context).bookingWarrantyDefault
          : names.join(' & ');
      final qty = (item['quantity'] is num)
          ? (item['quantity'] as num).toInt()
          : (int.tryParse(item['quantity']?.toString() ?? '1') ?? 1);
      items.add(
        PaymentTableItem(
          name: '$name (Bảo hành)',
          quantity: qty,
          unitPrice: 0,
        ),
      );
    }

    final cubit = context.read<WarrantyBookingCubit>();
    final counts = <String, int>{};
    for (final serviceId in state.selectedExtraServices.whereType<String>()) {
      counts[serviceId] = (counts[serviceId] ?? 0) + 1;
    }
    for (final entry in counts.entries) {
      final unit = cubit.servicePriceById(entry.key);
      items.add(
        PaymentTableItem(
          name: cubit.serviceNameById(entry.key),
          quantity: entry.value,
          unitPrice: unit,
        ),
      );
    }
    return items;
  }

  Widget _buildInvoiceRow(String label, num amount, {required bool isNegative}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              color: isNegative ? Colors.grey.shade700 : Colors.grey.shade600,
              fontWeight: isNegative ? FontWeight.w500 : FontWeight.normal,
            ),
          ),
          Text(
            isNegative
                ? '-${PriceFormatter.format(amount)}'
                : PriceFormatter.format(amount),
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isNegative
                  ? const Color(0xFFE02B6D)
                  : AppColors.textPrimary,
              fontSize: 13.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceRowText(
    String label,
    String valueText, {
    bool strong = false,
    bool muted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              color: muted ? Colors.grey.shade600 : AppColors.textPrimary,
              fontWeight: strong ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          Text(
            valueText,
            style: TextStyle(
              fontWeight: strong ? FontWeight.bold : FontWeight.w600,
              color: AppColors.textPrimary,
              fontSize: 13.5,
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
    WarrantyBookingState state,
  ) {
    final depositInfo = PriceFormatter.getDepositInfo(
      state.selectedBranch?['depositConfig'],
      totalPrice,
    );
    final depositConfigText = depositInfo['displayText'] as String;
    final depositAmountToPay =
        (initialDepositAmount - walletDeduction).clamp(0, initialDepositAmount);
    final remainingAmountAtSalon =
        (totalPrice - walletDeduction).clamp(0, totalPrice);

    return Column(
      children: [
        _buildInvoiceRowText(
          S.of(context).bookingDepositRatioLabel,
          depositConfigText,
          muted: true,
        ),
        if (_useWalletBalance && walletDeduction > 0) ...[
          const SizedBox(height: 8),
          _buildInvoiceRow(
            'Khấu trừ Ví Nailify (cọc)',
            walletDeduction,
            isNegative: true,
          ),
        ],
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                S.of(context).bookingDepositAmountLabel,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                PriceFormatter.format(depositAmountToPay),
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE02B6D),
                  fontSize: 17,
                ),
              ),
            ],
          ),
        ),
        if (_useWalletBalance && walletDeduction > 0) ...[
          const SizedBox(height: 8),
          _buildInvoiceRowText(
            'Còn lại trả tại Salon:',
            PriceFormatter.format(remainingAmountAtSalon),
            muted: true,
            strong: true,
          ),
        ],
      ],
    );
  }

  Widget _buildBottomBar(bool canProceed, WarrantyBookingState state) {
    final cubit = context.read<WarrantyBookingCubit>();
    final isLastStep = _currentStep == 3;
    final totalPrice = cubit.estimatedTotalPrice;

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
            if ((_currentStep == 1 || _currentStep == 2) && totalPrice > 0) ...[
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
                  Text(
                    PriceFormatter.format(totalPrice),
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                if (_currentStep > 0) ...[
                  TextButton.icon(
                    onPressed: state.isSubmitting
                        ? null
                        : () {
                            _pageController.previousPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
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
                ],
                Expanded(
                  child: Container(
                    height: 50,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(25),
                      gradient: LinearGradient(
                        colors: (!canProceed || state.isSubmitting)
                            ? [Colors.grey.shade400, Colors.grey.shade500]
                            : [
                                const Color(0xFFFF4081),
                                const Color(0xFFD81B60),
                              ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        if (canProceed && !state.isSubmitting)
                          BoxShadow(
                            color: const Color(0xFFD81B60).withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                      ],
                    ),
                    child: ElevatedButton(
                      onPressed: (canProceed && !state.isSubmitting)
                          ? () {
                              if (isLastStep) {
                                _handleSubmit();
                              } else {
                                _pageController.nextPage(
                                  duration: const Duration(milliseconds: 300),
                                  curve: Curves.easeInOut,
                                );
                              }
                            }
                          : null,
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
                              isLastStep
                                  ? (totalPrice == 0
                                      ? S.of(context).warrantyConfirmBtn
                                      : 'Thanh toán cọc')
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

class _HorizontalDashedLinePainter extends CustomPainter {
  final Color color;

  _HorizontalDashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    const dashWidth = 5.0;
    const dashSpace = 3.0;
    double startX = 0;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    while (startX < size.width) {
      canvas.drawLine(
        Offset(startX, 0),
        Offset(startX + dashWidth, 0),
        paint,
      );
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
