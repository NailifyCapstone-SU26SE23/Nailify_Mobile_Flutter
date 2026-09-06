import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/wallet_overview_model.dart';
import '../../data/repositories/wallet_repository.dart';

part 'wallet_overview_state.dart';

class WalletOverviewCubit extends Cubit<WalletOverviewState> {
  final WalletRepository _repository;

  WalletOverviewCubit(this._repository)
      : super(const WalletOverviewState.initial());

  Future<void> load({bool forceRefresh = false}) async {
    if (state.status == WalletOverviewStatus.loading && !forceRefresh) return;
    emit(state.copyWith(
      status: WalletOverviewStatus.loading,
      errorMessage: null,
    ));
    try {
      final snapshot = await _repository.getOverview(forceRefresh: forceRefresh);
      emit(state.copyWith(
        status: WalletOverviewStatus.loaded,
        snapshot: snapshot,
        errorMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: WalletOverviewStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> refresh() => load(forceRefresh: true);
}
