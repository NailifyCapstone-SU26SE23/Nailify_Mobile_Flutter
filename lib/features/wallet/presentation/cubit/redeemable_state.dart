part of 'redeemable_cubit.dart';

enum RedeemableStatus { initial, loading, loaded, error }

enum RedeemTransient { success, failure }

class RedeemableState extends Equatable {
  final RedeemableStatus status;
  final List<RedeemablePromotionModel> items;
  final bool hasMore;
  final bool isLoadingMore;
  final RedeemStatus redeemStatus;
  final RedeemOutcome? lastRedeemed;
  final RedeemTransient? transientMessage;
  final String? errorMessage;

  const RedeemableState({
    required this.status,
    required this.items,
    required this.hasMore,
    required this.isLoadingMore,
    required this.redeemStatus,
    this.lastRedeemed,
    this.transientMessage,
    this.errorMessage,
  });

  const RedeemableState.initial()
    : status = RedeemableStatus.initial,
      items = const [],
      hasMore = true,
      isLoadingMore = false,
      redeemStatus = RedeemStatus.idle,
      lastRedeemed = null,
      transientMessage = null,
      errorMessage = null;

  RedeemableState copyWith({
    RedeemableStatus? status,
    List<RedeemablePromotionModel>? items,
    bool? hasMore,
    bool? isLoadingMore,
    RedeemStatus? redeemStatus,
    RedeemOutcome? lastRedeemed,
    RedeemTransient? transientMessage,
    String? errorMessage,
  }) {
    return RedeemableState(
      status: status ?? this.status,
      items: items ?? this.items,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      redeemStatus: redeemStatus ?? this.redeemStatus,
      lastRedeemed: lastRedeemed ?? this.lastRedeemed,
      transientMessage: transientMessage,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
    status,
    items,
    hasMore,
    isLoadingMore,
    redeemStatus,
    lastRedeemed,
    transientMessage,
    errorMessage,
  ];
}
