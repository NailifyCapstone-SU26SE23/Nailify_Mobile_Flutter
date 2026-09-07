import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/signalr_service.dart';
import '../../../../generated/l10n_x.dart';
import '../../data/models/wallet_voucher_model.dart';
import '../../data/repositories/wallet_repository.dart';
import '../cubit/wallet_overview_cubit.dart';
import '../widgets/empty_wallet_state.dart';
import '../widgets/loyalty_tier_card.dart';
import '../widgets/wallet_balance_card.dart';

class WalletOverviewPage extends StatelessWidget {
  const WalletOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) =>
          WalletOverviewCubit(getIt<WalletRepository>())..load(),
      child: const _WalletOverviewView(),
    );
  }
}

class _WalletOverviewView extends StatefulWidget {
  const _WalletOverviewView();

  @override
  State<_WalletOverviewView> createState() => _WalletOverviewViewState();
}

class _WalletOverviewViewState extends State<_WalletOverviewView> {
  StreamSubscription<dynamic>? _walletSub;
  StreamSubscription<dynamic>? _voucherSub;
  final SignalRService _signalR = getIt<SignalRService>();

  @override
  void initState() {
    super.initState();
    _walletSub = _signalR.onWalletPointsChanged.listen((_) {
      if (mounted) context.read<WalletOverviewCubit>().refresh();
    });
    _voucherSub = _signalR.onVoucherReceived.listen((_) {
      if (mounted) context.read<WalletOverviewCubit>().refresh();
    });
  }

  @override
  void dispose() {
    _walletSub?.cancel();
    _voucherSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.l10n.walletTitle,
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
          IconButton(
            tooltip: context.l10n.pointsHistoryTitle,
            onPressed: () => context.push('/profile/wallet/transactions'),
            icon: const Icon(
              Icons.history_rounded,
              color: AppColors.primaryDark,
            ),
          ),
          BlocBuilder<WalletOverviewCubit, WalletOverviewState>(
            builder: (context, state) {
              return IconButton(
                onPressed: state.status == WalletOverviewStatus.loading
                    ? null
                    : () => context.read<WalletOverviewCubit>().refresh(),
                icon: state.status == WalletOverviewStatus.loading
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
      body: BlocBuilder<WalletOverviewCubit, WalletOverviewState>(
        builder: (context, state) {
          if (state.status == WalletOverviewStatus.initial ||
              (state.status == WalletOverviewStatus.loading &&
                  state.snapshot == null)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == WalletOverviewStatus.error &&
              state.snapshot == null) {
            return EmptyWalletState(
              icon: Icons.error_outline_rounded,
              title: state.errorMessage ??
                  context.l10n.walletOverviewLoadError,
              actionLabel: context.l10n.walletRedeem,
              onAction: () =>
                  context.read<WalletOverviewCubit>().refresh(),
            );
          }
          final snapshot = state.snapshot;
          if (snapshot == null) {
            return const SizedBox.shrink();
          }
          return RefreshIndicator(
            onRefresh: () =>
                context.read<WalletOverviewCubit>().refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LoyaltyTierCard(
                    tier: snapshot.loyalty.loyaltyTier,
                    lifetimePoints: snapshot.loyalty.lifetimePoints,
                    progress: snapshot.loyalty.progressPercent,
                    pointsToNext: snapshot.loyalty.pointsToNextTier,
                    hasNextTier: snapshot.loyalty.hasNextTier,
                  ),
                  const SizedBox(height: 16),
                  WalletBalanceCard(
                    loyaltyPoints: snapshot.loyalty.loyaltyPoint,
                    usableVoucherCount: snapshot.usableVoucherCount,
                  ),
                  const SizedBox(height: 20),
                  if (snapshot.expiringSoon.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.walletExpiringSoon,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: AppColors.textPrimary,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              context.push('/profile/wallet/vouchers'),
                          child: Text(
                            context.l10n.viewAll,
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...snapshot.expiringSoon
                        .map((v) => _buildQuickVoucherTile(context, v)),
                  ],
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildQuickVoucherTile(BuildContext context, WalletVoucherModel v) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: v.imageUrl != null && v.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.network(
                      v.imageUrl!,
                      fit: BoxFit.cover,
                      errorBuilder: (_, _, _) => const Icon(
                        Icons.local_offer_rounded,
                        color: AppColors.primary,
                      ),
                    ),
                  )
                : const Icon(
                    Icons.local_offer_rounded,
                    color: AppColors.primary,
                  ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  v.promotionName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  v.discountLabel,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Text(
            v.endDate != null
                ? context.l10n.expiredOn(_fmt(v.endDate!))
                : '',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey.shade500,
            ),
          ),
        ],
      ),
    );
  }

  String _fmt(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/'
      '${d.month.toString().padLeft(2, '0')}/'
      '${d.year}';
}
