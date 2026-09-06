import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/models/wallet_voucher_model.dart';
import '../../data/repositories/wallet_repository.dart';

part 'my_vouchers_state.dart';

enum MyVoucherFilter { all, usable, used, expired }

class MyVouchersCubit extends Cubit<MyVouchersState> {
  final WalletRepository _repository;

  MyVouchersCubit(this._repository) : super(const MyVouchersState.initial());

  Future<void> load({bool forceRefresh = false}) async {
    if (state.status == MyVouchersStatus.loading && !forceRefresh) return;
    emit(state.copyWith(
      status: MyVouchersStatus.loading,
      errorMessage: null,
    ));
    try {
      final items = await _repository.getMyWalletVouchers(
        forceRefresh: forceRefresh,
      );
      emit(state.copyWith(
        status: MyVouchersStatus.loaded,
        items: items,
        filter: state.filter,
        errorMessage: null,
      ));
    } catch (e) {
      emit(state.copyWith(
        status: MyVouchersStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<void> refresh() => load(forceRefresh: true);

  void setFilter(MyVoucherFilter filter) {
    if (state.filter == filter) return;
    emit(state.copyWith(filter: filter));
  }

  List<WalletVoucherModel> get filteredItems {
    final all = state.items;
    switch (state.filter) {
      case MyVoucherFilter.all:
        return all;
      case MyVoucherFilter.usable:
        return all.where((v) => v.isUsableNow).toList();
      case MyVoucherFilter.used:
        return all.where((v) => v.isFullyUsed).toList();
      case MyVoucherFilter.expired:
        return all.where((v) => v.isExpired).toList();
    }
  }
}
