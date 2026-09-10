import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/exceptions.dart';
import '../../data/models/booking_mock_data.dart';
import '../../data/models/promotion_model.dart';
import '../../data/models/wallet_voucher_model.dart';
import '../../data/nail_booking_repository_impl.dart';
import '../../domain/repositories/nail_booking_repository.dart';

part 'nail_booking_state.dart';

class NailBookingCubit extends Cubit<NailBookingState> {
  final NailBookingRepository _repository;
  Timer? _holdTimer;

  NailBookingCubit({NailBookingRepository? repository})
    : _repository = repository ?? NailBookingRepositoryImpl(),
      super(const NailBookingState());

  // ══════════════════════════════════════════════════════════════
  // LOAD INITIAL DATA
  // ══════════════════════════════════════════════════════════════

  Future<void> loadSalons() async {
    emit(state.copyWith(salonsStatus: NailBookingLoadStatus.loading));
    try {
      final salons = await _repository.getSalons();
      emit(
        state.copyWith(
          salons: salons,
          salonsStatus: NailBookingLoadStatus.loaded,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          salonsStatus: NailBookingLoadStatus.error,
          errorMessage: 'Lỗi tải danh sách Salon: $e',
        ),
      );
    }
  }

  Future<void> loadServices() async {
    try {
      final services = await _repository.getServices();
      emit(state.copyWith(services: services));
    } catch (_) {
      // Fallback về mock data
      final mock = BookingMockData.extraServices
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      emit(state.copyWith(services: mock));
    }
  }

  // ══════════════════════════════════════════════════════════════
  // USER SELECTIONS
  // ══════════════════════════════════════════════════════════════

  Future<void> selectBranch(Map<String, dynamic> branch) async {
    emit(
      state.copyWith(
        selectedBranch: branch,
        clearSeat: true,
        clearStylist: true,
        clearTime: true,
        noArtistSelected: false,
        artists: [],
        timeSlots: [],
        artistsStatus: NailBookingLoadStatus.loading,
        timeSlotsStatus: NailBookingLoadStatus.initial,
      ),
    );
    final salonId = branch['salonId']?.toString() ?? '';
    if (salonId.isNotEmpty) {
      try {
        final artists = await _repository.getArtistsBySalon(salonId);
        emit(
          state.copyWith(
            artists: artists,
            artistsStatus: NailBookingLoadStatus.loaded,
          ),
        );
      } catch (e) {
        emit(
          state.copyWith(
            artistsStatus: NailBookingLoadStatus.error,
            errorMessage: 'Lỗi tải danh sách thợ: $e',
          ),
        );
      }
    }
  }

  void initializeWarranty({
    required Map<String, dynamic> salon,
    required List<Map<String, dynamic>> warrantyBookingItems,
  }) {
    emit(
      state.copyWith(
        selectedBranch: salon,
        selectedExtraServices: const [],
        selectedWarrantyItems: warrantyBookingItems,
      ),
    );
  }

  void updateSelectedWarrantyItems(List<Map<String, dynamic>> items) {
    emit(state.copyWith(selectedWarrantyItems: items));
  }

  void selectSeat(String seatId) {
    emit(state.copyWith(selectedSeatId: seatId));
  }

  void updateExtraServices(List<String?> services) {
    // Fix bug: trước đây `updateExtraServices` xóa luôn `selectedStylist` +
    // `artists` + `timeSlots`. Điều này khiến khi user đính kèm dịch vụ
    // (ngâm chân thảo mộc, cắt da tay...) ở step 2 rồi sang step 3 chọn ngày,
    // `selectDate()` thấy `selectedStylist == null` → nhảy vào `_loadSalonSlots()`
    // → gọi SAI API `POST /api/Bookings/salon-available-slots` thay vì
    // `GET /api/Bookings/artist-available-slots?NailArtistId=...`.
    //
    // Sau fix: KHÔNG xóa thợ. Chỉ clear time đã chọn + reload slots
    // (giữ nguyên `selectedStylist` + `artists` để API gọi đúng endpoint).
    emit(
      state.copyWith(
        selectedExtraServices: services,
        clearTime: true,
        timeSlots: [],
      ),
    );
  }

