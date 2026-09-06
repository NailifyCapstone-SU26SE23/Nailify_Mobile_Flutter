import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../generated/l10n_x.dart';
import '../../data/repositories/wallet_repository.dart';
import '../cubit/my_vouchers_cubit.dart';
import '../widgets/empty_wallet_state.dart';
import '../widgets/voucher_tile.dart';

class MyVouchersPage extends StatelessWidget {
  const MyVouchersPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => MyVouchersCubit(getIt<WalletRepository>())..load(),
      child: const _MyVouchersView(),
    );
  }
}

class _MyVouchersView extends StatelessWidget {
  const _MyVouchersView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.l10n.walletMyVouchers,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: true,
      ),
      body: BlocBuilder<MyVouchersCubit, MyVouchersState>(
        builder: (context, state) {
          if (state.status == MyVouchersStatus.initial ||
              (state.status == MyVouchersStatus.loading &&
                  state.items.isEmpty)) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == MyVouchersStatus.error &&
              state.items.isEmpty) {
            return EmptyWalletState(
              icon: Icons.error_outline_rounded,
              title: state.errorMessage ?? 'Lỗi tải voucher',
              actionLabel: context.l10n.viewAll,
              onAction: () => context.read<MyVouchersCubit>().refresh(),
            );
          }
          return RefreshIndicator(
            onRefresh: () => context.read<MyVouchersCubit>().refresh(),
            child: Column(
              children: [
                _buildFilterTabs(context, state.filter),
                Expanded(child: _buildList(context, state)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildFilterTabs(BuildContext context, MyVoucherFilter current) {
    final entries = <(MyVoucherFilter, String)>[
      (MyVoucherFilter.all, context.l10n.walletVoucherAll),
      (MyVoucherFilter.usable, context.l10n.walletVoucherUsable),
      (MyVoucherFilter.used, context.l10n.walletVoucherUsed),
      (MyVoucherFilter.expired, context.l10n.walletVoucherExpired),
    ];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      color: Colors.white,
      child: Row(
        children: entries.map((entry) {
          final selected = entry.$1 == current;
          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: InkWell(
                borderRadius: BorderRadius.circular(10),
                onTap: () => context
                    .read<MyVouchersCubit>()
                    .setFilter(entry.$1),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
                  decoration: BoxDecoration(
                    color: selected
                        ? AppColors.primary.withValues(alpha: 0.12)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    entry.$2,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildList(BuildContext context, MyVouchersState state) {
    final items = context.read<MyVouchersCubit>().filteredItems;
    if (items.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: EmptyWalletState(
          icon: Icons.confirmation_number_outlined,
          title: context.l10n.emptyWalletVouchers,
          hint: context.l10n.emptyWalletVouchersHint,
          actionLabel: context.l10n.walletRedeem,
          onAction: () => context.push('/profile/wallet/redeem'),
        ),
      );
    }
    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final v = items[index];
        return VoucherTile(
          voucher: v,
          onTap: () => context.push(
            '/profile/wallet/vouchers/${v.userPromotionUsageId}',
            extra: v,
          ),
        );
      },
    );
  }
}
