part of 'nail_booking_cubit.dart';

/// Enum mô tả trạng thái loading cho từng phần của màn hình.
enum NailBookingLoadStatus { initial, loading, loaded, error }

class NailBookingState extends Equatable {
  // ── Loading states ─────────────────────────────────────────────────────────
  final NailBookingLoadStatus salonsStatus;
  final NailBookingLoadStatus artistsStatus;
  final NailBookingLoadStatus timeSlotsStatus;

  // ── Dữ liệu từ API ────────────────────────────────────────────────────────
  final List<Map<String, dynamic>> salons;
  final List<Map<String, dynamic>> services;
  final List<Map<String, dynamic>> artists;
  final List<Map<String, dynamic>> timeSlots;

  // ── Lựa chọn của user ─────────────────────────────────────────────────────
  final Map<String, dynamic>? selectedBranch;
  final String? selectedSeatId;
  final List<String?> selectedExtraServices;
  final DateTime? selectedDate;
  final Map<String, dynamic>? selectedStylist;
  final bool noArtistSelected;
  final String? selectedTime;
  final List<dynamic> selectedPromotions; // PromotionModel list
  final List<Map<String, dynamic>> selectedWarrantyItems;

  // ── Trạng thái submit ─────────────────────────────────────────────────────
  final bool isSubmitting;
  final String? errorMessage;

  // ── Giữ chỗ (Hold Slot) ──────────────────────────────────────────
  /// Token xác nhận việc giữ chỗ, dùng để truyền vào API tạo booking.
  final String? holdToken;
  /// Thời điểm hết hạn theo UTC của server (để đồng bộ đồng hồ).
  final DateTime? holdExpiresAt;
  /// Số giây còn lại (được cập nhật mỗi giây bởi Timer).
  final int holdRemainingSeconds;
  /// Đang trong trạng thái giữ chỗ (hiện countdown bar).
  final bool isHolding;

  const NailBookingState({
    this.salonsStatus = NailBookingLoadStatus.initial,
    this.artistsStatus = NailBookingLoadStatus.initial,
    this.timeSlotsStatus = NailBookingLoadStatus.initial,
    this.salons = const [],
    this.services = const [],
    this.artists = const [],
    this.timeSlots = const [],
    this.selectedBranch,
    this.selectedSeatId,
    this.selectedExtraServices = const [],
    this.selectedDate,
    this.selectedStylist,
    this.noArtistSelected = false,
    this.selectedTime,
    this.selectedPromotions = const [],
    this.selectedWarrantyItems = const [],
    this.isSubmitting = false,
    this.errorMessage,
    this.holdToken,
    this.holdExpiresAt,
    this.holdRemainingSeconds = 0,
    this.isHolding = false,
  });

  // ── Computed helpers ──────────────────────────────────────────────────────

  /// Đã chọn ngày chưa — điều kiện để hiện tab chọn thợ.
  bool get isDateSelected => selectedDate != null;

  /// Đã chọn thợ hoặc chọn chế độ không thợ — điều kiện để hiện grid giờ.
  bool get canSelectTime =>
      (selectedStylist != null || noArtistSelected) && isDateSelected;

  bool get isLoadingArtists => artistsStatus == NailBookingLoadStatus.loading;
  bool get isLoadingTimes => timeSlotsStatus == NailBookingLoadStatus.loading;
  bool get isLoadingSalons => salonsStatus == NailBookingLoadStatus.loading;

  NailBookingState copyWith({
    NailBookingLoadStatus? salonsStatus,
    NailBookingLoadStatus? artistsStatus,
    NailBookingLoadStatus? timeSlotsStatus,
    List<Map<String, dynamic>>? salons,
    List<Map<String, dynamic>>? services,
    List<Map<String, dynamic>>? artists,
    List<Map<String, dynamic>>? timeSlots,
    Map<String, dynamic>? selectedBranch,
    bool clearBranch = false,
    String? selectedSeatId,
    bool clearSeat = false,
    List<String?>? selectedExtraServices,
    DateTime? selectedDate,
    bool clearDate = false,
    Map<String, dynamic>? selectedStylist,
    bool clearStylist = false,
    bool? noArtistSelected,
    String? selectedTime,
    bool clearTime = false,
    List<dynamic>? selectedPromotions,
    List<Map<String, dynamic>>? selectedWarrantyItems,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    // Hold slot fields
    String? holdToken,
    bool clearHoldToken = false,
    DateTime? holdExpiresAt,
    int? holdRemainingSeconds,
    bool? isHolding,
  }) {
    return NailBookingState(
      salonsStatus: salonsStatus ?? this.salonsStatus,
      artistsStatus: artistsStatus ?? this.artistsStatus,
      timeSlotsStatus: timeSlotsStatus ?? this.timeSlotsStatus,
      salons: salons ?? this.salons,
      services: services ?? this.services,
      artists: artists ?? this.artists,
      timeSlots: timeSlots ?? this.timeSlots,
      selectedBranch: clearBranch
          ? null
          : (selectedBranch ?? this.selectedBranch),
      selectedSeatId: clearSeat
          ? null
          : (selectedSeatId ?? this.selectedSeatId),
      selectedExtraServices:
          selectedExtraServices ?? this.selectedExtraServices,
      selectedDate: clearDate ? null : (selectedDate ?? this.selectedDate),
      selectedStylist: clearStylist
          ? null
          : (selectedStylist ?? this.selectedStylist),
      noArtistSelected: noArtistSelected ?? this.noArtistSelected,
      selectedTime: clearTime ? null : (selectedTime ?? this.selectedTime),
      selectedPromotions: selectedPromotions ?? this.selectedPromotions,
      selectedWarrantyItems:
          selectedWarrantyItems ?? this.selectedWarrantyItems,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      holdToken: clearHoldToken ? null : (holdToken ?? this.holdToken),
      holdExpiresAt: clearHoldToken ? null : (holdExpiresAt ?? this.holdExpiresAt),
      holdRemainingSeconds: holdRemainingSeconds ?? this.holdRemainingSeconds,
      isHolding: isHolding ?? this.isHolding,
    );
  }

  @override
  List<Object?> get props => [
        salonsStatus,
        artistsStatus,
        timeSlotsStatus,
        salons,
        services,
        artists,
        timeSlots,
        selectedBranch,
        selectedSeatId,
        selectedExtraServices,
        selectedDate,
        selectedStylist,
        noArtistSelected,
        selectedTime,
        selectedPromotions,
        selectedWarrantyItems,
        isSubmitting,
        errorMessage,
        holdToken,
        holdExpiresAt,
        holdRemainingSeconds,
        isHolding,
      ];
}
