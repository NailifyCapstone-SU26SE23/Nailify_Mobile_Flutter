part of 'my_vouchers_cubit.dart';

enum MyVouchersStatus { initial, loading, loaded, error }

class MyVouchersState extends Equatable {
  final MyVouchersStatus status;
  final List<WalletVoucherModel> items;
  final MyVoucherFilter filter;
  final String? errorMessage;

  const MyVouchersState({
    required this.status,
    required this.items,
    required this.filter,
    this.errorMessage,
  });

  const MyVouchersState.initial()
    : status = MyVouchersStatus.initial,
      items = const [],
      filter = MyVoucherFilter.all,
      errorMessage = null;

  MyVouchersState copyWith({
    MyVouchersStatus? status,
    List<WalletVoucherModel>? items,
    MyVoucherFilter? filter,
    String? errorMessage,
  }) {
    return MyVouchersState(
      status: status ?? this.status,
      items: items ?? this.items,
      filter: filter ?? this.filter,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, items, filter, errorMessage];
}
