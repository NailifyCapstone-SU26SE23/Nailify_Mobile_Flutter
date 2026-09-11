part of 'warranty_booking_cubit.dart';

/// Enum mô tả trạng thái loading cho từng phần của màn hình bảo hành.
enum WarrantyLoadStatus { initial, loading, loaded, error }

/// State của luồng đặt lịch bảo hành.
///
/// Luồng 4 bước:
///  1. Artist: chọn thợ (ưu tiên thợ cũ)
///  2. Service: tick/bỏ tick các dịch vụ bảo hành (KHÔNG chọn thêm)
///  3. Schedule: chọn ngày/giờ (giữ chỗ 5 phút)
///  4. Summary: xác nhận, submit thẳng `POST /Bookings`
class WarrantyBookingState extends Equatable {
  // ── Loading states ────────────────────────────────────────────────
  final WarrantyLoadStatus artistsStatus;

  // ── Dữ liệu từ API / payload ─────────────────────────────────────
  final List<Map<String, dynamic>> artists;

  // ── Context từ booking gốc ───────────────────────────────────────
  /// ID của booking gốc (booking đã hoàn thành cần được bảo hành).
  final String sourceBookingId;

  /// ID của thợ đã làm trước đây — dùng để pin lên đầu danh sách.
  final String sourceArtistId;

  /// Tên thợ đã làm trước đây (để hiển thị summary).
  final String sourceArtistName;

  /// Salon (đã fix cứng từ booking gốc — user KHÔNG được chọn lại).
  final Map<String, dynamic>? selectedBranch;

  // ── Danh sách dịch vụ bảo hành ──────────────────────────────────
  /// Danh sách đầy đủ từ booking gốc (bookkeeping).
  final List<Map<String, dynamic>> warrantyItems;

  /// User đã tick/bỏ tick những items nào (mặc định = tất cả).
  final List<Map<String, dynamic>> selectedWarrantyItems;

  // ── User selections ──────────────────────────────────────────────
  final Map<String, dynamic>? selectedStylist;
  final bool noArtistSelected;
  final DateTime? selectedDate;
  final String? selectedTime;

  // ── Submit / Hold ────────────────────────────────────────────────
  final bool isSubmitting;
  final String? errorMessage;

  /// Hold-slot token, dùng khi tạo booking ở step cuối.
  final String? holdToken;
  final int holdRemainingSeconds;
  final bool isHolding;

  const WarrantyBookingState({
    this.artistsStatus = WarrantyLoadStatus.initial,
    this.artists = const [],
    this.sourceBookingId = '',
    this.sourceArtistId = '',
    this.sourceArtistName = '',
    this.selectedBranch,
    this.warrantyItems = const [],
    this.selectedWarrantyItems = const [],
    this.selectedStylist,
    this.noArtistSelected = false,
    this.selectedDate,
    this.selectedTime,
    this.isSubmitting = false,
    this.errorMessage,
    this.holdToken,
    this.holdRemainingSeconds = 0,
    this.isHolding = false,
  });

  // ── Computed helpers ─────────────────────────────────────────────
  bool get isLoadingArtists => artistsStatus == WarrantyLoadStatus.loading;

  /// Đã chọn ngày chưa — điều kiện để fetch slot giờ.
  bool get isDateSelected => selectedDate != null;

  /// Đã chọn thợ hoặc chọn chế độ không thợ.
  bool get canSelectTime =>
      (selectedStylist != null || noArtistSelected) && isDateSelected;

  WarrantyBookingState copyWith({
    WarrantyLoadStatus? artistsStatus,
    List<Map<String, dynamic>>? artists,
    String? sourceBookingId,
    String? sourceArtistId,
    String? sourceArtistName,
    Map<String, dynamic>? selectedBranch,
    bool clearBranch = false,
    List<Map<String, dynamic>>? warrantyItems,
    List<Map<String, dynamic>>? selectedWarrantyItems,
    Map<String, dynamic>? selectedStylist,
    bool clearStylist = false,
    bool? noArtistSelected,
    DateTime? selectedDate,
    bool clearDate = false,
    String? selectedTime,
    bool clearTime = false,
    bool? isSubmitting,
    String? errorMessage,
    bool clearError = false,
    String? holdToken,
    bool clearHoldToken = false,
    int? holdRemainingSeconds,
    bool? isHolding,
  }) {
    return WarrantyBookingState(
      artistsStatus: artistsStatus ?? this.artistsStatus,
      artists: artists ?? this.artists,
      sourceBookingId: sourceBookingId ?? this.sourceBookingId,
      sourceArtistId: sourceArtistId ?? this.sourceArtistId,
      sourceArtistName: sourceArtistName ?? this.sourceArtistName,
      selectedBranch:
          clearBranch ? null : (selectedBranch ?? this.selectedBranch),
      warrantyItems: warrantyItems ?? this.warrantyItems,
      selectedWarrantyItems:
          selectedWarrantyItems ?? this.selectedWarrantyItems,
      selectedStylist:
          clearStylist ? null : (selectedStylist ?? this.selectedStylist),
      noArtistSelected: noArtistSelected ?? this.noArtistSelected,
      selectedDate: clearDate ? null : (selectedDate ?? this.selectedDate),
      selectedTime: clearTime ? null : (selectedTime ?? this.selectedTime),
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      holdToken: clearHoldToken ? null : (holdToken ?? this.holdToken),
      holdRemainingSeconds: holdRemainingSeconds ?? this.holdRemainingSeconds,
      isHolding: isHolding ?? this.isHolding,
    );
  }

  @override
  List<Object?> get props => [
        artistsStatus,
        artists,
        sourceBookingId,
        sourceArtistId,
        sourceArtistName,
        selectedBranch,
        warrantyItems,
        selectedWarrantyItems,
        selectedStylist,
        noArtistSelected,
        selectedDate,
        selectedTime,
        isSubmitting,
        errorMessage,
        holdToken,
        holdRemainingSeconds,
        isHolding,
      ];
}
