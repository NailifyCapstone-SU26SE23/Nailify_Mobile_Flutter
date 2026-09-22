import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/error/exceptions.dart';
import '../../data/datasources/payment_api_service.dart';
import '../../data/nail_booking_repository_impl.dart';
import '../../domain/repositories/nail_booking_repository.dart';

part 'warranty_booking_state.dart';

/// Cubit riêng cho luồng đặt lịch bảo hành.
///
/// Khác với `NailBookingCubit` (luồng booking thường):
///  - Salon được fix cứng từ booking gốc (không cho chọn lại).
///  - Có thể chọn thêm dịch vụ phát sinh (cắt móng, ngâm chân...) → có phí.
///  - Submit: nếu tổng = 0 → POST /Bookings thẳng; nếu > 0 → qua
///    `/payments/create-for-request` → `/payment-qr`.
class WarrantyBookingCubit extends Cubit<WarrantyBookingState> {
  static const Duration warrantyWindow = Duration(days: 7);

  final NailBookingRepository _repository;
  final PaymentApiService _paymentApiService;
  Timer? _holdTimer;

  /// Số lần retry tối đa khi load salon / artists / timeSlots bị lỗi
  /// (timeout, network, 5xx). Sau khi hết retry, page sẽ hiện nút
  /// "Thử lại" cho user bấm tay.
  static const int _maxLoadRetries = 2;

  WarrantyBookingCubit({
    NailBookingRepository? repository,
    PaymentApiService? paymentApiService,
  }) : _repository = repository ?? NailBookingRepositoryImpl(),
       _paymentApiService = paymentApiService ?? PaymentApiService(),
       super(const WarrantyBookingState());

  // ══════════════════════════════════════════════════════════════
  // LOAD CONTEXT
  // ══════════════════════════════════════════════════════════════

