part of 'warranty_booking_cubit.dart';

/// Enum mô tả trạng thái loading cho từng phần của màn hình bảo hành.
enum WarrantyLoadStatus { initial, loading, loaded, error }

/// State của luồng đặt lịch bảo hành.
///
/// Luồng 4 bước:
///  1. Artist: chọn thợ (ưu tiên thợ cũ)
///  2. Service: tick/bỏ tick dịch vụ bảo hành + chọn thêm dịch vụ phát sinh
///  3. Schedule: chọn ngày/giờ (giữ chỗ 5 phút)
///  4. Summary: xác nhận, submit → free-flow (0đ) hoặc payment-qr (>0đ)
class WarrantyBookingState extends Equatable {
  // ── Loading states ────────────────────────────────────────────────
  final WarrantyLoadStatus artistsStatus;
  final WarrantyLoadStatus servicesStatus;
  final WarrantyLoadStatus timeSlotsStatus;

  // ── Dữ liệu từ API / payload ─────────────────────────────────────
  final List<Map<String, dynamic>> artists;
  final List<Map<String, dynamic>> services;

  // ── Context từ booking gốc ───────────────────────────────────────
  /// ID của booking gốc (booking đã hoàn thành cần được bảo hành).
  final String sourceBookingId;

  /// ID của thợ đã làm trước đây — dùng để pin lên đầu danh sách.
  final String sourceArtistId;

  /// Tên thợ đã làm trước đây (để hiển thị summary).
  final String sourceArtistName;

  /// Ngày hoàn thành booking gốc — dùng để validate deadline 7 ngày.
  final DateTime? sourceBookingDate;

  /// `true` nếu booking gốc còn trong thời hạn bảo hành (≤ 7 ngày từ
  /// `sourceBookingDate`). `false` nếu quá hạn → page phải khóa.
  final bool isWithinWarrantyWindow;

  /// Salon (đã fix cứng từ booking gốc — user KHÔNG được chọn lại).
  final Map<String, dynamic>? selectedBranch;

  // ── Danh sách dịch vụ bảo hành ──────────────────────────────────
  /// Danh sách đầy đủ từ booking gốc (bookkeeping).
  final List<Map<String, dynamic>> warrantyItems;

  /// User đã tick/bỏ tick những items nào (mặc định = tất cả).
  final List<Map<String, dynamic>> selectedWarrantyItems;

  // ── Dịch vụ phát sinh (extra services) ───────────────────────────
  /// User chọn thêm các dịch vụ phát sinh trong luồng bảo hành
  /// (vd: cắt móng, ngâm chân thảo mộc). Tính tiền riêng.
  final List<String?> selectedExtraServices;

  // ── User selections ──────────────────────────────────────────────
  final Map<String, dynamic>? selectedStylist;
  final bool noArtistSelected;
  final DateTime? selectedDate;
  final String? selectedTime;

  /// `holdToken` cuối cùng trả về 404 / không khả dụng — page dùng để
  /// phân biệt "lỗi lần đầu load" và "trạng thái rỗng hợp lệ".
  final String? timeSlotsLoadError;

  // ── Submit / Hold ────────────────────────────────────────────────
  final bool isSubmitting;
  final String? errorMessage;

  /// Hold-slot token, dùng khi tạo booking ở step cuối.
  final String? holdToken;
  final int holdRemainingSeconds;
  final bool isHolding;

  const WarrantyBookingState({
    this.artistsStatus = WarrantyLoadStatus.initial,
    this.servicesStatus = WarrantyLoadStatus.initial,
    this.timeSlotsStatus = WarrantyLoadStatus.initial,
    this.artists = const [],
    this.services = const [],
    this.sourceBookingId = '',
    this.sourceArtistId = '',
    this.sourceArtistName = '',
    this.sourceBookingDate,
    this.isWithinWarrantyWindow = true,
    this.selectedBranch,
    this.warrantyItems = const [],
    this.selectedWarrantyItems = const [],
    this.selectedExtraServices = const [],
    this.selectedStylist,
    this.noArtistSelected = false,
    this.selectedDate,
    this.selectedTime,
    this.timeSlotsLoadError,
    this.isSubmitting = false,
    this.errorMessage,
    this.holdToken,
    this.holdRemainingSeconds = 0,
    this.isHolding = false,
  });

