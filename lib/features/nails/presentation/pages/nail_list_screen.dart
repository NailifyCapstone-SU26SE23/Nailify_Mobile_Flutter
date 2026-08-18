import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../data/repositories/nail_design_repository.dart';
import '../../data/repositories/nail_variant_repository.dart';
import '../../data/models/nail_design_model.dart';
import '../../data/models/nail_filters.dart';
import '../cubit/nail_catalog_cubit.dart';
import '../widgets/nail_collection_section.dart';
import '../widgets/nail_filter_sheet.dart';
import '../widgets/banner.dart';
import '../../../quiz/data/models/quiz_result_model.dart';
import '../../../../generated/l10n.dart';

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
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Đồng bộ từ khoá tìm kiếm từ Cubit State (nếu có)
    final currentFilters = context.read<NailCatalogCubit>().state.filters;
    if (currentFilters.name != null) {
      _searchController.text = currentFilters.name!;
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 500) {
      context.read<NailCatalogCubit>().loadMore();
    }
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      final cubit = context.read<NailCatalogCubit>();
      final newFilters = NailFilters(
        name: query.trim().isEmpty ? null : query.trim(),
        categoryIds: cubit.state.filters.categoryIds,
        shapeId: cubit.state.filters.shapeId,
        surfaceId: cubit.state.filters.surfaceId,
        minPrice: cubit.state.filters.minPrice,
        maxPrice: cubit.state.filters.maxPrice,
      );
      cubit.applyFilters(newFilters);
      setState(() {}); // Để cập nhật nút xóa clear search icon
    });
  }

  // Highest matching score percentage for a given nail design, or null
  // if the design was not part of the quiz result set.
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

  // Groups the flat design list into named collections for the
  // Netflix-style layout.
  //
  // NOTE: this assumes `NailDesignModel` exposes a `categoryName` field
  // (or similar). Adjust `_categoryOf` below to match your actual model
  // if the field is named differently (e.g. `category.name`, `categoryTypeName`).
  String _categoryOf(NailDesignModel design, BuildContext context) {
    final dynamic d = design;
    try {
      final value = (d.categoryName ?? d.category?.name) as String?;
      if (value != null && value.trim().isNotEmpty) return value;
    } catch (_) {
      // Field doesn't exist on the model — falls through to default.
    }
    return S.of(context).recommended;
  }

  Map<String, List<NailDesignModel>> _groupByCategory(
    List<NailDesignModel> designs,
    BuildContext context,
  ) {
    final map = <String, List<NailDesignModel>>{};
    for (final design in designs) {
      final key = _categoryOf(design, context);
      map.putIfAbsent(key, () => []).add(design);
    }
    return map;
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
                      Expanded(
                        child: Text(
                          S.of(context).nailDesignTitle,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                            fontFamily: 'Georgia',
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

              // Thanh tìm kiếm thiết kế móng
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: const Color(0xFFFF4081).withValues(alpha: 0.12),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFFFF4081).withValues(alpha: 0.03),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: TextField(
                      controller: _searchController,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
                      decoration: InputDecoration(
                        hintText: S.of(context).searchNailHint,
                        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 14),
                        prefixIcon: const Icon(Icons.search_rounded, color: Color(0xFFFF4081), size: 20),
                        suffixIcon: _searchController.text.isNotEmpty
                            ? GestureDetector(
                                onTap: () {
                                  _searchController.clear();
                                  _onSearchChanged('');
                                },
                                child: const Icon(Icons.clear_rounded, color: Colors.grey, size: 20),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                      onChanged: _onSearchChanged,
                    ),
                  ),
                ),
              ),

              // Banner bộ lọc đang hoạt động
              if (state.filters.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4081).withValues(alpha: 0.02),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: const Color(0xFFFF4081).withValues(alpha: 0.08),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 16,
                            color: Color(0xFFFF4081),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _getFilterActiveText(context, state),
                              style: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Georgia',
                                color: Color(0xFFC44569),
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              context.read<NailCatalogCubit>().applyFilters(const NailFilters());
                              setState(() {});
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFF4081).withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    S.of(context).clearFilter,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFFFF4081),
                                    ),
                                  ),
                                  SizedBox(width: 2),
                                  Icon(
                                    Icons.close_rounded,
                                    size: 12,
                                    color: Color(0xFFFF4081),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SliverToBoxAdapter(child: QuizBanner()),

              // Trạng thái Loading / Error / Empty / Hiện các bộ sưu tập hoặc Grid kết quả lọc
              if (state.status == NailCatalogStatus.loading)
                if (state.filters.isNotEmpty)
                  _buildFilteredListSkeleton()
                else
                  _buildCollectionsSkeleton()
              else if (state.status == NailCatalogStatus.error &&
                  state.designs.isEmpty)
                SliverFillRemaining(
                  child: _ErrorState(
                    message:
                        state.errorMessage ?? S.of(context).nailLoadError,
                    onRetry: () =>
                        context.read<NailCatalogCubit>().loadDesigns(),
                  ),
                )
              else if (state.designs.isEmpty)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      S.of(context).noNailFound,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else if (state.filters.isNotEmpty)
                _buildFilteredGrid(context, state)
              else
                ..._buildCollectionSlivers(context, state),

              // Loading thêm khi cuộn
              if (state.status == NailCatalogStatus.loadingMore)
                const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.all(18),
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),

              const SliverToBoxAdapter(child: SizedBox(height: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFilteredGrid(BuildContext context, NailCatalogState state) {
    final hasMatch = widget.matchedResults != null && widget.matchedResults!.isNotEmpty;
    
    final matchLookup = <int, int>{};
    if (hasMatch) {
      for (final design in state.designs) {
        final pct = _getMatchPercentage(design);
        if (pct != null) matchLookup[design.nailDesignId] = pct;
      }
    }

    final designsToDisplay = state.designs;

    if (designsToDisplay.isEmpty) {
      return SliverFillRemaining(
        child: Center(
          child: Text(
            S.of(context).noNailFound,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      sliver: SliverList.builder(
        itemCount: designsToDisplay.length,
        itemBuilder: (context, index) {
          final design = designsToDisplay[index];
          final matchPct = matchLookup[design.nailDesignId];
          return NailDesignFullWidthCard(
            design: design,
            matchPercentage: matchPct,
            onTap: () => context.go('/nails/${design.nailDesignId}'),
          );
        },
      ),
    );
  }

  Widget _buildCollectionsSkeleton() {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, sectionIndex) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonBox(width: 140, height: 22, borderRadius: BorderRadius.all(Radius.circular(6))),
                      SkeletonBox(width: 80, height: 20, borderRadius: BorderRadius.all(Radius.circular(10))),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 250,
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    scrollDirection: Axis.horizontal,
                    itemCount: 4,
                    separatorBuilder: (context, index) =>
                        const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      return SizedBox(
                        width: 150,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SkeletonBox(
                              width: 150,
                              height: 160,
                              borderRadius: BorderRadius.all(Radius.circular(16)),
                            ),
                            const SizedBox(height: 10),
                            const SkeletonBox(
                              width: 120,
                              height: 16,
                            ),
                            const SizedBox(height: 6),
                            const SkeletonBox(
                              width: 80,
                              height: 12,
                            ),
                            const SizedBox(height: 6),
                            const SkeletonBox(
                              width: 100,
                              height: 14,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          );
        },
        childCount: 3,
      ),
    );
  }

  Widget _buildFilteredListSkeleton() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SkeletonBox(
                    width: double.infinity,
                    height: 200,
                    borderRadius: BorderRadius.all(Radius.circular(16)),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: const [
                      SkeletonBox(width: 180, height: 18),
                      SkeletonBox(width: 45, height: 14),
                    ],
                  ),
                  const SizedBox(height: 6),
                  const SkeletonBox(width: 150, height: 13),
                  const SizedBox(height: 4),
                  const SkeletonBox(width: 240, height: 13),
                ],
              ),
            );
          },
          childCount: 3,
        ),
      ),
    );
  }

  List<Widget> _buildCollectionSlivers(
    BuildContext context,
    NailCatalogState state,
  ) {
    final hasMatch =
        widget.matchedResults != null && widget.matchedResults!.isNotEmpty;

    // Build a lookup of matchPercentage per design id, computed once.
    final matchLookup = <int, int>{};
    if (hasMatch) {
      for (final design in state.designs) {
        final pct = _getMatchPercentage(design);
        if (pct != null) matchLookup[design.nailDesignId] = pct;
      }
    }

    final sections = <Widget>[];

    // 1. "Dành riêng cho bạn" — top matches from the quiz, sorted descending.
    if (hasMatch) {
      final matchedDesigns = state.designs
          .where((d) => matchLookup.containsKey(d.nailDesignId))
          .toList()
        ..sort(
          (a, b) => matchLookup[b.nailDesignId]!.compareTo(
            matchLookup[a.nailDesignId]!,
          ),
        );

      if (matchedDesigns.isNotEmpty) {
        sections.add(
          SliverToBoxAdapter(
            child: NailCollectionSection(
              title: S.of(context).forYouTitle,
              titleIcon: Icons.auto_awesome_rounded,
              designs: matchedDesigns,
              matchPercentages: matchLookup,
              onDesignTap: (design) =>
                  context.go('/nails/${design.nailDesignId}'),
            ),
          ),
        );
      }
    }

    // 1.5. "Theo mùa" (Seasonal theme section)
    final seasonalDesigns = state.designs.where((d) {
      return d.categories.any((c) {
        final typeName = c.categoryTypeName.toLowerCase();
        return typeName == 'theme' || typeName == 'season' || typeName == 'mùa';
      });
    }).toList();

    if (seasonalDesigns.isNotEmpty) {
      sections.add(
        SliverToBoxAdapter(
          child: NailCollectionSection(
            title: S.of(context).seasonalTitle,
            titleIcon: Icons.wb_sunny_rounded,
            designs: seasonalDesigns,
            onDesignTap: (design) =>
                context.go('/nails/${design.nailDesignId}'),
            onSeeAll: () {
              _applyCategoryTypeFilter(
                context,
                state,
                (name) =>
                    name == 'theme' || name == 'season' || name == 'mùa',
              );
              setState(() {});
            },
          ),
        ),
      );
    }

    final isVi = Localizations.localeOf(context).languageCode == 'vi';

    // 1.6. "Theo phong cách" (Style section)
    final styleDesigns = state.designs.where((d) {
      return d.categories.any((c) {
        final typeName = c.categoryTypeName.toLowerCase();
        return typeName == 'style' || typeName == 'phong cách' || typeName == 'phongcach';
      });
    }).toList();

    if (styleDesigns.isNotEmpty) {
      sections.add(
        SliverToBoxAdapter(
          child: NailCollectionSection(
            title: isVi ? 'Theo phong cách' : 'By Style',
            titleIcon: Icons.palette_rounded,
            designs: styleDesigns,
            onDesignTap: (design) =>
                context.go('/nails/${design.nailDesignId}'),
            onSeeAll: () {
              _applyCategoryTypeFilter(
                context,
                state,
                (name) =>
                    name == 'style' ||
                    name == 'phong cách' ||
                    name == 'phongcach',
              );
              setState(() {});
            },
          ),
        ),
      );
    }

    // 1.7. "Theo tông da" (Skin Tone section)
    final skinToneDesigns = state.designs.where((d) {
      return d.categories.any((c) {
        final typeName = c.categoryTypeName.toLowerCase();
        return typeName == 'skin tone' || typeName == 'skin-tone' || typeName == 'skintone' || typeName == 'tông da' || typeName == 'tongda';
      });
    }).toList();

    if (skinToneDesigns.isNotEmpty) {
      sections.add(
        SliverToBoxAdapter(
          child: NailCollectionSection(
            title: isVi ? 'Theo tông da' : 'By Skin Tone',
            titleIcon: Icons.face_retouching_natural_rounded,
            designs: skinToneDesigns,
            onDesignTap: (design) =>
                context.go('/nails/${design.nailDesignId}'),
            onSeeAll: () {
              _applyCategoryTypeFilter(
                context,
                state,
                (name) =>
                    name == 'skin tone' ||
                    name == 'skin-tone' ||
                    name == 'skintone' ||
                    name == 'tông da' ||
                    name == 'tongda',
              );
              setState(() {});
            },
          ),
        ),
      );
    }

    // 1.8. "Theo dịp" (Occasion section)
    final occasionDesigns = state.designs.where((d) {
      return d.categories.any((c) {
        final typeName = c.categoryTypeName.toLowerCase();
        return typeName == 'occasion' || typeName == 'dịp' || typeName == 'dip';
      });
    }).toList();

    if (occasionDesigns.isNotEmpty) {
      sections.add(
        SliverToBoxAdapter(
          child: NailCollectionSection(
            title: isVi ? 'Theo dịp' : 'By Occasion',
            titleIcon: Icons.celebration_rounded,
            designs: occasionDesigns,
            onDesignTap: (design) =>
                context.go('/nails/${design.nailDesignId}'),
            onSeeAll: () {
              _applyCategoryTypeFilter(
                context,
                state,
                (name) => name == 'occasion' || name == 'dịp' || name == 'dip',
              );
              setState(() {});
            },
          ),
        ),
      );
    }

    // 2. One horizontally-scrolling row per category.
    final grouped = _groupByCategory(state.designs, context);
    for (final entry in grouped.entries) {
      sections.add(
        SliverToBoxAdapter(
          child: NailCollectionSection(
            title: entry.key,
            designs: entry.value,
            onDesignTap: (design) =>
                context.go('/nails/${design.nailDesignId}'),
            onSeeAll: () {
              final match = state.categoryTypes.where((c) => c.name == entry.key);
              if (match.isNotEmpty) {
                context.read<NailCatalogCubit>().applyFilters(
                  NailFilters(
                    categoryIds: match.first.categories
                        .map((category) => category.categoryId)
                        .where((id) => id > 0)
                        .toList(),
                  ),
                );
              } else {
                context.read<NailCatalogCubit>().applyFilters(const NailFilters());
              }
              setState(() {});
            },
          ),
        ),
      );
    }

    return sections;
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
    if (filters == null || !context.mounted) return;
    await context.read<NailCatalogCubit>().applyFilters(filters);
    if (!mounted) return;
    _searchController.text = filters.name ?? '';
    setState(() {});
  }

  void _applyCategoryTypeFilter(
    BuildContext context,
    NailCatalogState state,
    bool Function(String normalizedTypeName) matchesType,
  ) {
    final categoryIds = state.categoryTypes
        .where((type) => matchesType(type.name.toLowerCase().trim()))
        .expand((type) => type.categories)
        .where((category) => category.status.toLowerCase() != 'inactive')
        .map((category) => category.categoryId)
        .where((id) => id > 0)
        .toList();

    context.read<NailCatalogCubit>().applyFilters(
      categoryIds.isEmpty
          ? const NailFilters()
          : NailFilters(categoryIds: categoryIds),
    );
  }

  String _getFilterActiveText(BuildContext context, NailCatalogState state) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final filters = state.filters;
    final parts = <String>[];
    if (filters.name != null && filters.name!.isNotEmpty) {
      parts.add(isVi ? 'từ khoá "${filters.name}"' : 'keyword "${filters.name}"');
    }
    if (filters.categoryIds.isNotEmpty) {
      final catNames = state.categoryTypes
          .expand((type) => type.categories)
          .where((category) => filters.categoryIds.contains(category.categoryId))
          .map((category) => category.name)
          .join(', ');
      if (catNames.isNotEmpty) {
        parts.add(isVi ? 'danh mục "$catNames"' : 'category "$catNames"');
      }
    }
    if (filters.shapeId != null) {
      parts.add(isVi ? 'dáng móng' : 'nail shape');
    }
    if (filters.surfaceId != null) {
      parts.add(isVi ? 'bề mặt' : 'nail surface');
    }
    if (parts.isEmpty) return isVi ? 'Đang áp dụng bộ lọc' : 'Applying filters';
    final joined = parts.join(isVi ? ' và ' : ' and ');
    return isVi ? 'Kết quả lọc theo $joined' : 'Results filtered by $joined';
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

