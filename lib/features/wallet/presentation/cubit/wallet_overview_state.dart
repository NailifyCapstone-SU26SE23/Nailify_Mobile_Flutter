part of 'wallet_overview_cubit.dart';

enum WalletOverviewStatus { initial, loading, loaded, error }

class WalletOverviewState extends Equatable {
  final WalletOverviewStatus status;
  final WalletOverviewSnapshot? snapshot;
  final String? errorMessage;

  const WalletOverviewState({
    required this.status,
    this.snapshot,
    this.errorMessage,
  });

  const WalletOverviewState.initial()
    : status = WalletOverviewStatus.initial,
      snapshot = null,
      errorMessage = null;

  WalletOverviewState copyWith({
    WalletOverviewStatus? status,
    WalletOverviewSnapshot? snapshot,
    String? errorMessage,
  }) {
    return WalletOverviewState(
      status: status ?? this.status,
      snapshot: snapshot ?? this.snapshot,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, snapshot, errorMessage];
}