  // ── Computed helpers ─────────────────────────────────────────────
  bool get isLoadingArtists => artistsStatus == WarrantyLoadStatus.loading;
  bool get isLoadingServices => servicesStatus == WarrantyLoadStatus.loading;
  bool get isLoadingTimes => timeSlotsStatus == WarrantyLoadStatus.loading;

  /// Đã chọn ngày chưa — điều kiện để fetch slot giờ.
  bool get isDateSelected => selectedDate != null;

  /// Đã chọn thợ hoặc chọn chế độ không thợ.
  bool get canSelectTime =>
      (selectedStylist != null || noArtistSelected) && isDateSelected;

  WarrantyBookingState copyWith({
    WarrantyLoadStatus? artistsStatus,
    WarrantyLoadStatus? servicesStatus,
    WarrantyLoadStatus? timeSlotsStatus,
    List<Map<String, dynamic>>? artists,
    List<Map<String, dynamic>>? services,
    String? sourceBookingId,
    String? sourceArtistId,
    String? sourceArtistName,
    DateTime? sourceBookingDate,
    bool? isWithinWarrantyWindow,
    Map<String, dynamic>? selectedBranch,
    bool clearBranch = false,
    List<Map<String, dynamic>>? warrantyItems,
    List<Map<String, dynamic>>? selectedWarrantyItems,
    List<String?>? selectedExtraServices,
    Map<String, dynamic>? selectedStylist,
    bool clearStylist = false,
    bool? noArtistSelected,
    DateTime? selectedDate,
    bool clearDate = false,
    String? selectedTime,
    bool clearTime = false,
    String? timeSlotsLoadError,
    bool clearTimeSlotsError = false,
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
      servicesStatus: servicesStatus ?? this.servicesStatus,
      timeSlotsStatus: timeSlotsStatus ?? this.timeSlotsStatus,
      artists: artists ?? this.artists,
      services: services ?? this.services,
      sourceBookingId: sourceBookingId ?? this.sourceBookingId,
      sourceArtistId: sourceArtistId ?? this.sourceArtistId,
      sourceArtistName: sourceArtistName ?? this.sourceArtistName,
      sourceBookingDate: sourceBookingDate ?? this.sourceBookingDate,
      isWithinWarrantyWindow:
          isWithinWarrantyWindow ?? this.isWithinWarrantyWindow,
      selectedBranch: clearBranch
          ? null
          : (selectedBranch ?? this.selectedBranch),
      warrantyItems: warrantyItems ?? this.warrantyItems,
      selectedWarrantyItems:
          selectedWarrantyItems ?? this.selectedWarrantyItems,
      selectedExtraServices:
          selectedExtraServices ?? this.selectedExtraServices,
      selectedStylist: clearStylist
          ? null
          : (selectedStylist ?? this.selectedStylist),
      noArtistSelected: noArtistSelected ?? this.noArtistSelected,
      selectedDate: clearDate ? null : (selectedDate ?? this.selectedDate),
      selectedTime: clearTime ? null : (selectedTime ?? this.selectedTime),
      timeSlotsLoadError: clearTimeSlotsError
          ? null
          : (timeSlotsLoadError ?? this.timeSlotsLoadError),
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
    servicesStatus,
    timeSlotsStatus,
    artists,
    services,
    sourceBookingId,
    sourceArtistId,
    sourceArtistName,
    sourceBookingDate,
    isWithinWarrantyWindow,
    selectedBranch,
    warrantyItems,
    selectedWarrantyItems,
    selectedExtraServices,
    selectedStylist,
    noArtistSelected,
    selectedDate,
    selectedTime,
    timeSlotsLoadError,
    isSubmitting,
    errorMessage,
    holdToken,
    holdRemainingSeconds,
    isHolding,
  ];
}
