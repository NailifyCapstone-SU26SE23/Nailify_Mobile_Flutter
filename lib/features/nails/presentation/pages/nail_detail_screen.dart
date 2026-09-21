import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../generated/l10n.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../data/models/category_model.dart';
import '../../data/models/nail_design_model.dart';
import '../../data/models/nail_variant_model.dart';
import '../../data/repositories/favorite_nail_repository.dart';
import '../../data/repositories/nail_design_repository.dart';

class NailDetailScreen extends StatefulWidget {
  final int nailDesignId;

  const NailDetailScreen({super.key, required this.nailDesignId});

  @override
  State<NailDetailScreen> createState() => _NailDetailScreenState();
}

class _NailDetailScreenState extends State<NailDetailScreen> {
  late Future<NailDesignModel> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<NailDesignRepository>().getNailDesignById(
      widget.nailDesignId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<NailDesignModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const NailDetailSkeleton();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(
                title: Text(S.of(context).nailDetailsTitle),
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => context.pop(),
                ),
              ),
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot.error?.toString() ??
                            S.of(context).nailDetailsError,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary),
                      ),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        onPressed: () => setState(() {
                          _future = getIt<NailDesignRepository>()
                              .getNailDesignById(widget.nailDesignId);
                        }),
                        icon: const Icon(Icons.refresh),
                        label: Text(S.of(context).retryBtn),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
          final design = snapshot.data!;
          return _DesignDetailContent(design: design);
        },
      ),
    );
  }
}

class _DesignDetailContent extends StatefulWidget {
  final NailDesignModel design;

  const _DesignDetailContent({required this.design});

  @override
  State<_DesignDetailContent> createState() => _DesignDetailContentState();
}

class _DesignDetailContentState extends State<_DesignDetailContent> {
  final _scrollController = ScrollController();
  late NailDesignModel _design;

  int _visibleVariantsCount = 3;

  @override
  void initState() {
    super.initState();
    _design = widget.design;
  }