  /// Gọi khi user chọn ngày — reset thợ/giờ rồi fetch thợ.
  Future<void> selectDate({
    required DateTime date,
    required int nailVariantId,
    int? shapeMethodConfigId,
    bool useSuggestedArtists = true,
  }) async {
    emit(
      state.copyWith(
        selectedDate: date,
        clearTime: true,
        timeSlots: [],
        timeSlotsStatus: NailBookingLoadStatus.loading,
      ),
    );

    if (state.noArtistSelected || state.selectedStylist == null) {
      await _loadSalonSlots();
    } else {
      await _fetchTimeSlots();
    }
  }

  /// Gọi khi user chọn thợ cụ thể.
  Future<void> selectStylist(Map<String, dynamic> artist) async {
    emit(
      state.copyWith(
        selectedStylist: artist,
        noArtistSelected: false,
        clearTime: true,
        timeSlots: [],
        timeSlotsStatus: NailBookingLoadStatus.loading,
      ),
    );
    await _fetchTimeSlots();
  }

  /// Gọi khi user chuyển sang tab "Không chọn thợ".
  Future<void> setNoArtistMode() async {
    emit(
      state.copyWith(
        noArtistSelected: true,
        clearStylist: true,
        clearTime: true,
        timeSlots: [],
        timeSlotsStatus: NailBookingLoadStatus.loading,
      ),
    );
    await _loadSalonSlots();
  }

  /// Gọi khi user quay lại tab "Chọn thợ".
  void setSelectArtistMode() {
    emit(
      state.copyWith(
        noArtistSelected: false,
        clearStylist: true,
        clearTime: true,
        timeSlots: [],
        timeSlotsStatus: NailBookingLoadStatus.initial,
      ),
    );
  }

  Future<void> _fetchTimeSlots() async {
    final stylist = state.selectedStylist;
    final date = state.selectedDate;
    if (stylist == null || date == null) return;

    try {
      final slots = await _repository.getArtistAvailableSlots(
        artistId: stylist['nailArtistId'],
        bookingDate: _formatDate(date),
      );
      final filteredSlots = _repository.filterSlotsByOperatingHours(
        slots: slots,
        salon: state.selectedBranch,
        date: date,
      );
      emit(
        state.copyWith(
          timeSlots: filteredSlots,
          timeSlotsStatus: NailBookingLoadStatus.loaded,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          timeSlotsStatus: NailBookingLoadStatus.error,
          errorMessage: 'Lỗi tải khung giờ: $e',
        ),
      );
    }
  }

  Future<void> _loadSalonSlots() async {
    final branch = state.selectedBranch;
    final date = state.selectedDate;
    if (branch == null || date == null) return;

    emit(state.copyWith(timeSlotsStatus: NailBookingLoadStatus.loading));

    try {
      final salonId = branch['salonId']?.toString() ?? '';

      // Build booking items
      final List<Map<String, dynamic>> bookingItems = [];

      // Group extra services by ID and count duplicates for correct quantity
      final extraCounts = <String, int>{};
      for (final id in state.selectedExtraServices.whereType<String>()) {
        extraCounts[id] = (extraCounts[id] ?? 0) + 1;
      }

      bookingItems.addAll(
        extraCounts.entries
            .map((e) => {'serviceId': e.key, 'quantity': e.value})
            .toList(),
      );

      final slots = await _repository.getSalonAvailableSlots(
        salonId: salonId,
        bookingDate: _formatDate(date),
        bookingItems: bookingItems,
      );

      final filteredSlots = _repository.filterSlotsByOperatingHours(
        slots: slots,
        salon: branch,
        date: date,
      );

      emit(
        state.copyWith(
          timeSlots: filteredSlots,
          timeSlotsStatus: NailBookingLoadStatus.loaded,
          clearTime: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          timeSlotsStatus: NailBookingLoadStatus.error,
          errorMessage: 'Lỗi tải khung giờ salon: $e',
        ),
      );
    }
  }

  /// Reload danh sách khung giờ từ bên ngoài (VD: từ widget khi detect isHeld).
  Future<void> refreshTimeSlots() async {
    emit(state.copyWith(timeSlotsStatus: NailBookingLoadStatus.loading));
    if (state.noArtistSelected) {
      await _loadSalonSlots();
    } else {
      await _fetchTimeSlots();
    }
  }

