import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../data/repositories/nail_design_repository.dart';
import '../../data/repositories/favorite_nail_repository.dart';
import '../../data/models/nail_design_model.dart';
import '../../data/models/nail_filters.dart';
import '../cubit/nail_catalog_cubit.dart';
import '../widgets/nail_design_card.dart';
import '../widgets/nail_filter_sheet.dart';
import '../widgets/banner.dart';
import '../../../quiz/data/models/quiz_result_model.dart';

class NailListScreen extends StatelessWidget {
  final List<QuizResultModel>? matchedResults;

  // Static global field to persist match results until logout
  static List<QuizResultModel>? _globalMatchedResults;

  const NailListScreen({super.key, this.matchedResults});

  static void clearMatchedResults() {
    _globalMatchedResults = null;
  }

  @override
  Widget build(BuildContext context) {
    if (matchedResults != null && matchedResults!.isNotEmpty) {
      _globalMatchedResults = matchedResults;
    }
    return BlocProvider(
      create: (_) =>
          NailCatalogCubit(getIt<NailDesignRepository>())..loadDesigns(),
      child: _NailListView(matchedResults: _globalMatchedResults),
    );
  }
}

class _NailListView extends StatefulWidget {
  final List<QuizResultModel>? matchedResults;

  const _NailListView({this.matchedResults});

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

  // Calculate highest matching score percentage for a given nail design
  int? _getMatchPercentage(NailDesignModel design) {
    if (widget.matchedResults == null || widget.matchedResults!.isEmpty) {
      return null;
    }

    double maxScore = -1.0;

    for (final r in widget.matchedResults!) {
      final variantId = int.tryParse(r.nailVariantId);
      final hasVariantMatch =
          variantId != null &&
          design.nailVariants.any((v) => v.nailVariantId == variantId);

      final designNameClean = design.name.toLowerCase().trim();
      final resultNameClean = r.name.toLowerCase().trim();
      final hasNameMatch =
          designNameClean == resultNameClean ||
          resultNameClean.contains(designNameClean) ||
          designNameClean.contains(resultNameClean);

      if (hasVariantMatch || hasNameMatch) {
        if (r.score > maxScore) {
          maxScore = r.score;
        }
      }
    }

    if (maxScore >= 0) {
      return (maxScore <= 1 ? maxScore * 100 : maxScore).toInt();
    }
    return null;
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
                      IconButton(
                        icon: const Icon(
                          Icons.arrow_back_ios_new_rounded,
                          size: 18,
                        ),
                        onPressed: () => context.go('/'),
                      ),
                      const SizedBox(width: 4),
                      const Expanded(
                        child: Text(
                          'Thiết kế móng',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.tune_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        style: IconButton.styleFrom(
                          backgroundColor: AppColors.primary.withValues(
                            alpha: 0.08,
                          ),
                          padding: const EdgeInsets.all(10),
                        ),
                        onPressed: () => _openFilters(context, state),
                      ),
                    ],
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: QuizBanner()),

              // Trạng thái Loading / Error / Empty / Hiện Grid
              if (state.status == NailCatalogStatus.loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (state.status == NailCatalogStatus.error &&
                  state.designs.isEmpty)
                SliverFillRemaining(
                  child: _ErrorState(
                    message:
                        state.errorMessage ?? 'Không thể tải danh sách móng.',
                    onRetry: () =>
                        context.read<NailCatalogCubit>().loadDesigns(),
                  ),
                )
              else if (state.designs.isEmpty)
                const SliverFillRemaining(
                  child: Center(
                    child: Text(
                      'Không tìm thấy thiết kế móng nào.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                () {
                  final sortedDesigns = List<NailDesignModel>.from(
                    state.designs,
                  );

                  if (widget.matchedResults != null &&
                      widget.matchedResults!.isNotEmpty) {
                    sortedDesigns.sort((a, b) {
                      final aPct = _getMatchPercentage(a);
                      final bPct = _getMatchPercentage(b);

                      if (aPct != null && bPct == null) return -1;
                      if (aPct == null && bPct != null) return 1;
                      if (aPct != null && bPct != null) {
                        return bPct.compareTo(aPct); // Sort descending
                      }
                      return 0;
                    });
                  }

                  return SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    sliver: SliverGrid.builder(
                      itemCount: sortedDesigns.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 12,
                            crossAxisSpacing: 12,
                            childAspectRatio: 0.55,
                          ),
                      itemBuilder: (context, index) {
                        final design = sortedDesigns[index];
                        final matchPct = _getMatchPercentage(design);
                        return NailDesignCard(
                          design: design,
                          isFavorited: design.isFavorited,
                          matchPercentage: matchPct,
                          onFavoriteToggle: (isFavorited) =>
                              _toggleFavorite(context, design, isFavorited),
                          onTap: () =>
                              context.go('/nails/${design.nailDesignId}'),
                        );
                      },
                    ),
                  );
                }(),

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

  Future<void> _openFilters(
    BuildContext context,
    NailCatalogState state,
  ) async {
    final filters = await showModalBottomSheet<NailFilters>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (_) => NailFilterSheet(
        initialFilters: state.filters,
        categoryTypes: state.categoryTypes,
      ),
    );
    if (filters != null && context.mounted) {
      await context.read<NailCatalogCubit>().applyFilters(filters);
    }
  }

  Future<void> _toggleFavorite(
    BuildContext context,
    NailDesignModel design,
    bool isFavorited,
  ) async {
    AuthGuard.check(context, () {
      _toggleFavoriteAfterAuth(context, design, isFavorited);
    });
  }

  Future<void> _toggleFavoriteAfterAuth(
    BuildContext context,
    NailDesignModel design,
    bool isFavorited,
  ) async {
    final cubit = context.read<NailCatalogCubit>();
    final previousFavoriteNailId = design.favoriteNailId;
    cubit.updateFavoriteDesign(
      nailDesignId: design.nailDesignId,
      isFavorited: isFavorited,
      favoriteNailId: previousFavoriteNailId,
    );
    try {
      if (isFavorited) {
        final favoriteNailId = await getIt<FavoriteNailRepository>()
            .favoriteDesign(design.nailDesignId);
        cubit.updateFavoriteDesign(
          nailDesignId: design.nailDesignId,
          isFavorited: true,
          favoriteNailId: favoriteNailId,
        );
      } else {
        if (previousFavoriteNailId == null) {
          throw StateError('Missing favoriteNailId');
        }
        await getIt<FavoriteNailRepository>().unfavorite(
          previousFavoriteNailId,
        );
        cubit.updateFavoriteDesign(
          nailDesignId: design.nailDesignId,
          isFavorited: false,
        );
      }
    } catch (error) {
      cubit.updateFavoriteDesign(
        nailDesignId: design.nailDesignId,
        isFavorited: design.isFavorited,
        favoriteNailId: previousFavoriteNailId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Khong the cap nhat yeu thich: $error')),
        );
      }
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
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      ),
    );
  }
}