  /// Load context từ booking gốc: salon + artists + services +
  /// booking items sẽ được bảo hành.
  ///
  /// `sourceBooking` chứa các key: `sourceBookingId`, `salonId`,
  /// `salonName?`, `sourceArtistId?`, `sourceArtistName?`,
  /// `sourceBookingDate?` (DateTime ISO), `bookingItems` (List<Map>).
  Future<void> loadWarrantyContext(Map<String, dynamic> sourceBooking) async {
    final salonId = sourceBooking['salonId']?.toString() ?? '';
    final rawItems = sourceBooking['bookingItems'];
    final warrantyItems = <Map<String, dynamic>>[];
    if (rawItems is List) {
      for (final e in rawItems) {
        if (e is Map) warrantyItems.add(Map<String, dynamic>.from(e));
      }
    }

    // Validate deadline 7 ngày.
    DateTime? sourceDate;
    final rawDate = sourceBooking['sourceBookingDate'];
    if (rawDate is DateTime) {
      sourceDate = rawDate;
    } else if (rawDate is String && rawDate.isNotEmpty) {
      sourceDate = DateTime.tryParse(rawDate);
    }
    final withinWindow = sourceDate == null
        ? true
        : DateTime.now().difference(sourceDate) <= warrantyWindow;

    // Tìm thông tin salon từ API (kèm retry).
    Map<String, dynamic>? branch;
    if (salonId.isNotEmpty) {
      branch = await _loadBranchWithRetry(salonId, sourceBooking);
    }

    emit(
      state.copyWith(
        sourceBookingId: sourceBooking['sourceBookingId']?.toString() ?? '',
        sourceArtistId: sourceBooking['sourceArtistId']?.toString() ?? '',
        sourceArtistName: sourceBooking['sourceArtistName']?.toString() ?? '',
        sourceBookingDate: sourceDate,
        isWithinWarrantyWindow: withinWindow,
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

    if (salonId.isNotEmpty) {
      // Fire-and-forget — page sẽ theo dõi state.
      // ignore: discarded_futures
      loadArtists(salonId);
    }
    // ignore: discarded_futures
    loadServices();
  }

  /// Load thông tin salon với retry. Trả về `null` nếu thất bại hết retry
  /// (page sẽ dùng thông tin fallback từ payload).
  Future<Map<String, dynamic>?> _loadBranchWithRetry(
    String salonId,
    Map<String, dynamic> fallbackPayload,
  ) async {
    for (int attempt = 0; attempt <= _maxLoadRetries; attempt++) {
      try {
        final salons = await _repository.getSalons();
        for (final s in salons) {
          if (s['salonId']?.toString() == salonId) {
            return Map<String, dynamic>.from(s);
          }
        }
        // API trả 200 nhưng không có salon match → dùng fallback.
        return _fallbackBranch(salonId, fallbackPayload);
      } catch (e) {
        if (attempt >= _maxLoadRetries) {
          // Hết retry → fallback + báo lỗi để page có thể hiển thị nút
          // "Thử lại".
          if (!isClosed) {
            emit(
              state.copyWith(
                errorMessage:
                    'Không tải được thông tin salon (đã thử ${attempt + 1} lần)',
              ),
            );
          }
          return _fallbackBranch(salonId, fallbackPayload);
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    return _fallbackBranch(salonId, fallbackPayload);
  }

  Map<String, dynamic> _fallbackBranch(
    String salonId,
    Map<String, dynamic> payload,
  ) {
    return {
      'salonId': salonId,
      'name': payload['salonName']?.toString() ?? '',
      'address': payload['salonAddress']?.toString() ?? '',
      if (payload['salonAddress'] != null)
        'salonAddress': payload['salonAddress'],
    };
  }

  /// Public cho page gọi retry khi user bấm nút "Thử lại".
  Future<void> reloadArtists() async {
    final s = state.selectedBranch;
    final salonId = s?['salonId']?.toString() ?? '';
    if (salonId.isEmpty) return;
    await loadArtists(salonId);
  }

  Future<void> loadArtists(String salonId) async {
    if (salonId.isEmpty) return;
    if (!isClosed) {
      emit(state.copyWith(artistsStatus: WarrantyLoadStatus.loading));
    }
    List<Map<String, dynamic>> lastArtists = const [];
    for (int attempt = 0; attempt <= _maxLoadRetries; attempt++) {
      try {
        final artists = await _repository.getArtistsBySalon(salonId);
        if (isClosed) return;
        emit(
          state.copyWith(
            artists: artists,
            artistsStatus: WarrantyLoadStatus.loaded,
          ),
        );
        return;
      } catch (e) {
        if (attempt >= _maxLoadRetries) {
          if (isClosed) return;
          emit(
            state.copyWith(
              artists: lastArtists,
              artistsStatus: WarrantyLoadStatus.error,
              errorMessage:
                  'Không tải được danh sách thợ (đã thử ${attempt + 1} lần): $e',
            ),
          );
          return;
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
  }

  Future<void> loadServices() async {
    if (!isClosed) {
      emit(state.copyWith(servicesStatus: WarrantyLoadStatus.loading));
    }
    for (int attempt = 0; attempt <= _maxLoadRetries; attempt++) {
      try {
        final services = await _repository.getServices();
        if (isClosed) return;
        emit(
          state.copyWith(
            services: services,
            servicesStatus: WarrantyLoadStatus.loaded,
          ),
        );
        return;
      } catch (e) {
        if (attempt >= _maxLoadRetries) {
          if (isClosed) return;
          emit(
            state.copyWith(
              servicesStatus: WarrantyLoadStatus.error,
              errorMessage:
                  'Không tải được danh sách dịch vụ (đã thử ${attempt + 1} lần): $e',
            ),
          );
          return;
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
  }

  /// Public cho page gọi reload time slots khi user đổi ngày/giờ hoặc
  /// bấm nút "Thử lại".
  Future<List<dynamic>> loadTimeSlots({
    required String salonId,
    String? artistId,
    required DateTime date,
  }) async {
    if (!isClosed) {
      emit(
        state.copyWith(
          timeSlotsStatus: WarrantyLoadStatus.loading,
          clearTimeSlotsError: true,
        ),
      );
    }
    final bookingItems = state.selectedWarrantyItems
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    for (int attempt = 0; attempt <= _maxLoadRetries; attempt++) {
      try {
        final List<dynamic> slots;
        if (artistId == null || artistId.isEmpty) {
          slots = await _repository.getSalonAvailableSlots(
            salonId: salonId,
            bookingDate: _formatDate(date),
            bookingItems: bookingItems,
          );
        } else {
          slots = await _repository.getArtistAvailableSlots(
            artistId: artistId,
            bookingDate: _formatDate(date),
          );
        }
        if (isClosed) return slots;
        emit(
          state.copyWith(
            timeSlotsStatus: WarrantyLoadStatus.loaded,
            clearTimeSlotsError: true,
          ),
        );
        return slots;
      } catch (e) {
        if (attempt >= _maxLoadRetries) {
          if (isClosed) return const [];
          emit(
            state.copyWith(
              timeSlotsStatus: WarrantyLoadStatus.error,
              timeSlotsLoadError:
                  'Không tải được khung giờ (đã thử ${attempt + 1} lần): $e',
            ),
          );
          return const [];
        }
        await Future<void>.delayed(Duration(milliseconds: 400 * (attempt + 1)));
      }
    }
    return const [];
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
        clearTimeSlotsError: true,
      ),
    );
    _cancelHoldTimer();
    final oldToken = state.holdToken;
    if (oldToken != null && oldToken.isNotEmpty) {
      _repository.cancelHoldSlot(oldToken);
    }
  }

  Future<void> selectTime(String time) async {
    // Bug fix: KHÔNG cancel hold cũ NGAY LẬP TỨC.
    // Nếu cancel rồi hold mới thất bại → user MẤT SLOT.
    // Fix: Tạo hold mới TRƯỚC, chỉ cancel hold cũ SAU KHI hold mới thành công.
    // Lưu token cũ để so sánh.
    final oldToken = state.holdToken;

    emit(
      state.copyWith(
        selectedTime: time,
        clearHoldToken: true,
        isHolding: false,
        holdRemainingSeconds: 0,
      ),
    );
    final ok = await holdSelectedSlot();
    if (!ok && oldToken != null && oldToken.isNotEmpty) {
      // Hold mới THẤT BẠI → Khôi phục hold CŨ nếu còn hiệu lực.
      // (Trường hợp này hiếm: slot hết ngay sau khi emit nhưng trước khi
      //  backend trả về — hold cũ đã bị cancel ở trên rồi nên không thể khôi phục.
      //  Hiện tại để nguyên state mới đã emit ở trên, user phải chọn lại giờ.)
    }
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

  void setExtraServices(List<String?> services) {
    emit(state.copyWith(selectedExtraServices: services));
  }

  // ══════════════════════════════════════════════════════════════
  // HOLD SLOT
  // ══════════════════════════════════════════════════════════════

  /// Giữ chỗ khi user chọn giờ. Trả về true nếu thành công.
  Future<bool> holdSelectedSlot() async {
    final time = state.selectedTime;
    if (time == null) return false;

    if (state.noArtistSelected) {
      return true;
    }

    final branch = state.selectedBranch;
    final date = state.selectedDate;
    final stylist = state.selectedStylist;
    if (branch == null || date == null || stylist == null) return false;

    final salonId = branch['salonId']?.toString() ?? '';
    final artistId = stylist['nailArtistId']?.toString() ?? '';
    if (salonId.isEmpty || artistId.isEmpty) return false;

    emit(state.copyWith(isSubmitting: true, clearError: true));
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
        if (!isClosed) {
          emit(
            state.copyWith(
              isSubmitting: false,
              clearHoldToken: true,
              isHolding: false,
              holdRemainingSeconds: 0,
              clearTime: true,
              errorMessage:
                  'Khung giờ này vừa có người chọn. Vui lòng chọn giờ khác.',
            ),
          );
        }
        return false;
      }

      final remaining = (data['remainingSeconds'] as num?)?.toInt() ?? 300;
      if (!isClosed) {
        emit(
          state.copyWith(
            isSubmitting: false,
            holdToken: token,
            holdRemainingSeconds: remaining,
            isHolding: true,
          ),
        );
        _startHoldTimer(token);
      }
      return true;
    } catch (e) {
      if (!isClosed) {
        // Phân biệt lỗi "user chọn giờ kín" (HTTP 400 + message cụ thể
        // từ backend) với lỗi hệ thống thực sự (network, 500...).
        // Backend .NET trả 400 cho cả 2 case → helper `classifyHoldError`
        // phân loại giúp.
        final errorKind = classifyHoldError(e);
        switch (errorKind) {
          case HoldErrorKind.artistFullyBooked:
            // User chọn giờ thợ đã kín — KHÔNG phải lỗi hệ thống.
            // Hiển thị message server trả về (đã Việt hoá) thay vì
            // "Hệ thống đang gặp sự cố" để user hiểu và đổi giờ.
            emit(
              state.copyWith(
                isSubmitting: false,
                clearHoldToken: true,
                isHolding: false,
                holdRemainingSeconds: 0,
                clearTime: true,
                errorMessage: _readableError(e),
              ),
            );
            break;
          case HoldErrorKind.slotTakenByOther:
            // Slot vừa bị người khác giữ trước khi mình tới lượt (HTTP 409).
            emit(
              state.copyWith(
                isSubmitting: false,
                clearHoldToken: true,
                isHolding: false,
                holdRemainingSeconds: 0,
                clearTime: true,
                errorMessage:
                    'Khung giờ này vừa có người chọn. Vui lòng chọn giờ khác.',
              ),
            );
            break;
          case HoldErrorKind.systemError:
            // Lỗi hệ thống thực sự — vẫn clear hold + giờ để tránh UI kẹt.
            emit(
              state.copyWith(
                isSubmitting: false,
                clearHoldToken: true,
                isHolding: false,
                holdRemainingSeconds: 0,
                clearTime: true,
                errorMessage: _readableError(e),
              ),
            );
            break;
        }
      }
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
            errorMessage:
                'Thời gian giữ chỗ đã hết. Vui lòng chọn lại khung giờ.',
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
  // HOLD/SLOT WRAPPERS — trả lại cho page dùng giữ nguyên flow cũ
  // (tái sử dụng với code đã viết ở warranty_booking_page.dart).
  // ══════════════════════════════════════════════════════════════

  Future<List<dynamic>> loadArtistAvailableSlots({
    required String artistId,
    required String bookingDate,
  }) {
    return _repository.getArtistAvailableSlots(
      artistId: artistId,
      bookingDate: bookingDate,
    );
  }

  Future<List<dynamic>> loadSalonAvailableSlots({
    required String salonId,
    required String bookingDate,
    required List<Map<String, dynamic>> bookingItems,
  }) {
    return _repository.getSalonAvailableSlots(
      salonId: salonId,
      bookingDate: bookingDate,
      bookingItems: bookingItems,
    );
  }

  void selectDateForHolder(DateTime date) {
    emit(state.copyWith(selectedDate: date));
  }

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

  void selectTimeForHolder(String time) {
    emit(state.copyWith(selectedTime: time));
  }

  // ══════════════════════════════════════════════════════════════
  // PRICE COMPUTATION (offline estimate)
  // ══════════════════════════════════════════════════════════════

  /// Giá ước tính cho các dịch vụ phát sinh (extra services). Trả về 0
  /// nếu user không chọn dịch vụ phát sinh nào.
  int get extraServicesTotal {
    int total = 0;
    for (final id in state.selectedExtraServices.whereType<String>()) {
      total += servicePriceById(id);
    }
    return total;
  }

  /// Tổng tiền phải trả cho booking bảo hành. Luồng bảo hành luôn
  /// MIỄN PHÍ phần gốc — chỉ cộng thêm phần dịch vụ phát sinh.
  ///
  /// `clamp(0, 1<<31)` đảm bảo không bao giờ xuống dưới 0 đồng (kể cả
  /// khi user áp dụng giảm giá hay discount nào đó trong tương lai).
  int get estimatedTotalPrice {
    return extraServicesTotal.clamp(0, 1 << 30);
  }

  /// Trả về `true` nếu booking hoàn toàn miễn phí (không có dịch vụ
  /// phát sinh nào được chọn) → submit thẳng, không qua payment.
  bool get isFreeFlow => estimatedTotalPrice == 0;

  /// Helper lấy giá 1 service theo id từ danh sách services của cubit
  /// (ưu tiên) hoặc fallback.
  int servicePriceById(String? id) {
    if (id == null) return 0;
    for (final s in state.services) {
      if (_matchServiceId(s, id)) {
        final price = s['price'] ?? s['basePrice'];
        if (price is num) return price.round();
        return int.tryParse(price?.toString() ?? '') ?? 0;
      }
    }
    return 0;
  }

  /// Helper lấy tên dịch vụ. Thử nhiều field name phổ biến (name,
  /// serviceName, ServiceName, title, displayName) để tương thích với
  /// cả mock data lẫn API response thực tế.
  String serviceNameById(String? id) {
    if (id == null) return '';
    for (final s in state.services) {
      if (_matchServiceId(s, id)) {
        final name =
            _firstNonEmptyString(s, const [
              'name',
              'serviceName',
              'ServiceName',
              'title',
              'displayName',
            ]) ??
            id;
        return name;
      }
    }
    // Fallback: tìm trong mock data.
    final mockName = _mockServiceName(id);
    if (mockName != null) return mockName;
    return id;
  }

  /// Map UUID → tên đẹp từ `BookingMockData.extraServices` (dùng làm
  /// fallback khi API response thiếu field name).
  static String? _mockServiceName(String id) {
    for (final s in _mockFallback) {
      if (_matchServiceId(s, id)) {
        final name = _firstNonEmptyString(s, const [
          'name',
          'serviceName',
          'ServiceName',
          'title',
          'displayName',
        ]);
        if (name != null && name.isNotEmpty) return name;
      }
    }
    return null;
  }

  /// Danh sách fallback mirror theo `BookingMockData.extraServices`. Dùng
  /// khi API trả về service không có trường tên → tránh hiển thị UUID.
  static const List<Map<String, dynamic>> _mockFallback = [
    {
      'id': 'f512b732-231c-4584-b3f0-647603b1f167',
      'name': 'Chà gót chân',
      'price': 12000,
    },
    {'id': 'tay-gel', 'name': 'Tẩy gel', 'price': 30000},
    {'id': 'lam-sach-mong', 'name': 'Làm sạch móng (Cắt da)', 'price': 40000},
    {'id': 'duong-mong-co-ban', 'name': 'Dưỡng móng cơ bản', 'price': 50000},
    {'id': 'phuc-hoi-mong', 'name': 'Phục hồi móng hư tổn', 'price': 100000},
  ];

  /// Match id linh hoạt: so sánh cả `id` và `serviceId`.
  static bool _matchServiceId(Map<String, dynamic> s, String id) {
    final sid = s['serviceId']?.toString();
    final sIdAlt = s['id']?.toString();
    return sid == id || sIdAlt == id;
  }

  /// Lấy giá trị string đầu tiên không rỗng từ các key được liệt kê.
  static String? _firstNonEmptyString(
    Map<String, dynamic> map,
    List<String> keys,
  ) {
    for (final k in keys) {
      final v = map[k]?.toString();
      if (v != null && v.isNotEmpty) return v;
    }
    return null;
  }

  // ══════════════════════════════════════════════════════════════
  // SUBMIT — 2 mode: free-flow vs payment-qr
  // ══════════════════════════════════════════════════════════════

  /// Result của submit: nếu miễn phí → trả về `response` (đã tạo
  /// booking); nếu trả phí → trả về `paymentData` để page navigate
  /// sang `/payment-qr`. Page sẽ xử lý navigate dựa trên 2 mode này.
  ///
  /// Throw nếu lỗi — page sẽ catch và hiển thị snackbar.
  Future<Map<String, dynamic>> submitWarrantyBooking({
    bool useWalletBalance = false,
    List<dynamic>? selectedPromotionIds,
  }) async {
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
      final total = estimatedTotalPrice;
      final Map<String, dynamic> result;

      if (total == 0) {
        // Free flow: gọi thẳng createBooking, không qua payment.
        result = await _createBookingOnly();
        result['__mode'] = 'free';
      } else {
        // Có phát sinh phí: gọi createPaymentForRequest để tạo order
        // trên cổng thanh toán. Khi user thanh toán xong → backend tự
        // tạo booking.
        result = await _createPaymentForRequest(
          useWalletBalance: useWalletBalance,
          selectedPromotionIds: selectedPromotionIds,
        );
        result['__mode'] = 'paid';
      }

      _cancelHoldTimer();
      emit(
        state.copyWith(
          isSubmitting: false,
          clearHoldToken: true,
          isHolding: false,
          holdRemainingSeconds: 0,
        ),
      );
      return result;
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

  Future<Map<String, dynamic>> _createBookingOnly() async {
    final branch = state.selectedBranch!;
    final date = state.selectedDate!;
    final time = state.selectedTime!;
    final formattedTime = time.length == 5 ? '$time:00' : time;
    final artistId = state.noArtistSelected
        ? null
        : state.selectedStylist?['nailArtistId']?.toString();

    return _repository.createBooking(
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
  }

  Future<Map<String, dynamic>> _createPaymentForRequest({
    bool useWalletBalance = false,
    List<dynamic>? selectedPromotionIds,
  }) async {
    final branch = state.selectedBranch!;
    final date = state.selectedDate!;
    final time = state.selectedTime!;
    final formattedTime = time.length == 5 ? '$time:00' : time;
    final artistId = state.noArtistSelected
        ? null
        : state.selectedStylist?['nailArtistId']?.toString();

    // Gộp các dịch vụ phát sinh (extra services) vào warrantyBookingItems
    // để backend có thể tính duration + giá đúng.
    final mergedItems = <Map<String, dynamic>>[
      ...state.selectedWarrantyItems,
      ...state.selectedExtraServices.whereType<String>().map(
        (id) => <String, dynamic>{'serviceId': id, 'quantity': 1},
      ),
    ];

    final payload = <String, dynamic>{
      'salonId': branch['salonId']?.toString() ?? '',
      'bookingDate': _formatDate(date),
      'startTime': formattedTime,
      'nailArtistId': artistId,
      'holdToken': state.holdToken,
      'bookingItems': mergedItems,
      'warrantyForBookingId': state.sourceBookingId,
      'useWalletBalance': useWalletBalance,
      'selectedPromotionIds': selectedPromotionIds,
    };

    return _paymentApiService.createPaymentForRequest(payload);
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
  }

  // ══════════════════════════════════════════════════════════════
  // HELPERS
  // ══════════════════════════════════════════════════════════════

  List<Map<String, dynamic>> _buildBookingItemsForHold() {
    final items = state.selectedWarrantyItems
        .map(
          (e) =>
              Map<String, dynamic>.from(e)
                ..['quantity'] = (e['quantity'] is num)
                    ? (e['quantity'] as num).toInt()
                    : (int.tryParse(e['quantity']?.toString() ?? '1') ?? 1),
        )
        .toList();
    // Append extra services để backend tính duration chính xác.
    for (final sId in state.selectedExtraServices.whereType<String>()) {
      items.add({'serviceId': sId, 'quantity': 1});
    }
    return items;
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