  void selectTime(String time) {
    // 1. Nếu user chọn lại đúng giờ đã chọn → bỏ chọn.
    if (state.selectedTime == time) {
      if (state.holdToken != null) {
        _cancelCurrentHold(state.holdToken!);
      }
      emit(
        state.copyWith(
          clearTime: true,
          clearHoldToken: true,
          isHolding: false,
          holdRemainingSeconds: 0,
        ),
      );
      return;
    }

    // 2. Người dùng đổi giờ → huỷ giữ chỗ cũ (nếu có)
    if (state.holdToken != null) {
      _cancelCurrentHold(state.holdToken!);
    }
    emit(
      state.copyWith(
        selectedTime: time,
        clearHoldToken: true,
        isHolding: false,
        holdRemainingSeconds: 0,
      ),
    );
  }

  /// Giữ chỗ trước khi bước sang trang Xác nhận.
  /// Trả về true nếu giữ chỗ thành công, false nếu thất bại (đã emit errorMessage).
  Future<bool> holdSelectedSlot({int? nailVariantId}) async {
    final time = state.selectedTime;
    if (time == null) return false;

    // Nếu chọn luồng "Không chọn thợ", bỏ qua việc lấy holdToken
    if (state.noArtistSelected) return true;

    // Fix bug: set `isSubmitting = true` trước khi gọi API hold-slot để button
    // "Tiếp tục" trên `service_booking_page` disable + spinner ngay, tránh
    // user bấm nhầm nhiều lần (gọi API hold-slot trùng lặp).
    emit(state.copyWith(isSubmitting: true));
    try {
      await _holdSlot(time, nailVariantId: nailVariantId);
      return state.holdToken != null;
    } finally {
      // Chỉ reset isSubmitting nếu vẫn còn mounted (tránh emit sau dispose).
      if (!isClosed) {
        emit(state.copyWith(isSubmitting: false));
      }
    }
  }

