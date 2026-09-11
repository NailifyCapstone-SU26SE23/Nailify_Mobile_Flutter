import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/exceptions.dart';
import '../../data/nail_booking_repository_impl.dart';
import '../../domain/repositories/nail_booking_repository.dart';

part 'warranty_booking_state.dart';

/// Cubit riêng cho luồng đặt lịch bảo hành.
///
/// Khác với `NailBookingCubit` (luồng booking thường):
///  - Salon được fix cứng từ booking gốc (không cho chọn lại).
///  - Không có nail variant / shape method.
///  - Không cho chọn thêm dịch vụ phát sinh.
///  - Submit gọi thẳng `POST /Bookings` với `warrantyForBookingId` (KHÔNG
///    qua `/payments/create-for-request`).
///  - Tổng tiền = 0, navigate sang `/booking-success`.
class WarrantyBookingCubit extends Cubit<WarrantyBookingState> {
  final NailBookingRepository _repository;
  Timer? _holdTimer;

  WarrantyBookingCubit({NailBookingRepository? repository})
      : _repository = repository ?? NailBookingRepositoryImpl(),
        super(const WarrantyBookingState());

  // ══════════════════════════════════════════════════════════════
  // LOAD CONTEXT
  // ══════════════════════════════════════════════════════════════

  /// Load context từ booking gốc: salon + danh sách thợ + danh sách
  /// booking items sẽ được bảo hành.
  ///
  /// `sourceBooking` chứa các key: `salonId`, `salonName?`,
  /// `sourceArtistId?`, `sourceArtistName?`, `bookingItems` (List<Map>).
  Future<void> loadWarrantyContext(Map<String, dynamic> sourceBooking) async {
    final salonId = sourceBooking['salonId']?.toString() ?? '';
    final rawItems = sourceBooking['bookingItems'];
    final warrantyItems = <Map<String, dynamic>>[];
    if (rawItems is List) {
      for (final e in rawItems) {
        if (e is Map) warrantyItems.add(Map<String, dynamic>.from(e));
      }
    }

    // Tìm thông tin salon từ API để hiển thị (tên, địa chỉ) — dù là luồng
    // bảo hành, page Summary vẫn cần show tên salon + địa chỉ.
    Map<String, dynamic>? branch;
    if (salonId.isNotEmpty) {
      try {
        final salons = await _repository.getSalons();
        for (final s in salons) {
          if (s['salonId']?.toString() == salonId) {
            branch = s;
            break;
          }
        }
      } catch (_) {
        branch = {
          'salonId': salonId,
          'name': sourceBooking['salonName']?.toString() ?? '',
          if (sourceBooking['salonAddress'] != null)
            'salonAddress': sourceBooking['salonAddress'],
        };
      }
    }

    emit(
      state.copyWith(
        sourceBookingId: sourceBooking['sourceBookingId']?.toString() ?? '',
        sourceArtistId: sourceBooking['sourceArtistId']?.toString() ?? '',
        sourceArtistName: sourceBooking['sourceArtistName']?.toString() ?? '',
        selectedBranch: branch,
        selectedStylist: sourceBooking['sourceStylist'] is Map
            ? Map<String, dynamic>.from(sourceBooking['sourceStylist'] as Map)
            : null,
        noArtistSelected: sourceBooking['noArtistSelected'] == true,
        warrantyItems: warrantyItems,
        // Mặc định tick tất cả items — user có thể bỏ tick ở UI.
        selectedWarrantyItems: List<Map<String, dynamic>>.from(warrantyItems),
      ),
    );

    // Load artists của salon để user chọn (nếu chưa pre-select từ sourceArtistId).
    await loadArtists(salonId);
  }

  Future<void> loadArtists(String salonId) async {
    if (salonId.isEmpty) return;
    emit(state.copyWith(artistsStatus: WarrantyLoadStatus.loading));
    try {
      final artists = await _repository.getArtistsBySalon(salonId);
      emit(
        state.copyWith(
          artists: artists,
          artistsStatus: WarrantyLoadStatus.loaded,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          artistsStatus: WarrantyLoadStatus.error,
          errorMessage: 'Lỗi tải danh sách thợ: $e',
        ),
      );
    }
  }

  // ══════════════════════════════════════════════════════════════
  // USER SELECTIONS
  // ══════════════════════════════════════════════════════════════

  void selectStylist(Map<String, dynamic>? stylist) {
    emit(
      state.copyWith(
        selectedStylist: stylist,
        noArtistSelected: stylist == null,
        clearTime: true,
        clearHoldToken: true,
        isHolding: false,
        holdRemainingSeconds: 0,
      ),
    );
    _cancelHoldTimer();
    final oldToken = state.holdToken;
    if (oldToken != null && oldToken.isNotEmpty) {
      _repository.cancelHoldSlot(oldToken);
    }
  }

