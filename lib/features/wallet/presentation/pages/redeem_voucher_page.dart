import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../generated/l10n_x.dart';
import '../../data/models/redeemable_promotion_model.dart';
import '../../data/repositories/wallet_repository.dart';
import '../cubit/redeemable_cubit.dart';
import '../cubit/wallet_overview_cubit.dart';
import '../widgets/empty_wallet_state.dart';
import '../widgets/redeemable_detail_sheet.dart';
import '../widgets/voucher_filter_chips.dart';
import '../widgets/voucher_grid_card.dart';

class RedeemVoucherPage extends StatelessWidget {
  const RedeemVoucherPage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              RedeemableCubit(getIt<WalletRepository>())..loadFirst(),
        ),
        BlocProvider(
          create: (_) =>
              WalletOverviewCubit(getIt<WalletRepository>())..load(),
        ),
      ],
      child: const _RedeemVoucherView(),
    );
  }
}

class _RedeemVoucherView extends StatefulWidget {
  const _RedeemVoucherView();

  @override
  State<_RedeemVoucherView> createState() => _RedeemVoucherViewState();
}

class _RedeemVoucherViewState extends State<_RedeemVoucherView> {
  VoucherFilterType _filter = VoucherFilterType.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(
          context.l10n.walletRedeem,
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
        actions: [
          BlocBuilder<RedeemableCubit, RedeemableState>(
            builder: (context, state) {
              return IconButton(
                onPressed: state.status == RedeemableStatus.loading
                    ? null
                    : () =>
                        context.read<RedeemableCubit>().loadFirst(),
                icon: state.status == RedeemableStatus.loading
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
      body: BlocConsumer<RedeemableCubit, RedeemableState>(
        listenWhen: (prev, curr) =>
            prev.transientMessage != curr.transientMessage,
        listener: (context, state) {
          // Cubit không còn đẩy message ra ngoài — sheet tự xử lý.
          // Giữ listener này cho trường hợp redeem từ nơi khác (future).
          if (state.transientMessage != null) {
            context.read<RedeemableCubit>().clearTransient();
          }
        },
        builder: (context, redeemState) {
          return Column(
            children: [
              _buildBalanceBar(context),
              const SizedBox(height: 8),
              VoucherFilterChips(
                selected: _filter,
                onChanged: (t) => setState(() => _filter = t),
              ),
              const SizedBox(height: 8),
              Expanded(child: _buildGrid(context, redeemState)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBalanceBar(BuildContext context) {
    return BlocBuilder<WalletOverviewCubit, WalletOverviewState>(
      builder: (context, state) {
        final points = state.snapshot?.loyalty.loyaltyPoint ?? 0;
        return Container(
          width: double.infinity,
          margin: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppColors.primary,
                AppColors.primaryDark.withValues(alpha: 0.9),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white,
                size: 22,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.balanceHint(points),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              Text(
                '$points ${context.l10n.pointsShort}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGrid(BuildContext context, RedeemableState state) {
    if (state.status == RedeemableStatus.initial ||
        (state.status == RedeemableStatus.loading && state.items.isEmpty)) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.status == RedeemableStatus.error && state.items.isEmpty) {
      return EmptyWalletState(
        icon: Icons.error_outline_rounded,
        title: state.errorMessage ?? context.l10n.redeemFailed,
        actionLabel: context.l10n.viewAll,
        onAction: () => context.read<RedeemableCubit>().loadFirst(),
      );
    }
    final filtered = _applyFilter(state.items);
    if (filtered.isEmpty) {
      return EmptyWalletState(
        icon: Icons.card_giftcard_outlined,
        title: context.l10n.emptyRedeemable,
        hint: context.l10n.emptyRedeemableHint,
      );
    }
    return BlocBuilder<WalletOverviewCubit, WalletOverviewState>(
      builder: (context, overviewState) {
        final balance = overviewState.snapshot?.loyalty.loyaltyPoint ?? 0;
        return GridView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          physics: const AlwaysScrollableScrollPhysics(),
          gridDelegate:
              const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 0.62,
          ),
          itemCount: filtered.length,
          itemBuilder: (context, index) {
            final promo = filtered[index];
            final isRedeeming =
                state.redeemStatus == RedeemStatus.redeeming;
            return VoucherGridCard(
              promotion: promo,
              userBalance: balance,
              canRedeem: promo.canRedeem && !isRedeeming,
              onTap: () => _openDetailSheet(
                promotion: promo,
                balance: balance,
              ),
            );
          },
        );
      },
    );
  }

  List _applyFilter(List items) {
    switch (_filter) {
      case VoucherFilterType.all:
        return items;
      case VoucherFilterType.percentage:
        return items
            .where((p) => p.discountType.toLowerCase() == 'percentage')
            .toList();
      case VoucherFilterType.fixedAmount:
        return items
            .where((p) => p.discountType.toLowerCase() != 'percentage')
            .toList();
    }
  }

  /// Mở sheet chi tiết. Nếu user bấm "Đổi điểm" trong sheet thì flow sẽ:
  /// 1. Sheet pop về parent với sentinel `'__redeem__'`
  /// 2. Parent gọi API redeem
  /// 3. Mở lại sheet kết quả với message từ BE
  Future<void> _openDetailSheet({
    required RedeemablePromotionModel promotion,
    required int balance,
  }) async {
    // Dùng this.context (State context) thay vì parameter để analyzer không
    // báo "guarded by unrelated mounted check" sau nhiều lần await.
    // Mọi thao tác với context đều đi qua `if (!mounted) return;` ngay trước.

    final redeemCubit = context.read<RedeemableCubit>();
    final overviewCubit = context.read<WalletOverviewCubit>();

    // Cache các giá trị l10n + giá trị nội bộ trước async.
    final successMsg = context.l10n.redeemSuccess;
    final failedMsg = context.l10n.redeemFailed;
    final modalContext = context;
    final navigator = Navigator.of(context, rootNavigator: false);

    final points = promotion.pointsRequired;
    final enoughPoints = points == null || points <= balance;

    // Bước 1: Mở sheet chi tiết, đợi user bấm "Đổi điểm" (sentinel).
    if (!mounted) return;
    final firstResult = await showModalBottomSheet<String?>(
      context: modalContext,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => RedeemableDetailSheet(
        promotion: promotion,
        userBalance: balance,
        canRedeem: enoughPoints,
      ),
    );

    if (!mounted || firstResult != '__redeem__') return;

    // Bước 2: Gọi API redeem.
    String? message;
    bool isSuccess = false;
    try {
      final outcome = await redeemCubit.redeem(promotion.promotionId);
      if (outcome != null) {
        // Reload balance + list sau khi redeem.
        overviewCubit.load(forceRefresh: true);
        if (!mounted) return;
        redeemCubit.loadFirst();
        message = outcome.message.isNotEmpty
            ? outcome.message
            : successMsg;
        isSuccess = true;
      } else {
        if (!mounted) return;
        message = failedMsg;
        isSuccess = false;
      }
    } catch (e) {
      if (!mounted) return;
      message = _extractMessage(e);
      isSuccess = false;
    }

    if (!mounted) return;

    // Bước 3: Mở sheet kết quả — dùng Navigator đã capture ở đầu hàm.
    await navigator.push(
      ModalBottomSheetRoute<void>(
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _RedeemResultSheet(
          success: isSuccess,
          message: message ?? '',
          promotionName: promotion.name,
        ),
      ),
    );
  }

  String _extractMessage(Object e) {
    final raw = e.toString();
    final match = RegExp(r'message:\s*([^,)]+)').firstMatch(raw);
    if (match != null) return match.group(1)!.trim();
    return raw
        .replaceAll('AppException: ', '')
        .replaceAll('Exception: ', '')
        .trim();
  }
}

/// Bottom sheet chỉ hiển thị message kết quả redeem (success/error).
class _RedeemResultSheet extends StatelessWidget {
  final bool success;
  final String message;
  final String promotionName;

  const _RedeemResultSheet({
    required this.success,
    required this.message,
    required this.promotionName,
  });

  @override
  Widget build(BuildContext context) {
    final color = success ? Colors.green : Colors.red;
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                success
                    ? Icons.check_rounded
                    : Icons.error_outline_rounded,
                size: 48,
                color: color,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              success ? context.l10n.redeemSuccess : context.l10n.redeemFailed,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
                height: 1.4,
              ),
            ),
            if (success) ...[
              const SizedBox(height: 4),
              Text(
                promotionName,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  context.l10n.redeemConfirmCancel,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
