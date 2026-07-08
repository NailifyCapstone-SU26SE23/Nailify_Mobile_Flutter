import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/booking_mock_data.dart';
import '../../data/models/promotion_model.dart';
import '../../data/nail_booking_repository_impl.dart';
import '../../domain/repositories/nail_booking_repository.dart';

part 'nail_booking_state.dart';

class NailBookingCubit extends Cubit<NailBookingState> {
  final NailBookingRepository _repository;

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

  void selectBranch(Map<String, dynamic> branch) {
    emit(
      state.copyWith(
        selectedBranch: branch,
        clearSeat: true,
        clearStylist: true,
        clearTime: true,
        artists: [],
        timeSlots: [],
        artistsStatus: NailBookingLoadStatus.initial,
        timeSlotsStatus: NailBookingLoadStatus.initial,
      ),
    );
  }

  void selectSeat(String seatId) {
    emit(state.copyWith(selectedSeatId: seatId));
  }

  void updateExtraServices(List<String?> services) {
    emit(
      state.copyWith(
        selectedExtraServices: services,
        clearStylist: true,
        clearTime: true,
        artists: [],
        timeSlots: [],
      ),
    );
  }

  /// Gọi khi user chọn ngày — reset thợ/giờ rồi fetch thợ.
  Future<void> selectDate({
    required DateTime date,
    required int nailVariantId,
    int? shapeMethodConfigId,

    /// Dùng getSuggestedArtists (NailBooking) hay getNailArtistsBySalon (ServiceBooking)
    bool useSuggestedArtists = true,
  }) async {
    emit(
      state.copyWith(
        selectedDate: date,
        clearStylist: true,
        clearTime: true,
        noArtistSelected: false,
        artists: [],
        timeSlots: [],
        artistsStatus: NailBookingLoadStatus.loading,
        timeSlotsStatus: NailBookingLoadStatus.initial,
      ),
    );

    await _fetchArtists(
      nailVariantId: nailVariantId,
      shapeMethodConfigId: shapeMethodConfigId,
      useSuggestedArtists: useSuggestedArtists,
    );
  }

  Future<void> _fetchArtists({
    required int nailVariantId,
    int? shapeMethodConfigId,
    required bool useSuggestedArtists,
  }) async {
    final branch = state.selectedBranch;
    final date = state.selectedDate;
    if (branch == null || date == null) return;

    final dateStr = _formatDate(date);

    try {
      List<Map<String, dynamic>> artists;
      if (useSuggestedArtists) {
        artists = await _repository.getSuggestedArtists(
          salonId: branch['salonId'],
          bookingDate: dateStr,
          nailVariantId: nailVariantId,
          serviceIds: state.selectedExtraServices.whereType<String>().toList(),
          shapeMethodConfigId: shapeMethodConfigId,
        );
      } else {
        artists = await _repository.getArtistsBySalon(branch['salonId']);
      }

      if (artists.isEmpty) {
        // Không có thợ → tự động chọn chế độ "không chọn thợ"
        emit(
          state.copyWith(
            artists: artists,
            artistsStatus: NailBookingLoadStatus.loaded,
            noArtistSelected: true,
          ),
        );
        await _loadSalonSlots();
      } else {
        emit(
          state.copyWith(
            artists: artists,
            artistsStatus: NailBookingLoadStatus.loaded,
          ),
        );
      }
    } catch (e) {
      emit(
        state.copyWith(
          artistsStatus: NailBookingLoadStatus.error,
          errorMessage: 'Lỗi tải danh sách thợ: $e',
        ),
      );
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
      emit(
        state.copyWith(
          timeSlots: slots,
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

    final slots = _repository.getSalonOperatingSlots(salon: branch, date: date);
    emit(
      state.copyWith(
        timeSlots: slots,
        timeSlotsStatus: NailBookingLoadStatus.loaded,
        clearTime: true,
      ),
    );
  }

  void selectTime(String time) {
    emit(state.copyWith(selectedTime: time));
  }

  void selectPromotions(List<dynamic> promos) {
    emit(state.copyWith(selectedPromotions: promos));
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
    return services.whereType<String>().fold<int>(
      0,
      (sum, id) => sum + servicePriceById(id),
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

  // ══════════════════════════════════════════════════════════════
  // SUBMIT BOOKING
  // ══════════════════════════════════════════════════════════════

  /// Tạo booking từ luồng NailVariant — trả về response map hoặc throw.
  Future<Map<String, dynamic>> createNailVariantBooking({
    required int nailVariantId,
    required List<String> serviceIds,
    List<int>? selectedPromotionIds,
    int? shapeMethodConfigId,
  }) async {
    emit(state.copyWith(isSubmitting: true));
    try {
      final s = state;
      final formattedTime = s.selectedTime!.length == 5
          ? '${s.selectedTime}:00'
          : s.selectedTime!;
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
        shapeMethodConfigId: shapeMethodConfigId,
      );
      emit(state.copyWith(isSubmitting: false));
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
      );
      emit(state.copyWith(isSubmitting: false));
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
}