  /// Gọi API giữ chỗ và khởi động bộ đếm thời gian.
  Future<void> _holdSlot(String time, {int? nailVariantId}) async {
    final branch = state.selectedBranch;
    final date = state.selectedDate;
    if (branch == null || date == null) return;

    final salonId = branch['salonId']?.toString() ?? '';
    final artistId = state.noArtistSelected
        ? ''
        : (state.selectedStylist?['nailArtistId']?.toString() ?? '');

    if (salonId.isEmpty || artistId.isEmpty) return;

    final bookingDate = _formatDate(date);
    final formattedTime = time.length == 5 ? '$time:00' : time;

    final List<Map<String, dynamic>> bookingItems = [];
    final isWarranty = state.selectedWarrantyItems.isNotEmpty;

    // Group extra services by ID and count duplicates for correct quantity
    final extraCounts = <String, int>{};

    // 1. Service gốc (base service) — dùng cho luồng service_booking_page.
    final baseServiceId = state.selectedBaseServiceId;
    if (baseServiceId != null && baseServiceId.isNotEmpty) {
      extraCounts[baseServiceId] = (extraCounts[baseServiceId] ?? 0) + 1;
    }

    // 2. Các dịch vụ thêm user chọn ở BookingServiceSelection.
    for (final id in state.selectedExtraServices.whereType<String>()) {
      extraCounts[id] = (extraCounts[id] ?? 0) + 1;
    }

    // Nếu rỗng → không thể giữ chỗ, báo lỗi ngay để khỏi spam backend.
    if (extraCounts.isEmpty && nailVariantId == null) {
      emit(
        state.copyWith(
          errorMessage:
              'Vui lòng chọn ít nhất một dịch vụ hoặc mẫu nail trước khi giữ chỗ.',
        ),
      );
      return;
    }

    if (isWarranty) {
      bookingItems.addAll(state.selectedWarrantyItems);
      for (final entry in extraCounts.entries) {
        bookingItems.add({
          'nailVariantId': null,
          'serviceId': entry.key,
          'customerNailId': null,
          'quantity': entry.value,
        });
      }
    } else {
      bookingItems.addAll(
        extraCounts.entries
            .map((e) => {'serviceId': e.key, 'quantity': e.value})
            .toList(),
      );
      if (nailVariantId != null && nailVariantId > 0) {
        bookingItems.insert(0, {'nailVariantId': nailVariantId, 'quantity': 1});
      }
    }

    try {
      final data = await _repository.holdSlot(
        salonId: salonId,
        nailArtistId: artistId,
        bookingDate: bookingDate,
        startTime: formattedTime,
        bookingItems: bookingItems,
      );

      if (isClosed) return;

      final token = data['holdToken']?.toString();
      final expiresAtStr = data['expiresAt']?.toString();

      // Fix bug "app đơ khi bấm Tiếp tục":
      // Nếu backend trả token rỗng hoặc null → không có hold. Trước fix:
      // không emit gì cả → isHolding vẫn false → _holdSelectedSlot return false
      // nhưng không thông báo → user thấy app đơ. Sau fix: báo lỗi rõ ràng.
      if (token == null || token.isEmpty) {
        emit(
          state.copyWith(
            clearHoldToken: true,
            isHolding: false,
            holdRemainingSeconds: 0,
            errorMessage:
                'Không thể giữ khung giờ này. Vui lòng chọn giờ khác.',
          ),
        );
        return;
      }

      // Bỏ qua việc tính difference từ expiresAt vì đồng hồ device có thể lệch với server.
      // Ưu tiên dùng remainingSeconds từ server trả về, nếu không có mặc định 300s (5 phút).
      DateTime? expiresAt;
      if (expiresAtStr != null) {
        try {
          expiresAt = DateTime.parse(expiresAtStr).toUtc();
        } catch (_) {}
      }

      final remaining = (data['remainingSeconds'] as num?)?.toInt() ?? 300;

      emit(
        state.copyWith(
          holdToken: token,
          holdExpiresAt: expiresAt,
          holdRemainingSeconds: remaining,
          isHolding: true,
        ),
      );

      _startHoldTimer(token, expiresAt);
    } catch (e) {
      // Phân biệt lỗi race condition (slot đã bị người khác giữ) với lỗi khác
      // (validation, auth, network). Chỉ khi là conflict (HTTP 409) mới xoá
      // giờ đang chọn và reload slots. Các lỗi khác chỉ thông báo để user biết.
      final isConflict = _isConflictError(e);
      if (isConflict) {
        emit(
          state.copyWith(
            clearHoldToken: true,
            isHolding: false,
            holdRemainingSeconds: 0,
            clearTime: true,
            errorMessage:
                'Khung giờ này vừa mới có người chọn. Vui lòng chọn giờ khác.',
          ),
        );
        // Tải lại danh sách giờ để cập nhật trạng thái isHeld mới nhất
        if (state.noArtistSelected) {
          _loadSalonSlots();
        } else {
          _fetchTimeSlots();
        }
      } else {
        // Các lỗi khác (validation, auth, network...) — chỉ thông báo,
        // không xoá thời gian user đã chọn để tránh UX khó chịu.
        // Fix bug "app đơ": luôn set isHolding = false để _holdSelectedSlot
        // nhận ra hold fail và return false + BlocConsumer hiển thị lỗi.
        emit(
          state.copyWith(
            clearHoldToken: true,
            isHolding: false,
            holdRemainingSeconds: 0,
            errorMessage: _readableError(e),
          ),
        );
      }
    }
  }

  /// Kiểm tra exception có phải race condition (slot bị giữ bởi người khác)
  /// hay không. Server hiện tại trả về các loại lỗi khác nhau tuỳ business
  /// logic; ta ưu tiên HTTP 409 + các mã thường gặp.
  bool _isConflictError(Object error) {
    if (error is AppException) {
      final code = error.code;
      if (code == 'HTTP_409' || code == 'HTTP_410' || code == 'HTTP_423') {
        return true;
      }
      final msg = error.message.toLowerCase();
      if (msg.contains('đã được giữ') ||
          msg.contains('slot') && msg.contains('conflict') ||
          msg.contains('already held') ||
          msg.contains('race condition')) {
        return true;
      }
    }
    return false;
  }

