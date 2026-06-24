import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../data/repositories/nail_design_repository.dart';
import '../../data/models/nail_filters.dart';
import '../cubit/nail_catalog_cubit.dart';
import '../widgets/nail_design_card.dart';
import '../widgets/nail_filter_sheet.dart';
import '../widgets/banner.dart';

class NailListScreen extends StatelessWidget {
  const NailListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => NailCatalogCubit(getIt<NailDesignRepository>())..loadDesigns(),
      child: const _NailListView(),
    );
  }
}

class _NailListView extends StatefulWidget {
  const _NailListView();

  @override
  State<_NailListView> createState() => _NailListViewState();
}

class _NailListViewState extends State<_NailListView> {
  final _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500) {
      context.read<NailCatalogCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<NailCatalogCubit, NailCatalogState>(
      builder: (context, state) {
        return RefreshIndicator(
          onRefresh: () => context.read<NailCatalogCubit>().refresh(),
          child: CustomScrollView(
            controller: _scrollController,
            slivers: [
              // Tiêu đề và nút Lọc
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 18, 16, 0),
                  child: Row(
                    children: [
                      const Expanded(child: Text('Nail designs', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w800))),
                      IconButton.filledTonal(
                        tooltip: 'Filter',
                        onPressed: () => _openFilters(context, state),
                        icon: const Icon(Icons.tune),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(
                child: QuizBanner(),
              ),

              // Trạng thái Loading / Error / Empty / Hiện Grid
              if (state.status == NailCatalogStatus.loading)
                const SliverFillRemaining(child: Center(child: CircularProgressIndicator()))
              else if (state.status == NailCatalogStatus.error && state.designs.isEmpty)
                SliverFillRemaining(
                  child: _ErrorState(
                    message: state.errorMessage ?? 'Could not load nails.',
                    onRetry: () => context.read<NailCatalogCubit>().loadDesigns(),
                  ),
                )
              else if (state.designs.isEmpty)
                  const SliverFillRemaining(child: Center(child: Text('No nail designs found.')))
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    sliver: SliverGrid.builder(
                      itemCount: state.designs.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        mainAxisSpacing: 12,
                        crossAxisSpacing: 12,
                        childAspectRatio: 0.72,
                      ),
                      itemBuilder: (context, index) {
                        final design = state.designs[index];
                        return NailDesignCard(
                          design: design,
                          onTap: () => context.go('/nails/${design.nailDesignId}'),
                        );
                      },
                    ),
                  ),

              // Loading thêm khi cuộn
              if (state.status == NailCatalogStatus.loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openFilters(BuildContext context, NailCatalogState state) async {
    final filters = await showModalBottomSheet<NailFilters>(
      context: context,
      isScrollControlled: true,
      builder: (_) => NailFilterSheet(
        initialFilters: state.filters,
        categoryTypes: state.categoryTypes,
      ),
    );
    if (filters != null && mounted) {
      await context.read<NailCatalogCubit>().applyFilters(filters);
    }
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}