  void setNoArtist(bool noArtist) {
    emit(
      state.copyWith(
        noArtistSelected: noArtist,
        clearStylist: noArtist,
        clearTime: true,
        clearHoldToken: true,
        isHolding: false,
        holdRemainingSeconds: 0,
      ),
    );
    _cancelHoldTimer();
    final oldToken = state.holdToken;
    if (oldToken != null && oldToken.isNotEmpty) {
      _repository.cancelHoldSlot(oldToken);
    }
  }

  void selectDate(DateTime date) {
    emit(
      state.copyWith(
        selectedDate: date,
        clearTime: true,
        clearHoldToken: true,
        isHolding: false,
        holdRemainingSeconds: 0,
      ),
    );
    _cancelHoldTimer();
    final oldToken = state.holdToken;
    if (oldToken != null && oldToken.isNotEmpty) {
      _repository.cancelHoldSlot(oldToken);
    }
  }

  Future<void> selectTime(String time) async {
    // Đổi giờ -> huỷ hold cũ nếu có.
    final oldToken = state.holdToken;
    if (oldToken != null && oldToken.isNotEmpty) {
      _cancelHoldTimer();
      _repository.cancelHoldSlot(oldToken);
    }
    emit(
      state.copyWith(
        selectedTime: time,
        clearHoldToken: true,
        isHolding: false,
        holdRemainingSeconds: 0,
      ),
    );
    // Tự động giữ chỗ khi user chọn giờ.
    await holdSelectedSlot();
  }

  void toggleWarrantyItem(Map<String, dynamic> item, bool selected) {
    final next = List<Map<String, dynamic>>.from(state.selectedWarrantyItems);
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

    if (selected) {
      if (!next.any((s) => isSame(s, item))) next.add(item);
    } else {
      next.removeWhere((s) => isSame(s, item));
    }
    emit(state.copyWith(selectedWarrantyItems: next));
  }

  // ══════════════════════════════════════════════════════════════
  // HOLD SLOT
  // ══════════════════════════════════════════════════════════════

