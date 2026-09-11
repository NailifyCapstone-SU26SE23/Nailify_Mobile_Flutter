import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
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
  bool _isLoadingTimes = false;
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
    final state = context.read<WarrantyBookingCubit>().state;
    final salonId = state.selectedBranch?['salonId']?.toString() ?? '';
    final artistId = _noArtistSelected
        ? null
        : (_selectedStylistId ??
            state.selectedStylist?['nailArtistId']?.toString());
    if (salonId.isEmpty) return;
    if (!_noArtistSelected && (artistId == null || artistId.isEmpty)) return;

    setState(() => _isLoadingTimes = true);
    try {
      final cubit = context.read<WarrantyBookingCubit>();
      // Dùng repository thông qua cubit: gọi thẳng cubit service qua helper
      // tạm — thực tế ta dùng cubit.holdSelectedSlot() sau khi user chọn giờ,
      // còn việc fetch slot list tạm thời dùng qua cubit thông qua public API.
      final bookingItems = state.selectedWarrantyItems
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final List<dynamic> slots;
      if (_noArtistSelected || artistId == null) {
        // Không có artist → lấy slot của salon.
        // Sử dụng repo của cubit thông qua helper public (xem bên dưới).
        slots = await cubit.loadSalonAvailableSlots(
          salonId: salonId,
          bookingDate: _formatDate(_selectedDate!),
          bookingItems: bookingItems,
        );
      } else {
        slots = await cubit.loadArtistAvailableSlots(
          artistId: artistId,
          bookingDate: _formatDate(_selectedDate!),
        );
      }
      if (!mounted) return;
      setState(() {
        _timeSlots = slots;
        _isLoadingTimes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _timeSlots = [];
        _isLoadingTimes = false;
      });
    }
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
    // Sync state với cubit để holdSelectedSlot dùng được.
    cubit.selectDateForHolder(_selectedDate!);
    cubit.selectStylistForHolder(artistObj, noArtist: _noArtistSelected);
    cubit.selectTimeForHolder(time);
    final ok = await cubit.holdSelectedSlot();
    if (!mounted) return;
    if (ok) {
      _startHoldCountdown();
    } else {
      // hold thất bại -> reset time
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
    // Lắng nghe state holdToken + holdRemainingSeconds từ cubit.
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final s = context.read<WarrantyBookingCubit>().state;
      if (s.holdToken == null) {
        _holdTimer?.cancel();
        if (_selectedTime != null) {
          setState(() {
            _selectedTime = null;
          });
          _showSnackBar('Thời gian giữ chỗ đã hết. Vui lòng chọn lại khung giờ.');
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

  // ── Submit ───────────────────────────────────────────────────────
  Future<void> _handleSubmit() async {
    if (_selectedTime == null || _selectedDate == null) return;
    final cubit = context.read<WarrantyBookingCubit>();
    try {
      final response = await cubit.submitWarrantyBooking();
      if (!mounted) return;
      final state = cubit.state;
      final time = _selectedTime!;
      final formattedTime = time.length == 5 ? '$time:00' : time;
      final stylistName = _noArtistSelected
          ? 'Tự động phân công'
          : (state.selectedStylist?['fullName']?.toString() ?? '');
      final serviceName = _buildWarrantyServiceSummary(state);
      context.go(
        '/booking-success',
        extra: {
          'bookingId': response['bookingId']?.toString() ?? '',
          'serviceName': serviceName,
          'date': _selectedDate,
          'time': formattedTime,
          'stylistName': stylistName,
          'totalPrice': 0,
        },
      );
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('Đặt lịch thất bại: $e');
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

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-${d}T00:00:00';
  }

  // ── BUILD ────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return BlocConsumer<WarrantyBookingCubit, WarrantyBookingState>(
      listenWhen: (prev, curr) =>
          curr.errorMessage != null && prev.errorMessage != curr.errorMessage,
      listener: (context, state) {
        _showSnackBar(state.errorMessage!);
        context.read<WarrantyBookingCubit>().clearError();
      },
      builder: (context, state) {
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
              _buildBottomBar(canProceed),
            ],
          ),
        );
      },
    );
  }

  bool _canProceedForStep(WarrantyBookingState state) {
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

  Widget _buildArtistStep(WarrantyBookingState state) {
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

  Widget _buildServiceStep(WarrantyBookingState state) {
    if (state.warrantyItems.isEmpty) {
      return const Center(child: Text('Không có dịch vụ bảo hành.'));
    }
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
            style: TextStyle(
              fontSize: 13,
              color: Colors.grey.shade700,
            ),
          ),
          const SizedBox(height: 16),
          ...state.warrantyItems.map((item) {
            return _buildWarrantyItemTile(item, state);
          }),
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
          BookingTimeSelection(
            timeSlots: _timeSlots,
            isLoading: _isLoadingTimes,
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

  Widget _buildSummaryStep(WarrantyBookingState state) {
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
          // ── Salon ────────────────────────────────────────────────
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
          // ── Stylist ──────────────────────────────────────────────
          _buildSummaryCard(
            icon: Icons.person_rounded,
            title: S.of(context).bookingInfoStaff,
            value: _noArtistSelected
                ? 'Tự động phân công'
                : (stylist?['fullName']?.toString() ??
                    state.sourceArtistName),
          ),
          const SizedBox(height: 12),
          // ── Schedule ─────────────────────────────────────────────
          _buildSummaryCard(
            icon: Icons.calendar_today_rounded,
            title: S.of(context).bookingInfoTime,
            value: date == null
                ? ''
                : '${date.day}/${date.month}/${date.year} • $time',
          ),
          const SizedBox(height: 12),
          // ── Warranty items ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.grey.shade100),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
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
                        Icons.shield_outlined,
                        color: AppColors.primary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      S.of(context).warrantyStepServices,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                ...state.selectedWarrantyItems.map((item) {
                  final names = [
                    item['nailVariantName']?.toString().trim() ?? '',
                    item['customerNailName']?.toString().trim() ?? '',
                    item['serviceName']?.toString().trim() ?? '',
                  ].where((n) => n.isNotEmpty).toList();
                  final name = names.isEmpty
                      ? S.of(context).bookingWarrantyDefault
                      : names.join(' & ');
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.check_circle,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                        Text(
                          S.of(context).warrantyFree,
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      S.of(context).bookingInfoTotal,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      S.of(context).warrantyFree,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 17,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
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

  Widget _buildBottomBar(bool canProceed) {
    final isLastStep = _currentStep == 3;
    final isSubmitting =
        context.read<WarrantyBookingCubit>().state.isSubmitting;
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
            onPressed: (canProceed && !isSubmitting)
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
            child: isSubmitting
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
                        ? S.of(context).warrantyConfirmBtn
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
