import 'package:flutter_bloc/flutter_bloc.dart';
import '../../data/datasources/studio_api_service.dart';
import '../../data/models/customer_nail_model.dart';

// state quản lý danh sách
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
      final nails = await _apiService.getMyNails();
      emit(StudioListLoaded(nails));
    } catch (e) {
      emit(StudioListError(e.toString()));
    }
  }
}

// state quản lý chi tiết
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

  Future<void> fetchDetail(String id) async {
    emit(StudioDetailLoading());
    try {
      final nail = await _apiService.getNailDetail(id);

      // NẾU MÓNG ĐƯỢC DUYỆT VÀ CÓ ID THỢ, GỌI API ĐỂ LỤM THÔNG TIN
      if (nail.status == 'Approved' && nail.approvedArtistId != null) {
        try {
          final artistData = await _apiService.getArtistDetail(nail.approvedArtistId!);
          final firstName = artistData['firstName']?.toString() ?? '';
          final lastName = artistData['lastName']?.toString() ?? '';

          nail.stylistName = '$firstName $lastName'.trim();
          nail.salonId = artistData['salonId']?.toString();
        } catch (e) {
          nail.stylistName = 'Không thể tải tên thợ';
        }
      }

      emit(StudioDetailLoaded(nail));
    } catch (e) {
      emit(StudioDetailError(e.toString()));
    }
  }
  Future<bool> submitReview(String id) async {
    try {
      await _apiService.submitNailReview(id);
      await fetchDetail(id);
      return true;
    } catch (e) {
      emit(StudioDetailError(e.toString()));
      return false;
    }
  }
}