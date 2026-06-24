import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/studio_api_service.dart';
import '../../data/models/customer_nail_model.dart';

// ===================================================================
// STATE QUẢN LÝ DANH SÁCH (CustomerNailRequests)
// ===================================================================
abstract class StudioListState {}
class StudioListInitial extends StudioListState {}
class StudioListLoading extends StudioListState {}
class StudioListLoaded extends StudioListState {
  final List<CustomerNailModel> nails;
  StudioListLoaded(this.nails);
}
class StudioListError extends StudioListState {
  final String message;
  StudioListError(this.message);
}

class StudioListCubit extends Cubit<StudioListState> {
  final StudioApiService _apiService = StudioApiService();
  StudioListCubit() : super(StudioListInitial());

  Future<void> fetchNails() async {
    emit(StudioListLoading());
    try {
      final nails = await _apiService.getMyNailRequests();
      emit(StudioListLoaded(nails));
    } catch (e) {
      emit(StudioListError(e.toString()));
    }
  }
}

// ===================================================================
// STATE QUẢN LÝ CHI TIẾT (CustomerNailRequest detail)
// ===================================================================
abstract class StudioDetailState {}
class StudioDetailInitial extends StudioDetailState {}
class StudioDetailLoading extends StudioDetailState {}
class StudioDetailLoaded extends StudioDetailState {
  final CustomerNailModel nail;
  StudioDetailLoaded(this.nail);
}
class StudioDetailError extends StudioDetailState {
  final String message;
  StudioDetailError(this.message);
}

class StudioDetailCubit extends Cubit<StudioDetailState> {
  final StudioApiService _apiService = StudioApiService();
  StudioDetailCubit() : super(StudioDetailInitial());

  /// Fetch chi tiết bằng customerNailRequestId
  Future<void> fetchDetail(String customerNailRequestId) async {
    emit(StudioDetailLoading());
    try {
      // API mới trả về đầy đủ thông tin salon + artist, không cần gọi thêm API
      final nail = await _apiService.getNailRequestDetail(customerNailRequestId);
      emit(StudioDetailLoaded(nail));
    } catch (e) {
      emit(StudioDetailError(e.toString()));
    }
  }

  /// Gửi yêu cầu duyệt (submit-review) — dùng customerNailId (int)
  Future<bool> submitReview(String nailId, String salonId) async {
    try {
      await _apiService.submitNailReview(nailId, salonId);
      // Sau khi gửi xong, refresh danh sách nếu cần
      return true;
    } catch (e) {
      emit(StudioDetailError(e.toString()));
      return false;
    }
  }
}