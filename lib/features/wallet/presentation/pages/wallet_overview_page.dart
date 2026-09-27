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
import '../widgets/cash_wallet_card.dart';
import '../widgets/convert_points_sheet.dart';
import '../widgets/deposit_sheet.dart';
import '../widgets/empty_wallet_state.dart';
import '../widgets/loyalty_rewards_card.dart';
import '../widgets/withdraw_sheet.dart';
import 'wallet_transactions_page.dart';

class WalletOverviewPage extends StatelessWidget {
  const WalletOverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => WalletOverviewCubit(getIt<WalletRepository>())..load(),
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

  void _openDepositSheet(BuildContext context) {
    DepositSheet.show(
      context,
      onConfirmDeposit: (amount) async {
        final repo = getIt<WalletRepository>();
        final paymentData = await repo.requestDeposit(amount);
        if (!mounted) return;

        if (paymentData.isNotEmpty && context.mounted) {
          final Map<String, dynamic> enrichedData = Map<String, dynamic>.from(
            paymentData,
          );
          enrichedData['paymentType'] = 'WalletDeposit';
          enrichedData['policy'] = 'Nạp tiền vào ví cá nhân';
          context.push('/payment-qr', extra: enrichedData);
        }
      },
    );
  }

  void _openWithdrawSheet(BuildContext context, double availableBalance) {
    final cubit = context.read<WalletOverviewCubit>();
    WithdrawSheet.show(
      context,
      availableBalance: availableBalance,
      onConfirmWithdraw:
          ({
            required double amount,
            required String bankName,
            required String bankCode,
            required String accountNumber,
            required String accountHolderName,
          }) async {
            final repo = getIt<WalletRepository>();
            final success = await repo.requestWithdrawal(
              amount: amount,
              bankName: bankName,
              bankCode: bankCode,
              accountNumber: accountNumber,
              accountHolderName: accountHolderName,
            );
            if (mounted && success) {
              cubit.refresh();
            }
            return success;
          },
    );
  }

  void _openConvertPointsSheet(BuildContext context, double availableBalance) {
    final cubit = context.read<WalletOverviewCubit>();
    ConvertPointsSheet.show(
      context,
      availableBalance: availableBalance,
      onConfirmConvert: (moneyAmount) async {
        final repo = getIt<WalletRepository>();
        final msg = await repo.convertMoneyToPoints(moneyAmount);
        if (mounted) {
          cubit.refresh();
        }
        return msg;
      },
    );
  }

  void _openTransactionsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const WalletTransactionsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        title: Text(
          context.l10n.walletTitle,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w900,
            fontSize: 20,
            letterSpacing: 0.2,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        actions: [
          IconButton(
            tooltip: 'Lịch sử ví tiền mặt',
            onPressed: () => _openTransactionsPage(context),
            icon: const Icon(
              Icons.receipt_long_rounded,
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
                    : const Icon(
                        Icons.refresh_rounded,
                        color: AppColors.primaryDark,
                      ),
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
              title: state.errorMessage ?? context.l10n.walletOverviewLoadError,
              actionLabel: context.l10n.walletRedeem,
              onAction: () => context.read<WalletOverviewCubit>().refresh(),
            );
          }
          final snapshot = state.snapshot;
          if (snapshot == null) {
            return const SizedBox.shrink();
          }

          final cash = snapshot.cashSummary;
          final balance = cash?.balance ?? 0.0;
          final frozenBalance = cash?.frozenBalance ?? 0.0;
          final availableBalance =
              cash?.availableBalance ?? (balance - frozenBalance);

          return RefreshIndicator(
            onRefresh: () => context.read<WalletOverviewCubit>().refresh(),
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Card 1: Digital Cash Wallet Card
                  CashWalletCard(
                    balance: balance,
                    frozenBalance: frozenBalance,
                    loyaltyTierName: snapshot.loyalty.loyaltyTier?.name,
                    onDepositPressed: () => _openDepositSheet(context),
                    onWithdrawPressed: () =>
                        _openWithdrawSheet(context, availableBalance),
                    onConvertPointsPressed: () =>
                        _openConvertPointsSheet(context, availableBalance),
                    onHistoryPressed: () => _openTransactionsPage(context),
                  ),
                  const SizedBox(height: 16),

                  // Card 2: Loyalty Tier, Reward Points & Voucher Actions Card
                  LoyaltyRewardsCard(
                    tier: snapshot.loyalty.loyaltyTier,
                    loyaltyPoints: snapshot.loyalty.loyaltyPoint,
                    lifetimePoints: snapshot.loyalty.lifetimePoints,
                    progress: snapshot.loyalty.progressPercent,
                    pointsToNext: snapshot.loyalty.pointsToNextTier,
                    hasNextTier: snapshot.loyalty.hasNextTier,
                    usableVoucherCount: snapshot.usableVoucherCount,
                    onConvertPointsPressed: () =>
                        _openConvertPointsSheet(context, availableBalance),
                    onRedeemPressed: () =>
                        context.push('/profile/wallet/redeem'),
                    onMyVouchersPressed: () =>
                        context.push('/profile/wallet/vouchers'),
                    onHistoryPressed: () =>
                        context.push('/profile/wallet/transactions'),
                  ),
                  const SizedBox(height: 20),

                  if (snapshot.expiringSoon.isNotEmpty) ...[
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            context.l10n.walletExpiringSoon,
                            style: const TextStyle(
                              fontSize: 15,
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
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...snapshot.expiringSoon.map(
                      (v) => _buildQuickVoucherTile(context, v),
                    ),
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
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: v.imageUrl != null && v.imageUrl!.isNotEmpty
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
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
                    fontSize: 13.5,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  v.discountLabel,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primaryDark,
                  ),
                ),
              ],
            ),
          ),
          Text(
            v.endDate != null ? context.l10n.expiredOn(_fmt(v.endDate!)) : '',
            style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
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