class NailDesignFullWidthCard extends StatefulWidget {
  final NailDesignModel design;
  final int? matchPercentage;
  final VoidCallback onTap;

  const NailDesignFullWidthCard({
    super.key,
    required this.design,
    required this.onTap,
    this.matchPercentage,
  });

  @override
  State<NailDesignFullWidthCard> createState() => _NailDesignFullWidthCardState();
}

class _NailDesignFullWidthCardState extends State<NailDesignFullWidthCard> {
  int _currentImageIndex = 0;
  final _pageController = PageController();

  double _rating = 0.0;
  int _reviewsCount = 0;
  bool _isLoadingRating = true;

  @override
  void initState() {
    super.initState();
    _loadRating();
  }

  @override
  void didUpdateWidget(covariant NailDesignFullWidthCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.design.nailDesignId != widget.design.nailDesignId) {
      _loadRating();
    }
  }

  Future<void> _loadRating() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRating = true;
    });

    final variantIds = widget.design.nailVariants.map((v) => v.nailVariantId).toList();
    final stats = await getIt<NailVariantRepository>().getRatingStatsForVariants(variantIds);

    if (mounted) {
      setState(() {
        _rating = stats['rating'] as double;
        _reviewsCount = stats['reviewsCount'] as int;
        _isLoadingRating = false;
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final design = widget.design;
    final ratingStr = _isLoadingRating ? '...' : _rating.toStringAsFixed(1);
    final reviewsCountStr = _isLoadingRating ? '...' : '$_reviewsCount';

    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        color: Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Image PageView with Page indicators
            Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(16),
                  child: SizedBox(
                    height: 200,
                    width: double.infinity,
                    child: design.imageUrls.isEmpty
                        ? Container(
                            color: const Color(0xFFF5F5F7),
                            child: const Icon(
                              Icons.spa_rounded,
                              size: 48,
                              color: Colors.grey,
                            ),
                          )
                        : PageView.builder(
                            controller: _pageController,
                            itemCount: design.imageUrls.length,
                            onPageChanged: (index) {
                              setState(() => _currentImageIndex = index);
                            },
                            itemBuilder: (context, index) {
                              return Hero(
                                tag: index == 0
                                    ? 'nail_image_${design.nailDesignId}'
                                    : 'nail_image_${design.nailDesignId}_$index',
                                child: Image.network(
                                  design.imageUrls[index],
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) =>
                                      Container(
                                    color: const Color(0xFFF5F5F7),
                                    alignment: Alignment.center,
                                    child: const Icon(
                                      Icons.broken_image_rounded,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
                if (widget.matchPercentage != null)
                  Positioned(
                    top: 12,
                    left: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFF66C4), Color(0xFFFFDE59)],
                        ),
                        borderRadius: BorderRadius.circular(30),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFF66C4).withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.auto_awesome_rounded,
                            size: 11,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            '${widget.matchPercentage}% phù hợp',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (design.imageUrls.length > 1)
                  Positioned(
                    bottom: 12,
                    left: 0,
                    right: 0,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(
                        design.imageUrls.length,
                        (index) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: _currentImageIndex == index ? 14 : 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: _currentImageIndex == index
                                ? Colors.white
                                : Colors.white.withValues(alpha: 0.5),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // 2. Info details text matching the provided salon screenshot structure
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    design.name,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      fontFamily: 'Georgia',
                      color: AppColors.textPrimary,
                      letterSpacing: -0.3,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star_rounded,
                      color: Color(0xFFFFB300),
                      size: 18,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      ratingStr,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              design.categories.map((c) => c.name).join(' • '),
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              '${design.nailVariants.length} phiên bản • $reviewsCountStr đánh giá',
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class SkeletonBox extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius? borderRadius;

  const SkeletonBox({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius ?? BorderRadius.circular(8),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFFF5F5F7),
                Color.lerp(
                  const Color(0xFFF5F5F7),
                  const Color(0xFFFF4081).withValues(alpha: 0.08),
                  _controller.value,
                )!,
                const Color(0xFFF5F5F7),
              ],
            ),
          ),
        );
      },
    );
  }
}
