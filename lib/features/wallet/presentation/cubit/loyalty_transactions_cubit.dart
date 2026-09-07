import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/loyalty_transaction_model.dart';
import '../../data/repositories/wallet_repository.dart';

part 'loyalty_transactions_state.dart';

class LoyaltyTransactionsCubit extends Cubit<LoyaltyTransactionsState> {
  final WalletRepository _repository;

  LoyaltyTransactionsCubit(this._repository)
      : super(const LoyaltyTransactionsState.initial());

  static const int pageSize = 20;

  Future<void> load({bool forceRefresh = false}) async {
    if (state.status == LoyaltyTransactionsStatus.loading && !forceRefresh) {
      return;
    }
    emit(state.copyWith(
      status: LoyaltyTransactionsStatus.loading,
      errorMessage: null,
      append: false,
    ));
    try {
      final result = await _repository.getMyLoyaltyTransactions(
        pageNumber: 1,
        pageSize: pageSize,
        forceRefresh: forceRefresh,
      );
      emit(state.copyWith(
        status: LoyaltyTransactionsStatus.loaded,
        items: result.items,
        page: result.page,
        hasNextPage: result.hasNextPage,
        totalItems: result.totalItems,
        errorMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoyaltyTransactionsStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> loadMore() async {
    if (state.status == LoyaltyTransactionsStatus.loadingMore) return;
    if (!state.hasNextPage) return;
    emit(state.copyWith(
      status: LoyaltyTransactionsStatus.loadingMore,
      errorMessage: null,
    ));
    try {
      final nextPage = state.page + 1;
      final result = await _repository.getMyLoyaltyTransactions(
        pageNumber: nextPage,
        pageSize: pageSize,
      );
      emit(state.copyWith(
        status: LoyaltyTransactionsStatus.loaded,
        items: [...state.items, ...result.items],
        page: result.page,
        hasNextPage: result.hasNextPage,
        errorMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: LoyaltyTransactionsStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> refresh() => load(forceRefresh: true);
}
