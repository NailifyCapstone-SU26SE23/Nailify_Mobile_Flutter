import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/signalr_service.dart';
import '../../../../generated/l10n_x.dart';
import '../../data/repositories/wallet_repository.dart';
import '../cubit/loyalty_transactions_cubit.dart';
import '../widgets/empty_wallet_state.dart';
import '../widgets/loyalty_transaction_tile.dart';

/// Lịch sử biến động điểm thưởng của khách hàng.
class PointsHistoryPage extends StatelessWidget {
  const PointsHistoryPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          LoyaltyTransactionsCubit(getIt<WalletRepository>())..load(),
      child: const _PointsHistoryView(),
    );
  }
}

class _PointsHistoryView extends StatefulWidget {
  const _PointsHistoryView();

  @override
  State<_PointsHistoryView> createState() => _PointsHistoryViewState();
}

class _PointsHistoryViewState extends State<_PointsHistoryView> {
  final ScrollController _scrollController = ScrollController();
  StreamSubscription<dynamic>? _walletSub;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _walletSub = getIt<SignalRService>().onWalletPointsChanged.listen((_) {
      if (mounted) {
        context.read<LoyaltyTransactionsCubit>().refresh();
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final position = _scrollController.position;
    if (position.pixels >= position.maxScrollExtent - 200) {
      context.read<LoyaltyTransactionsCubit>().loadMore();
    }
  }

  @override
  void dispose() {
    _walletSub?.cancel();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 20,
            color: AppColors.primaryDark,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          context.l10n.pointsHistoryTitle,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          BlocBuilder<LoyaltyTransactionsCubit, LoyaltyTransactionsState>(
            builder: (context, state) {
              return IconButton(
                onPressed: state.status == LoyaltyTransactionsStatus.loading
                    ? null
                    : () => context.read<LoyaltyTransactionsCubit>().refresh(),
                icon: state.status == LoyaltyTransactionsStatus.loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              );
            },
          ),
        ],
      ),
      body: BlocBuilder<LoyaltyTransactionsCubit, LoyaltyTransactionsState>(
        builder: (context, state) {
          if (state.status == LoyaltyTransactionsStatus.initial ||
              (state.status == LoyaltyTransactionsStatus.loading &&
                  state.items.isEmpty)) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state.status == LoyaltyTransactionsStatus.error &&
              state.items.isEmpty) {
            return EmptyWalletState(
              icon: Icons.error_outline_rounded,
              title: state.errorMessage ?? context.l10n.pointsHistoryLoadError,
              actionLabel: context.l10n.retry,
              onAction: () =>
                  context.read<LoyaltyTransactionsCubit>().refresh(),
            );
          }

          if (state.items.isEmpty) {
            return EmptyWalletState(
              icon: Icons.history_rounded,
              title: context.l10n.pointsHistoryEmpty,
              hint: context.l10n.pointsHistoryEmptyHint,
            );
          }

          return RefreshIndicator(
            onRefresh: () => context.read<LoyaltyTransactionsCubit>().refresh(),
            child: ListView.builder(
              controller: _scrollController,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              itemCount: state.items.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildSummary(state);
                }
                final t = state.items[index - 1];
                return LoyaltyTransactionTile(transaction: t);
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildSummary(LoyaltyTransactionsState state) {
    final earned = state.items
        .where((t) => t.points > 0)
        .fold<int>(0, (sum, t) => sum + t.points);
    final spent = state.items
        .where((t) => t.points < 0)
        .fold<int>(0, (sum, t) => sum + t.points);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primaryDark],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.pointsHistorySubtitle,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(
                child: _SummaryStat(
                  label: context.l10n.pointsHistoryEarned,
                  value: '+$earned',
                  color: Colors.lightGreenAccent.shade100,
                ),
              ),
              Container(
                width: 1,
                height: 36,
                color: Colors.white24,
                margin: const EdgeInsets.symmetric(horizontal: 12),
              ),
              Expanded(
                child: _SummaryStat(
                  label: context.l10n.pointsHistorySpent,
                  value: '$spent',
                  color: Colors.orangeAccent.shade100,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryStat({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            color: color,
            fontWeight: FontWeight.w900,
            height: 1.1,
          ),
        ),
      ],
    );
  }
}