  /// Trả về message thân thiện cho mọi lỗi không phải conflict.
  String _readableError(Object error) {
    if (error is AppException) return error.message;
    return 'Lỗi giữ chỗ: $error';
  }

  /// Bộ đếm ngược từ máy client, không phụ thuộc vào đồng hồ hệ thống.
  void _startHoldTimer(String token, DateTime? expiresAt) {
    _holdTimer?.cancel();
    // Bỏ qua sự sai lệch đồng hồ thiết bị và server, luôn đếm ngược từ remaining ban đầu
    _holdTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (isClosed) {
        _holdTimer?.cancel();
        return;
      }

      final remaining = (state.holdRemainingSeconds - 1).clamp(0, 600);

      if (state.holdToken != token) {
        // Token đã thay đổi (user đổi giờ), huỷ timer
        _holdTimer?.cancel();
        return;
      }

      if (remaining <= 0) {
        _holdTimer?.cancel();
        emit(
          state.copyWith(
            clearHoldToken: true,
            isHolding: false,
            clearTime: true,
            clearStylist: true,
            noArtistSelected: false,
            errorMessage:
                'Thời gian giữ chỗ đã hết! Vui lòng chọn lại thợ và khung giờ.',
          ),
        );
      } else {
        emit(state.copyWith(holdRemainingSeconds: remaining));
      }
    });
  }

  /// Huỷ token cũ (khi đổi giờ, đổi thợ, hoặc đóng trang).
  void _cancelCurrentHold(String token) {
    _holdTimer?.cancel();
    _holdTimer = null;
    _repository.cancelHoldSlot(token); // fire-and-forget
  }

  void selectPromotions(List<dynamic> promos) {
    emit(state.copyWith(selectedPromotions: promos));
  }

  /// Đặt dịch vụ gốc cho luồng `service_booking_page` — dịch vụ user đã chọn
  /// từ trang trước khi vào booking flow.
  ///
  /// Service này sẽ tự động được thêm vào `bookingItems` của API hold-slot
  /// và create-booking. Khác với `selectedExtraServices` (user chọn thêm).
  void setBaseService(String? serviceId) {
    if (serviceId == null || serviceId.isEmpty) {
      emit(state.copyWith(clearBaseService: true));
    } else {
      emit(state.copyWith(selectedBaseServiceId: serviceId));
    }
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  // ══════════════════════════════════════════════════════════════
  // PRICE CALCULATION HELPERS
  // ══════════════════════════════════════════════════════════════

  List<Map<String, dynamic>> get availableServices {
    final source = state.services.isEmpty
        ? BookingMockData.extraServices
              .map((e) => Map<String, dynamic>.from(e))
              .toList()
        : state.services;
    return source;
  }

  String serviceIdOf(Map<String, dynamic> svc) =>
      svc['serviceId']?.toString() ?? svc['id']?.toString() ?? '';

  String serviceNameOf(Map<String, dynamic> svc) =>
      svc['serviceName']?.toString() ?? svc['name']?.toString() ?? '';

  int servicePriceOf(Map<String, dynamic> svc) {
    final price = svc['price'] ?? svc['basePrice'];
    if (price is num) return price.round();
    return int.tryParse(price?.toString() ?? '') ?? 0;
  }

  String serviceNameById(String? id) {
    if (id == null) return '';
    final matches = availableServices.where((s) => serviceIdOf(s) == id);
    return matches.isEmpty ? id : serviceNameOf(matches.first);
  }

  int servicePriceById(String? id) {
    if (id == null) return 0;
    final matches = availableServices.where((s) => serviceIdOf(s) == id);
    if (matches.isEmpty) return 0;
    return servicePriceOf(matches.first);
  }

  int extraServicesTotal(List<String?> services) {
    // Count duplicates so total price reflects quantity
    final counts = <String, int>{};
    for (final id in services.whereType<String>()) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
    return counts.entries.fold<int>(
      0,
      (sum, e) => sum + servicePriceById(e.key) * e.value,
    );
  }

  int discountAmount({
    required int subtotal,
    required List<PromotionModel> promotions,
  }) {
    if (promotions.isEmpty) return 0;
    double total = 0;
    for (final p in promotions) {
      if (p.discountType == 'Percentage') {
        total += subtotal * (p.discountValue / 100);
      } else {
        total += p.discountValue;
      }
    }
    return total.toInt();
  }

  /// Tính số tiền giảm từ danh sách wallet voucher (dùng cho các luồng
  /// booking mới dùng API /api/Promotions/my-wallet-vouchers).
  int discountAmountFromVouchers({
    required int subtotal,
    required List<WalletVoucherModel> vouchers,
  }) {
    if (vouchers.isEmpty) return 0;
    double total = 0;
    for (final v in vouchers) {
      final type = v.discountType.toLowerCase();
      if (type == 'percentage') {
        total += subtotal * (v.discountValue / 100);
      } else {
        total += v.discountValue;
      }
    }
    return total.toInt();
  }

  // ══════════════════════════════════════════════════════════════
  // SUBMIT BOOKING
  // ══════════════════════════════════════════════════════════════

  /// Tạo booking từ luồng NailVariant — trả về response map hoặc throw.
  Future<Map<String, dynamic>> createNailVariantBooking({
    required int nailVariantId,
    required List<String> serviceIds,
    List<int>? selectedPromotionIds,
    int? shapeMethodConfigId,
    String? warrantyForBookingId,
    List<Map<String, dynamic>>? warrantyBookingItems,
  }) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      final s = state;
      final formattedTime = s.selectedTime!.length == 5
          ? '${s.selectedTime}:00'
          : s.selectedTime!;

      List<Map<String, dynamic>>? finalBookingItems;
      if (warrantyForBookingId != null && warrantyBookingItems != null) {
        finalBookingItems = List<Map<String, dynamic>>.from(
          warrantyBookingItems,
        );
        for (final sId in serviceIds) {
          finalBookingItems.add({
            'nailVariantId': null,
            'serviceId': sId,
            'customerNailId': null,
            'quantity': 1,
          });
        }
      }

      final result = await _repository.createBooking(
        salonId: s.selectedBranch!['salonId'],
        bookingDate: _formatDate(s.selectedDate!),
        startTime: formattedTime,
        artistId: s.noArtistSelected
            ? null
            : s.selectedStylist?['nailArtistId'],
        nailVariantId: nailVariantId,
        serviceIds: serviceIds,
        selectedPromotionIds: selectedPromotionIds,
        holdToken: s.holdToken,
        shapeMethodConfigId: shapeMethodConfigId,
        warrantyForBookingId: warrantyForBookingId,
        warrantyBookingItems: warrantyForBookingId != null
            ? (finalBookingItems ?? warrantyBookingItems)
            : null,
      );
      _holdTimer?.cancel();
      emit(
        state.copyWith(
          isSubmitting: false,
          clearHoldToken: true,
          isHolding: false,
        ),
      );
      return result;
    } catch (e) {
      emit(
        state.copyWith(isSubmitting: false, errorMessage: 'Lỗi đặt lịch: $e'),
      );
      rethrow;
    }
  }

  /// Tạo booking từ luồng Service độc lập — trả về response map hoặc throw.
  Future<Map<String, dynamic>> createServiceBookingFromState({
    required Map<String, dynamic> payload,
    List<int>? selectedPromotionIds,
  }) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      final result = await _repository.createServiceBooking(
        payload,
        selectedPromotionIds: selectedPromotionIds,
        holdToken: state.holdToken,
      );
      _holdTimer?.cancel();
      emit(
        state.copyWith(
          isSubmitting: false,
          clearHoldToken: true,
          isHolding: false,
        ),
      );
      return result;
    } catch (e) {
      emit(
        state.copyWith(isSubmitting: false, errorMessage: 'Lỗi đặt lịch: $e'),
      );
      rethrow;
    }
  }

  // ══════════════════════════════════════════════════════════════
  // UTILITIES
  // ══════════════════════════════════════════════════════════════

  String _formatDate(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-${d}T00:00:00';
  }

  String formatBookingDate(DateTime date) => _formatDate(date);

  /// Huỷ giữ chỗ khi user thoát khỏi quá trình đặt lịch.
  @override
  Future<void> close() {
    if (state.holdToken != null) {
      _repository.cancelHoldSlot(state.holdToken!); // fire-and-forget
    }
    _holdTimer?.cancel();
    return super.close();
  }
}