  /// Giữ chỗ khi user chọn giờ. Trả về true nếu thành công.
  Future<bool> holdSelectedSlot() async {
    final time = state.selectedTime;
    if (time == null) return false;

    if (state.noArtistSelected) {
      // Không cần hold slot cho luồng "tự động phân công".
      return true;
    }

    final branch = state.selectedBranch;
    final date = state.selectedDate;
    final stylist = state.selectedStylist;
    if (branch == null || date == null || stylist == null) return false;

    final salonId = branch['salonId']?.toString() ?? '';
    final artistId = stylist['nailArtistId']?.toString() ?? '';
    if (salonId.isEmpty || artistId.isEmpty) return false;

    emit(state.copyWith(isSubmitting: true));
    try {
      final formattedTime = time.length == 5 ? '$time:00' : time;
      final bookingItems = _buildBookingItemsForHold();

      final data = await _repository.holdSlot(
        salonId: salonId,
        nailArtistId: artistId,
        bookingDate: _formatDate(date),
        startTime: formattedTime,
        bookingItems: bookingItems,
      );

      final token = data['holdToken']?.toString();
      if (token == null || token.isEmpty) {
        emit(
          state.copyWith(
            isSubmitting: false,
            clearHoldToken: true,
            isHolding: false,
            holdRemainingSeconds: 0,
            errorMessage:
                'Không thể giữ khung giờ này. Vui lòng chọn giờ khác.',
          ),
        );
        return false;
      }

      final remaining =
          (data['remainingSeconds'] as num?)?.toInt() ?? 300;
      emit(
        state.copyWith(
          isSubmitting: false,
          holdToken: token,
          holdRemainingSeconds: remaining,
          isHolding: true,
        ),
      );
      _startHoldTimer(token);
      return true;
    } catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          clearHoldToken: true,
          isHolding: false,
          holdRemainingSeconds: 0,
          errorMessage: _readableError(e),
        ),
      );
      return false;
    }
  }

  void _startHoldTimer(String token) {
    _holdTimer?.cancel();
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isClosed) {
        _holdTimer?.cancel();
        return;
      }
      final remaining = (state.holdRemainingSeconds - 1).clamp(0, 600);
      if (state.holdToken != token) {
        _holdTimer?.cancel();
        return;
      }
      if (remaining <= 0) {
        _holdTimer?.cancel();
        emit(
          state.copyWith(
            clearHoldToken: true,
            isHolding: false,
            holdRemainingSeconds: 0,
            clearTime: true,
            errorMessage: 'Thời gian giữ chỗ đã hết. Vui lòng chọn lại khung giờ.',
          ),
        );
      } else {
        emit(state.copyWith(holdRemainingSeconds: remaining));
      }
    });
  }

  void _cancelHoldTimer() {
    _holdTimer?.cancel();
    _holdTimer = null;
  }

  Future<void> cancelCurrentHold() async {
    final token = state.holdToken;
    _cancelHoldTimer();
    emit(
      state.copyWith(
        clearHoldToken: true,
        isHolding: false,
        holdRemainingSeconds: 0,
      ),
    );
    if (token != null && token.isNotEmpty) {
      await _repository.cancelHoldSlot(token);
    }
  }

  // ══════════════════════════════════════════════════════════════
  // SUBMIT
  // ══════════════════════════════════════════════════════════════

  /// Tạo booking bảo hành. Trả về response map từ backend (chứa bookingId).
  /// Throw nếu lỗi — page sẽ catch và hiển thị snackbar.
  Future<Map<String, dynamic>> submitWarrantyBooking() async {
    final branch = state.selectedBranch;
    final date = state.selectedDate;
    final time = state.selectedTime;
    if (branch == null || date == null || time == null) {
      throw Exception('Thiếu thông tin: chi nhánh / ngày / giờ.');
    }
    if (state.sourceBookingId.isEmpty) {
      throw Exception('Thiếu ID booking gốc.');
    }
    if (state.selectedWarrantyItems.isEmpty) {
      throw Exception('Vui lòng chọn ít nhất một dịch vụ bảo hành.');
    }

    emit(state.copyWith(isSubmitting: true, clearError: true));
    try {
      final formattedTime = time.length == 5 ? '$time:00' : time;
      final artistId = state.noArtistSelected
          ? null
          : state.selectedStylist?['nailArtistId']?.toString();

      final response = await _repository.createBooking(
        salonId: branch['salonId']?.toString() ?? '',
        bookingDate: _formatDate(date),
        startTime: formattedTime,
        artistId: artistId,
        nailVariantId: 0,
        serviceIds: const [],
        holdToken: state.holdToken,
        warrantyForBookingId: state.sourceBookingId,
        warrantyBookingItems: state.selectedWarrantyItems,
      );

      _cancelHoldTimer();
      emit(
        state.copyWith(
          isSubmitting: false,
          clearHoldToken: true,
          isHolding: false,
          holdRemainingSeconds: 0,
        ),
      );
      return response;
    } catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          errorMessage: 'Không thể đặt lịch bảo hành: $e',
        ),
      );
      rethrow;
    }
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  // ══════════════════════════════════════════════════════════════
  // INTERNAL HELPERS (cho WarrantyBookingPage)
  // ══════════════════════════════════════════════════════════════

  /// Wrapper public cho page gọi fetch slots khi user chọn ngày ở step 3.
  Future<List<dynamic>> loadArtistAvailableSlots({
    required String artistId,
    required String bookingDate,
  }) async {
    return _repository.getArtistAvailableSlots(
      artistId: artistId,
      bookingDate: bookingDate,
    );
  }

  /// Wrapper public cho page gọi fetch slots khi user chọn ngày ở step 3
  /// (luồng "tự động phân công" - không chọn thợ).
  Future<List<dynamic>> loadSalonAvailableSlots({
    required String salonId,
    required String bookingDate,
    required List<Map<String, dynamic>> bookingItems,
  }) async {
    return _repository.getSalonAvailableSlots(
      salonId: salonId,
      bookingDate: bookingDate,
      bookingItems: bookingItems,
    );
  }

  /// Sync page-local date với cubit (chỉ dùng cho warranty flow).
  void selectDateForHolder(DateTime date) {
    emit(state.copyWith(selectedDate: date));
  }

  /// Sync page-local stylist với cubit (chỉ dùng cho warranty flow).
  void selectStylistForHolder(
    Map<String, dynamic>? stylist, {
    bool noArtist = false,
  }) {
    emit(
      state.copyWith(
        selectedStylist: stylist,
        noArtistSelected: noArtist,
        clearStylist: stylist == null,
      ),
    );
  }

  /// Sync page-local time với cubit (chỉ dùng cho warranty flow).
  void selectTimeForHolder(String time) {
    emit(state.copyWith(selectedTime: time));
  }

  // ══════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════

  /// Build payload bookingItems cho API hold-slot — dùng các items user
  /// đã tick ở bước "Dịch vụ bảo hành" để backend tính duration.
  List<Map<String, dynamic>> _buildBookingItemsForHold() {
    return state.selectedWarrantyItems
        .map(
          (e) => Map<String, dynamic>.from(e)
            ..['quantity'] = (e['quantity'] is num)
                ? (e['quantity'] as num).toInt()
                : (int.tryParse(e['quantity']?.toString() ?? '1') ?? 1),
        )
        .toList();
  }

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-${d}T00:00:00';
  }

  String _readableError(Object e) {
    if (e is AppException) return e.message;
    final s = e.toString();
    return s.length > 200 ? '${s.substring(0, 200)}...' : s;
  }

  @override
  Future<void> close() {
    _cancelHoldTimer();
    final token = state.holdToken;
    if (token != null && token.isNotEmpty) {
      // fire-and-forget
      _repository.cancelHoldSlot(token);
    }
    return super.close();
  }
}