  @override
  void didUpdateWidget(covariant _DesignDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.design.nailDesignId != widget.design.nailDesignId) {
      _design = widget.design;
    }
  }

  Future<void> _toggleFavorite() async {
    AuthGuard.check(context, () {
      _toggleFavoriteAfterAuth();
    });
  }

  Future<void> _toggleFavoriteAfterAuth() async {
    final previousDesign = _design;
    final shouldFavorite = !_design.isFavorited;
    setState(() {
      _design = _design.copyWith(
        isFavorited: shouldFavorite,
        clearFavoriteNailId: !shouldFavorite,
      );
    });
    try {
      if (shouldFavorite) {
        final favoriteNailId = await getIt<FavoriteNailRepository>()
            .favoriteDesign(_design.nailDesignId);
        if (mounted) {
          setState(() {
            _design = _design.copyWith(
              isFavorited: true,
              favoriteNailId: favoriteNailId,
            );
          });
        }
      } else {
        final favoriteNailId = previousDesign.favoriteNailId;
        if (favoriteNailId == null) throw StateError('Missing favoriteNailId');
        await getIt<FavoriteNailRepository>().unfavorite(favoriteNailId);
        if (mounted) {
          setState(() {
            _design = _design.copyWith(
              isFavorited: false,
              clearFavoriteNailId: true,
            );
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() => _design = previousDesign);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Khong the cap nhat yeu thich: $error')),
        );
      }
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToVariants() {
    if (_scrollController.hasClients) {
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final design = _design;

    return Stack(
      children: [
        // 1. Scrollable body content
        SingleChildScrollView(
          controller: _scrollController,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image slider gallery
              _ImageGallery(
                nailDesignId: design.nailDesignId,
                imageUrls: design.imageUrls,
              ),

              // White card contents overlapping slightly on top of the image
              Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    24,
                    20,
                    130,
                  ), // generous bottom padding to prevent bottom bar overlapping
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title (Design Name)
                      Text(
                        design.name,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontFamily: 'Georgia',
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Subtitle categories (Luxury Badges)
                      _buildCategoryBadges(context, design.categories),
                      const SizedBox(height: 24),
                      // Introduction header & card
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            S.of(context).introduction,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontFamily: 'Georgia',
                              letterSpacing: -0.5,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAFAFD),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFF2ECF3)),
                        ),
                        child: Text(
                          design.description.isEmpty
                              ? S.of(context).nailDescriptionDefault
                              : design.description,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade800,
                            height: 1.6,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Variants section
                      Row(
                        children: [
                          Container(
                            width: 4,
                            height: 18,
                            decoration: BoxDecoration(
                              color: AppColors.primary,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            S.of(context).availableVariants,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                              fontFamily: 'Georgia',
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFF0F6), Color(0xFFFFECF4)],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.2),
                              ),
                            ),
                            child: Text(
                              '${design.nailVariants.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      if (design.nailVariants.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              S.of(context).noVariantsAvailable,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                        )
                      else ...[
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: design.nailVariants.length.clamp(0, _visibleVariantsCount),
                          itemBuilder: (context, index) {
                            return _VariantSection(
                              variant: design.nailVariants[index],
                              designName: design.name,
                            );
                          },
                        ),
                        if (design.nailVariants.length > _visibleVariantsCount) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton.icon(
                              onPressed: () {
                                setState(() {
                                  _visibleVariantsCount += 5;
                                });
                              },
                              style: OutlinedButton.styleFrom(
                                backgroundColor: const Color(0xFFF4F4F6),
                                foregroundColor: AppColors.textPrimary,
                                side: BorderSide.none,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(Icons.expand_more_rounded, size: 20),
                              label: Text(
                                Localizations.localeOf(context).languageCode == 'vi'
                                    ? 'Xem thêm biến thể móng (${design.nailVariants.length - _visibleVariantsCount})'
                                    : 'Load More Related Variants (${design.nailVariants.length - _visibleVariantsCount})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Overlaid top buttons (Back, Share, Favorite)
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Back Button
              GestureDetector(
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/nails');
                  }
                },
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  radius: 20,
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    size: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
              // Action Buttons
              GestureDetector(
                onTap: _toggleFavorite,
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  radius: 20,
                  child: Icon(
                    design.isFavorited
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    size: 20,
                    color: design.isFavorited
                        ? Colors.redAccent
                        : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Floating Sticky Bottom Bar
        Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.12),
                  blurRadius: 20,
                  spreadRadius: 2,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: const Color(0xFFFFF0F5),
                width: 1.5,
              ),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S
                            .of(context)
                            .variantsCount(
                              design.nailVariants.length.toString(),
                            ),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        S.of(context).availableForTryOn,
                        style: const TextStyle(
                          fontSize: 11,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    height: 44,
                    child: ElevatedButton(
                      onPressed: _scrollToVariants,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 26),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: Text(
                        S.of(context).bookNow,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBadges(
    BuildContext context,
    List<CategoryModel> categories,
  ) {
    if (categories.isEmpty) {
      return Text(
        S.of(context).nailDesignFallback,
        style: TextStyle(
          fontSize: 13,
          color: Colors.grey.shade500,
          fontWeight: FontWeight.w500,
        ),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories.map((c) {
        final badgeStyle = _getCategoryBadgeStyle(c.categoryTypeName, c.name);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 7),
          decoration: BoxDecoration(
            gradient: badgeStyle.bgGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: badgeStyle.borderColor,
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: badgeStyle.textColor.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: badgeStyle.iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  badgeStyle.icon,
                  size: 12,
                  color: badgeStyle.iconColor,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                c.name,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: badgeStyle.textColor,
                  letterSpacing: 0.2,
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  _BadgeStyle _getCategoryBadgeStyle(String typeName, String categoryName) {
    final type = typeName.toLowerCase();
    final name = categoryName.toLowerCase();

    if (type.contains('shape') ||
        type.contains('form') ||
        name.contains('hạnh nhân') ||
        name.contains('dáng') ||
        name.contains('móng')) {
      return const _BadgeStyle(
        bgGradient: LinearGradient(colors: [Color(0xFFEFF6FF), Color(0xFFDBEAFE)]),
        borderColor: Color(0xFFBFDBFE),
        textColor: Color(0xFF1E40AF),
        iconColor: Color(0xFF2563EB),
        iconBgColor: Color(0xFFDBEAFE),
        icon: Icons.gesture_rounded,
      );
    }
    if (type.contains('surface') ||
        name.contains('sơn') ||
        name.contains('mờ') ||
        name.contains('bóng') ||
        name.contains('tráng')) {
      return const _BadgeStyle(
        bgGradient: LinearGradient(colors: [Color(0xFFFFF7ED), Color(0xFFFFEDD5)]),
        borderColor: Color(0xFFFED7AA),
        textColor: Color(0xFFC2410C),
        iconColor: Color(0xFFEA580C),
        iconBgColor: Color(0xFFFFEDD5),
        icon: Icons.layers_rounded,
      );
    }
    if (type.contains('season') ||
        type.contains('mùa') ||
        name.contains('thu') ||
        name.contains('hạ') ||
        name.contains('đông') ||
        name.contains('xuân')) {
      return const _BadgeStyle(
        bgGradient: LinearGradient(colors: [Color(0xFFFEFCE8), Color(0xFFFEF08A)]),
        borderColor: Color(0xFFFDE047),
        textColor: Color(0xFFA16207),
        iconColor: Color(0xFFCA8A04),
        iconBgColor: Color(0xFFFEF9C3),
        icon: Icons.wb_sunny_rounded,
      );
    }
    if (type.contains('skin') || name.contains('da') || name.contains('tông')) {
      return const _BadgeStyle(
        bgGradient: LinearGradient(colors: [Color(0xFFFAF5FF), Color(0xFFF3E8FF)]),
        borderColor: Color(0xFFE9D5FF),
        textColor: Color(0xFF7E22CE),
        iconColor: Color(0xFF9333EA),
        iconBgColor: Color(0xFFF3E8FF),
        icon: Icons.face_retouching_natural_rounded,
      );
    }
    if (type.contains('occasion') ||
        name.contains('dịp') ||
        name.contains('văn phòng') ||
        name.contains('tiệc')) {
      return const _BadgeStyle(
        bgGradient: LinearGradient(colors: [Color(0xFFF0FDF4), Color(0xFFDCFCE7)]),
        borderColor: Color(0xFFBBF7D0),
        textColor: Color(0xFF15803D),
        iconColor: Color(0xFF16A34A),
        iconBgColor: Color(0xFFDCFCE7),
        icon: Icons.celebration_rounded,
      );
    }
    return const _BadgeStyle(
      bgGradient: LinearGradient(colors: [Color(0xFFFFF0F6), Color(0xFFFFECF4)]),
      borderColor: Color(0xFFFFC0E0),
      textColor: Color(0xFFC2185B),
      iconColor: Color(0xFFE91E63),
      iconBgColor: Color(0xFFFFE0F0),
      icon: Icons.palette_rounded,
    );
  }
}

class _ImageGallery extends StatefulWidget {
  final int nailDesignId;
  final List<String> imageUrls;

  const _ImageGallery({required this.nailDesignId, required this.imageUrls});

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return Container(
        height: 350,
        color: const Color(0xFFF5F5F7),
        alignment: Alignment.center,
        child: const Icon(Icons.spa_rounded, size: 64, color: Colors.grey),
      );
    }

    return Stack(
      children: [
        SizedBox(
          height: 350,
          width: double.infinity,
          child: PageView.builder(
            itemCount: widget.imageUrls.length,
            onPageChanged: (index) {
              setState(() => _currentIndex = index);
            },
            itemBuilder: (context, index) {
              return Hero(
                tag: index == 0
                    ? 'detail_nail_image_${widget.nailDesignId}'
                    : 'detail_nail_image_${widget.nailDesignId}_$index',
                child: Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
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
        // Image index counter pill (e.g. "1/4")
        Positioned(
          bottom: 40,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_currentIndex + 1}/${widget.imageUrls.length}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeStyle {
  final LinearGradient bgGradient;
  final Color borderColor;
  final Color textColor;
  final Color iconColor;
  final Color iconBgColor;
  final IconData icon;

  const _BadgeStyle({
    required this.bgGradient,
    required this.borderColor,
    required this.textColor,
    required this.iconColor,
    required this.iconBgColor,
    required this.icon,
  });
}

class _VariantSection extends StatelessWidget {
  final NailVariantModel variant;
  final String designName;

  const _VariantSection({required this.variant, required this.designName});

  String _formatDuration(BuildContext context, int? mins) {
    return DurationFormatter.format(mins, context: context);
  }

  @override
  Widget build(BuildContext context) {
    final durationText = _formatDuration(context, variant.duration);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFF4EBF2), width: 1.3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            spreadRadius: 0,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: () => context.push(
          '/nail-variants/${variant.nailVariantId}',
          extra: {'designName': designName},
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Part: Product Thumbnail + Title + Specs
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Product image (88x88)
                  Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFF0E5EC)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(17),
                      child: variant.imageUrl.isEmpty
                          ? Container(
                              color: const Color(0xFFFFF0F5),
                              child: const Icon(
                                Icons.spa_rounded,
                                color: AppColors.primary,
                                size: 32,
                              ),
                            )
                          : Image.network(
                              variant.imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                color: const Color(0xFFF5F5F7),
                                child: const Icon(
                                  Icons.broken_image_rounded,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  // Title + Attribute Tags
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          variant.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Georgia',
                            color: AppColors.textPrimary,
                            height: 1.25,
                            letterSpacing: -0.2,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            if (variant.nailShape != null)
                              _buildMiniChip(
                                Icons.gesture_rounded,
                                variant.nailShape!.name,
                                const Color(0xFFEFF6FF),
                                const Color(0xFF1D4ED8),
                              ),
                            if (variant.nailSurface != null)
                              _buildMiniChip(
                                Icons.layers_rounded,
                                variant.nailSurface!.name,
                                const Color(0xFFFFF7ED),
                                const Color(0xFFC2410C),
                              ),
                            if (durationText.isNotEmpty)
                              _buildMiniChip(
                                Icons.access_time_rounded,
                                durationText,
                                const Color(0xFFF0FDF4),
                                const Color(0xFF15803D),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // Thin Separator Line
              Container(
                height: 1,
                color: const Color(0xFFF4ECF2),
              ),
              const SizedBox(height: 10),
              // Bottom Action Bar: Price + CTA Button
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Giá dịch vụ',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        PriceFormatter.format(variant.price),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 9,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF66C4), Color(0xFFFF4081)],
                      ),
                      borderRadius: BorderRadius.circular(22),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.32),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          S.of(context).bookBtn,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.white,
                          size: 11,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMiniChip(
    IconData icon,
    String text,
    Color bgColor,
    Color textColor,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: textColor),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ],
      ),
    );
  }
}

class NailDetailSkeleton extends StatelessWidget {
  const NailDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SkeletonBox(
                width: double.infinity,
                height: 350,
                borderRadius: BorderRadius.zero,
              ),
              Transform.translate(
                offset: const Offset(0, -28),
                child: Container(
                  width: double.infinity,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(28),
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SkeletonBox(width: 220, height: 28),
                      const SizedBox(height: 10),
                      const SkeletonBox(width: 140, height: 16),
                      const SizedBox(height: 12),
                      const SkeletonBox(width: 200, height: 16),
                      const SizedBox(height: 20),
                      const SkeletonBox(
                        width: double.infinity,
                        height: 50,
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      const SizedBox(height: 24),
                      const SkeletonBox(width: 100, height: 22),
                      const SizedBox(height: 12),
                      const SkeletonBox(
                        width: double.infinity,
                        height: 72,
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      const SizedBox(height: 28),
                      const SkeletonBox(width: 150, height: 22),
                      const SizedBox(height: 16),
                      const SkeletonBox(
                        width: double.infinity,
                        height: 96,
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                      const SizedBox(height: 12),
                      const SkeletonBox(
                        width: double.infinity,
                        height: 96,
                        borderRadius: BorderRadius.all(Radius.circular(20)),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: MediaQuery.paddingOf(context).top + 12,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                radius: 20,
                child: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 18,
                  color: Colors.black87,
                ),
              ),
              CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                radius: 20,
                child: const Icon(
                  Icons.favorite_outline_rounded,
                  size: 18,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ),
      ],
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
