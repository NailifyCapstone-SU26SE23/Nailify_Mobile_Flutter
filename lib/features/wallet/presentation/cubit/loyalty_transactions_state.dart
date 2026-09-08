part of 'loyalty_transactions_cubit.dart';

enum LoyaltyTransactionsStatus {
  initial,
  loading,
  loadingMore,
  loaded,
  error,
}

class LoyaltyTransactionsState extends Equatable {
  final LoyaltyTransactionsStatus status;
  final List<LoyaltyTransactionModel> items;
  final int page;
  final bool hasNextPage;
  final int totalItems;
  final String? errorMessage;

  /// Cờ phụ trợ cho UI: append = true khi loadMore, false khi load đầu.
  /// Không tham gia `props` vì chỉ là tín hiệu tạm.
  final bool append;

  const LoyaltyTransactionsState({
    required this.status,
    required this.items,
    required this.page,
    required this.hasNextPage,
    required this.totalItems,
    this.errorMessage,
    this.append = false,
  });

  const LoyaltyTransactionsState.initial()
      : status = LoyaltyTransactionsStatus.initial,
        items = const [],
        page = 1,
        hasNextPage = false,
        totalItems = 0,
        errorMessage = null,
        append = false;

  LoyaltyTransactionsState copyWith({
    LoyaltyTransactionsStatus? status,
    List<LoyaltyTransactionModel>? items,
    int? page,
    bool? hasNextPage,
    int? totalItems,
    String? errorMessage,
    bool? append,
  }) {
    return LoyaltyTransactionsState(
      status: status ?? this.status,
      items: items ?? this.items,
      page: page ?? this.page,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      totalItems: totalItems ?? this.totalItems,
      errorMessage: errorMessage,
      append: append ?? this.append,
    );
  }

  @override
  List<Object?> get props => [
        status,
        items,
        page,
        hasNextPage,
        totalItems,
        errorMessage,
      ];
}
