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
    // Đổi salon → slot cũ không còn hợp lệ, huỷ hold token (nếu có).
    if (state.holdToken != null) {
      _cancelCurrentHold(state.holdToken!);
    }
    emit(
      state.copyWith(
        selectedBranch: branch,
        clearSeat: true,
        clearStylist: true,
        clearTime: true,
        clearHoldToken: true,
        isHolding: false,
        holdRemainingSeconds: 0,
        noArtistSelected: false,
        artists: [],
        timeSlots: [],
        artistsStatus: NailBookingLoadStatus.initial,
        timeSlotsStatus: NailBookingLoadStatus.initial,
      ),
    );
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
    emit(state.copyWith(selectedExtraServices: services));
  }

  /// Helper build booking items payload cho API suggested-artists & salon-available-slots
  List<Map<String, dynamic>> buildBookingItemsPayload({
    int nailVariantId = 0,
    int? shapeMethodConfigId,
  }) {
    final List<Map<String, dynamic>> bookingItems = [];
    final extraCounts = <String, int>{};

    final baseServiceId = state.selectedBaseServiceId;
    if (baseServiceId != null && baseServiceId.isNotEmpty) {
      extraCounts[baseServiceId] = (extraCounts[baseServiceId] ?? 0) + 1;
    }
    for (final id in state.selectedExtraServices.whereType<String>()) {
      extraCounts[id] = (extraCounts[id] ?? 0) + 1;
    }

    if (state.selectedWarrantyItems.isNotEmpty) {
      bookingItems.addAll(state.selectedWarrantyItems);
      for (final entry in extraCounts.entries) {
        bookingItems.add({'serviceId': entry.key, 'quantity': entry.value});
      }
    } else {
      if (nailVariantId > 0) {
        bookingItems.add({
          'nailVariantId': nailVariantId,
          'shapeMethodConfigId': ?shapeMethodConfigId,
          'quantity': 1,
        });
      }
      for (final entry in extraCounts.entries) {
        bookingItems.add({'serviceId': entry.key, 'quantity': entry.value});
      }
    }
    return bookingItems;
  }

  /// Gọi API POST /Bookings/suggested-artists để gợi ý danh sách thợ đủ skill
  Future<void> fetchSuggestedArtists({
    int nailVariantId = 0,
    int? shapeMethodConfigId,
  }) async {
    final branch = state.selectedBranch;
    final date = state.selectedDate;
    if (branch == null || date == null) return;

    final salonId = branch['salonId']?.toString() ?? '';
    if (salonId.isEmpty) return;

    emit(state.copyWith(artistsStatus: NailBookingLoadStatus.loading));

    try {
      final bookingItems = buildBookingItemsPayload(
        nailVariantId: nailVariantId,
        shapeMethodConfigId: shapeMethodConfigId,
      );
      final artists = await _repository.getSuggestedArtists(
        salonId: salonId,
        bookingDate: _formatDate(date),
        bookingItems: bookingItems,
      );
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
          errorMessage: 'Lỗi gợi ý thợ nail: $e',
        ),
      );
    }
  }

  /// Gọi khi user chọn ngày — reset thợ/giờ rồi fetch thợ gợi ý hoặc slot salon.
  Future<void> selectDate({
    required DateTime date,
    int nailVariantId = 0,
    int? shapeMethodConfigId,
    bool useSuggestedArtists = true,
  }) async {
    if (state.holdToken != null) {
      _cancelCurrentHold(state.holdToken!);
    }
    emit(
      state.copyWith(
        selectedDate: date,
        clearTime: true,
        clearHoldToken: true,
        isHolding: false,
        holdRemainingSeconds: 0,
        timeSlots: [],
        timeSlotsStatus: NailBookingLoadStatus.loading,
      ),
    );

    if (state.noArtistSelected) {
      await loadSalonAvailableSlots(
        nailVariantId: nailVariantId,
        shapeMethodConfigId: shapeMethodConfigId,
      );
    } else {
      await fetchSuggestedArtists(
        nailVariantId: nailVariantId,
        shapeMethodConfigId: shapeMethodConfigId,
      );
      if (state.selectedStylist != null) {
        await _fetchTimeSlots(
          nailVariantId: nailVariantId,
          shapeMethodConfigId: shapeMethodConfigId,
        );
      }
    }
  }

  /// Gọi khi user chọn thợ cụ thể.
  Future<void> selectStylist(
    Map<String, dynamic> artist, {
    int nailVariantId = 0,
    int? shapeMethodConfigId,
  }) async {
    if (state.holdToken != null) {
      _cancelCurrentHold(state.holdToken!);
    }
    emit(
      state.copyWith(
        selectedStylist: artist,
        noArtistSelected: false,
        clearTime: true,
        clearHoldToken: true,
        isHolding: false,
        holdRemainingSeconds: 0,
        timeSlots: [],
        timeSlotsStatus: NailBookingLoadStatus.loading,
      ),
    );
    await _fetchTimeSlots(
      nailVariantId: nailVariantId,
      shapeMethodConfigId: shapeMethodConfigId,
    );
  }

  /// Gọi khi user chuyển sang tab "Để Nailify sắp xếp".
  Future<void> setNoArtistMode({
    int nailVariantId = 0,
    int? shapeMethodConfigId,
  }) async {
    if (state.holdToken != null) {
      _cancelCurrentHold(state.holdToken!);
    }
    emit(
      state.copyWith(
        noArtistSelected: true,
        clearStylist: true,
        clearTime: true,
        clearHoldToken: true,
        isHolding: false,
        holdRemainingSeconds: 0,
        timeSlots: [],
        timeSlotsStatus: NailBookingLoadStatus.loading,
      ),
    );
    await loadSalonAvailableSlots(
      nailVariantId: nailVariantId,
      shapeMethodConfigId: shapeMethodConfigId,
    );
  }

  /// Gọi khi user chuyển sang tab "Tự chọn thợ".
  Future<void> setSelectArtistMode({
    int nailVariantId = 0,
    int? shapeMethodConfigId,
  }) async {
    if (state.holdToken != null) {
      _cancelCurrentHold(state.holdToken!);
    }
    emit(
      state.copyWith(
        noArtistSelected: false,
        clearStylist: true,
        clearTime: true,
        clearHoldToken: true,
        isHolding: false,
        holdRemainingSeconds: 0,
        timeSlots: [],
        timeSlotsStatus: NailBookingLoadStatus.initial,
      ),
    );
    await fetchSuggestedArtists(
      nailVariantId: nailVariantId,
      shapeMethodConfigId: shapeMethodConfigId,
    );
  }

  Future<void> _fetchTimeSlots({
    int nailVariantId = 0,
    int? shapeMethodConfigId,
  }) async {
    final stylist = state.selectedStylist;
    final date = state.selectedDate;
    if (stylist == null || date == null) return;

    try {
      final bookingItems = buildBookingItemsPayload(
        nailVariantId: nailVariantId,
        shapeMethodConfigId: shapeMethodConfigId,
      );
      final slots = await _repository.getArtistAvailableSlots(
        artistId: stylist['nailArtistId'],
        bookingDate: _formatDate(date),
        bookingItems: bookingItems,
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

  Future<void> loadSalonAvailableSlots({
    int nailVariantId = 0,
    int? shapeMethodConfigId,
  }) async {
    final branch = state.selectedBranch;
    final date = state.selectedDate;
    if (branch == null || date == null) return;

    emit(state.copyWith(timeSlotsStatus: NailBookingLoadStatus.loading));

    try {
      final salonId = branch['salonId']?.toString() ?? '';
      final bookingItems = buildBookingItemsPayload(
        nailVariantId: nailVariantId,
        shapeMethodConfigId: shapeMethodConfigId,
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

  Future<void> _loadSalonSlots() async {
    await loadSalonAvailableSlots();
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
  ///
  /// Lưu ý: Vẫn tạo hold token cho cả flow "Không chọn thợ" — backend cần
  /// token này để tránh 2 user cùng đặt 1 slot salon (race condition).
  Future<bool> holdSelectedSlot({int? nailVariantId}) async {
    final time = state.selectedTime;
    if (time == null) return false;

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
  ///
  /// Hỗ trợ cả 2 luồng:
  /// - Có chọn thợ cụ thể → truyền `nailArtistId`
  /// - "Không chọn thợ" → truyền `nailArtistId` rỗng, backend sẽ tự assign sau
  Future<void> _holdSlot(String time, {int? nailVariantId}) async {
    final branch = state.selectedBranch;
    final date = state.selectedDate;
    if (branch == null || date == null) return;

    final salonId = branch['salonId']?.toString() ?? '';
    // Khi `noArtistSelected = true`, vẫn truyền nailArtistId rỗng để
    // backend có thể giữ chỗ ở cấp salon (tránh race condition giữa 2 users).
    final artistId = state.noArtistSelected
        ? ''
        : (state.selectedStylist?['nailArtistId']?.toString() ?? '');

    if (salonId.isEmpty) return;

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
      // Phân biệt các loại lỗi để hiển thị message phù hợp:
      // 1. Lỗi do người dùng chọn giờ đã kín / slot đã có người giữ
      //    → hiển thị "vui lòng chọn giờ khác", reload slots
      // 2. Lỗi hệ thống (network, timeout, 500...)
      //    → hiển thị "hệ thống đang gặp sự cố"
      //
      // Backend .NET hiện tại trả 400 Bad Request cho cả 2 trường hợp:
      //  - Body `{ isSucceeded: false, message: "Thợ đã đầy lịch..." }` — lỗi
      //    nghiệp vụ (user chọn giờ kín, KHÔNG phải lỗi hệ thống).
      //  - Body khác (validation fail...) — lỗi hệ thống.
      // Helper `classifyHoldError` ở `core/error/exceptions.dart` xử lý
      // phân loại (dùng chung cho nail_booking + warranty_booking).
      final errorKind = classifyHoldError(e);
      switch (errorKind) {
        case HoldErrorKind.slotTakenByOther:
          // Slot vừa bị người khác giữ trước khi mình tới lượt.
          // Xoá giờ đang chọn + reload slots để UI cập nhật trạng thái mới nhất.
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
          if (state.noArtistSelected) {
            _loadSalonSlots();
          } else {
            _fetchTimeSlots();
          }
          break;
        case HoldErrorKind.artistFullyBooked:
          // Backend báo thợ đã kín lịch trong khoảng thời gian user chọn.
          // Đây KHÔNG phải lỗi hệ thống — chỉ là user chọn giờ không còn khả dụng.
          // Hiển thị message server trả về (đã được Việt hoá) để user hiểu và chọn giờ khác.
          // Vẫn reload slots vì giờ khác có thể đã bị người khác vừa chọn.
          emit(
            state.copyWith(
              clearHoldToken: true,
              isHolding: false,
              holdRemainingSeconds: 0,
              clearTime: true,
              errorMessage: _readableError(e),
            ),
          );
          if (state.noArtistSelected) {
            _loadSalonSlots();
          } else {
            _fetchTimeSlots();
          }
          break;
        case HoldErrorKind.systemError:
          // Lỗi thực sự (network, 500, timeout...). Giữ nguyên UI, chỉ thông báo.
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
          break;
      }
    }
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

  /// Huỷ giữ chỗ hiện tại (nếu có) — fire-and-forget, không throw.
  /// Gọi khi user back step 3 → 2 hoặc đóng page mà chưa đặt booking xong.
  void cancelCurrentHold() {
    final token = state.holdToken;
    if (token == null || token.isEmpty) return;
    _cancelCurrentHold(token);
    if (!isClosed) {
      emit(
        state.copyWith(
          clearHoldToken: true,
          isHolding: false,
          holdRemainingSeconds: 0,
        ),
      );
    }
  }

  /// Bắt đầu giữ chỗ (cho service_booking_page gọi thẳng vào cubit).
  /// Trả về true nếu thành công, false nếu thất bại.
  Future<bool> startHold() async {
    return holdSelectedSlot();
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
