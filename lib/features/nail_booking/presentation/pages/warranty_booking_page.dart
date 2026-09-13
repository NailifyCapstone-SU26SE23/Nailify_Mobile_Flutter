import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../generated/l10n.dart';

import '../cubit/warranty_booking_cubit.dart';
import '../widgets/artist_selection_list.dart';
import '../widgets/booking_date_selection.dart';
import '../widgets/booking_time_selection.dart';

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
    });
  }

  @override
  void dispose() {
    _holdTimer?.cancel();
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
    _cancelHold();
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
      _startHoldCountdown();
    } else {
      // hold thất bại -> reset time (cubit đã emit errorMessage + clearTime)
      setState(() {
        _selectedTime = null;
      });
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
      final result = await cubit.submitWarrantyBooking();
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
                  '${S.of(context).bookingSelectedCount(counts.values.fold<int>(0, (s, c) => s + c).toString())}',
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
          ...state.services.whereType<Map>().map((service) {
            final sMap = Map<String, dynamic>.from(service);
            final sId =
                sMap['serviceId']?.toString() ?? sMap['id']?.toString() ?? '';
            final name = sMap['serviceName']?.toString() ?? '';
            final price =
                sMap['price'] ?? sMap['basePrice'] ?? 0;
            final count = counts[sId] ?? 0;
            return _buildExtraServiceRow(sId, name, price, count);
          }),
        ],
      ),
    );
  }

  Widget _buildExtraServiceRow(
    String serviceId,
    String name,
    dynamic price,
    int count,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: count > 0
            ? AppColors.primary.withValues(alpha: 0.05)
            : Colors.grey.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: count > 0
              ? AppColors.primary.withValues(alpha: 0.3)
              : Colors.grey.shade200,
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name.isEmpty ? serviceId : name,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  PriceFormatter.format(price),
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (count > 0)
                IconButton(
                  onPressed: () =>
                      _handleExtraServiceRemoveAll(serviceId),
                  icon: const Icon(Icons.delete_outline, size: 20),
                  color: Colors.red,
                ),
              if (count > 0)
                IconButton(
                  onPressed: () =>
                      _handleExtraServiceDecrement(serviceId),
                  icon: const Icon(Icons.remove_circle_outline, size: 22),
                  color: AppColors.primary,
                ),
              IconButton(
                onPressed: () => _handleExtraServiceIncrement(serviceId),
                icon: const Icon(Icons.add_circle_rounded, size: 22),
                color: AppColors.primary,
              ),
            ],
          ),
        ],
      ),
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
    final cubit = context.read<WarrantyBookingCubit>();
    final totalPrice = cubit.estimatedTotalPrice;
    final extraTotal = cubit.extraServicesTotal;
    final isFree = totalPrice == 0;
    final salon = state.selectedBranch;
    final stylist = state.selectedStylist;
    final time = _selectedTime != null
        ? (_selectedTime!.length == 5
            ? '${_selectedTime!}:00'
            : _selectedTime!)
        : '';
    final date = _selectedDate;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSummaryCard(
            icon: Icons.storefront_rounded,
            title: S.of(context).bookingInfoSalon,
            value: salon?['name']?.toString() ??
                salon?['salonName']?.toString() ??
                '',
            subtitle: salon?['address']?.toString() ??
                salon?['salonAddress']?.toString() ??
                '',
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            icon: Icons.person_rounded,
            title: S.of(context).bookingInfoStaff,
            value: _noArtistSelected
                ? 'Tự động phân công'
                : (stylist?['fullName']?.toString() ??
                    state.sourceArtistName),
          ),
          const SizedBox(height: 12),
          _buildSummaryCard(
            icon: Icons.calendar_today_rounded,
            title: S.of(context).bookingInfoTime,
            value: date == null
                ? ''
                : '${date.day}/${date.month}/${date.year} • $time',
          ),
          const SizedBox(height: 12),
          _buildPaymentDetails(state, extraTotal, totalPrice, isFree),
        ],
      ),
    );
  }

  Widget _buildPaymentDetails(
    WarrantyBookingState state,
    int extraTotal,
    int totalPrice,
    bool isFree,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              const Icon(Icons.shield_outlined, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                S.of(context).bookingPaymentDetails,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // ── Warranty items (miễn phí) ──────────────────────────
          ...state.selectedWarrantyItems.map((item) {
            final names = [
              item['nailVariantName']?.toString().trim() ?? '',
              item['customerNailName']?.toString().trim() ?? '',
              item['serviceName']?.toString().trim() ?? '',
            ].where((n) => n.isNotEmpty).toList();
            final name = names.isEmpty
                ? S.of(context).bookingWarrantyDefault
                : names.join(' & ');
            return _buildPaymentRow(name, 0, muted: true);
          }),
          if (state.selectedExtraServices
              .whereType<String>()
              .isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              S.of(context).bookingAddonServices,
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 6),
            ..._buildExtraServiceRows(state),
          ],
          const Divider(height: 16),
          // ── Subtotal (chỉ extra services, warranty = 0) ──────
          _buildPaymentRow(
            'Tạm tính (dịch vụ phát sinh)',
            extraTotal,
            muted: true,
          ),
          // ── Discount (giữ chỗ hiển thị — hiện chưa có) ────────
          // Nếu tương lai tích hợp voucher sẽ hiện ở đây.
          // ── Total ─────────────────────────────────────────────
          const Divider(height: 16),
          _buildPaymentRow(
            S.of(context).bookingTotal,
            totalPrice,
            strong: true,
            highlight: true,
          ),
          if (!isFree) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Colors.amber.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline,
                      color: Colors.amber.shade800, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      S.of(context).warrantyDepositNote,
                      style: TextStyle(
                        fontSize: 12.5,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  List<Widget> _buildExtraServiceRows(WarrantyBookingState state) {
    final cubit = context.read<WarrantyBookingCubit>();
    final counts = <String, int>{};
    for (final id in state.selectedExtraServices.whereType<String>()) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts.entries.map((entry) {
      final id = entry.key;
      final count = entry.value;
      final unit = cubit.servicePriceById(id);
      final name = cubit.serviceNameById(id);
      final lineTotal = unit * count;
      final label = count > 1 ? '$name × $count' : name;
      return _buildPaymentRow(
        S.of(context).bookingExtraService(label),
        lineTotal,
        muted: true,
      );
    }).toList();
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
            price == 0 ? S.of(context).warrantyFree : PriceFormatter.format(price),
            style: TextStyle(
              fontWeight: strong ? FontWeight.bold : FontWeight.w600,
              color: price == 0
                  ? Colors.green
                  : (highlight ? AppColors.primary : AppColors.textPrimary),
              fontSize: highlight ? 18 : 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard({
    required IconData icon,
    required String title,
    required String value,
    String? subtitle,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppColors.primary, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.grey.shade700,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar(bool canProceed, WarrantyBookingState state) {
    final isLastStep = _currentStep == 3;
    final totalPrice = context.read<WarrantyBookingCubit>().estimatedTotalPrice;
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
        decoration: BoxDecoration(
          color: const Color(0xFFFDFBF7),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 12,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SizedBox(
          width: double.infinity,
          height: 52,
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
              backgroundColor: AppColors.primary,
              disabledBackgroundColor: Colors.grey.shade300,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
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
                : Text(
                    isLastStep
                        ? (totalPrice == 0
                            ? S.of(context).warrantyConfirmBtn
                            : S.of(context).warrantyConfirmDepositBtn)
                        : S.of(context).bookingContinueBtn,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
