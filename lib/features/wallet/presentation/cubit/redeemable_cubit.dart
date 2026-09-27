import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/redeem_outcome.dart';
import '../../data/models/redeemable_promotion_model.dart';
import '../../data/repositories/wallet_repository.dart';

part 'redeemable_state.dart';

enum RedeemStatus { idle, redeeming }

class RedeemableCubit extends Cubit<RedeemableState> {
  final WalletRepository _repository;

  int _page = 1;
  bool _hasMore = true;
  bool _isFetching = false;
  bool _isRedeeming = false;

  RedeemableCubit(this._repository) : super(const RedeemableState.initial());

  Future<void> loadFirst() async {
    _page = 1;
    _hasMore = true;
    emit(
      state.copyWith(
        status: RedeemableStatus.loading,
        items: const [],
        hasMore: true,
        isLoadingMore: false,
        errorMessage: null,
        transientMessage: null,
      ),
    );
    await _fetchPage();
  }

  Future<void> loadMore() async {
    if (_isFetching || !_hasMore) return;
    _isFetching = true;
    emit(state.copyWith(isLoadingMore: true));
    _page += 1;
    await _fetchPage(append: true);
    _isFetching = false;
  }

  Future<void> _fetchPage({bool append = false}) async {
    try {
      final response = await _repository.getRedeemable(
        page: _page,
        pageSize: 10,
      );
      _hasMore = response.hasNext;
      final next = append
          ? [...state.items, ...response.items]
          : response.items;
      emit(
        state.copyWith(
          status: RedeemableStatus.loaded,
          items: next,
          hasMore: _hasMore,
          isLoadingMore: false,
          errorMessage: null,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: RedeemableStatus.error,
          isLoadingMore: false,
          errorMessage: e.toString(),
        ),
      );
    }
  }

  /// Trả về RedeemOutcome nếu thành công, null nếu thất bại.
  /// Phát transient state để UI có thể show toast.
  Future<RedeemOutcome?> redeem(int promotionId) async {
    if (_isRedeeming) return null;
    _isRedeeming = true;
    emit(
      state.copyWith(
        redeemStatus: RedeemStatus.redeeming,
        transientMessage: null,
      ),
    );
    try {
      final result = await _repository.redeem(promotionId);
      emit(
        state.copyWith(
          redeemStatus: RedeemStatus.idle,
          lastRedeemed: result,
          transientMessage: RedeemTransient.success,
        ),
      );
      return result;
    } catch (e) {
      emit(
        state.copyWith(
          redeemStatus: RedeemStatus.idle,
          transientMessage: RedeemTransient.failure,
          errorMessage: e.toString(),
        ),
      );
      return null;
    } finally {
      _isRedeeming = false;
    }
  }

  void clearTransient() {
    if (state.transientMessage == null) return;
    emit(state.copyWith(transientMessage: null));
  }
}
