import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../generated/l10n.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../data/models/nail_design_model.dart';
import '../../data/models/nail_variant_model.dart';
import '../../data/repositories/nail_design_repository.dart';
import '../../data/repositories/nail_variant_repository.dart';

class NailDetailScreen extends StatefulWidget {
  final int nailDesignId;

  const NailDetailScreen({super.key, required this.nailDesignId});

  @override
  State<NailDetailScreen> createState() => _NailDetailScreenState();
}

class _NailDetailScreenState extends State<NailDetailScreen> {
  late Future<NailDesignModel> _future;
  bool _isFavorited = false;

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
                        snapshot.error?.toString() ?? S.of(context).nailDetailsError,
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
          return _DesignDetailContent(
            design: design,
            isFavorited: _isFavorited,
            onFavoriteToggle: () {
              setState(() => _isFavorited = !_isFavorited);
            },
          );
        },
      ),
    );
  }
}

class _DesignDetailContent extends StatefulWidget {
  final NailDesignModel design;
  final bool isFavorited;
  final VoidCallback onFavoriteToggle;

  const _DesignDetailContent({
    required this.design,
    required this.isFavorited,
    required this.onFavoriteToggle,
  });

  @override
  State<_DesignDetailContent> createState() => _DesignDetailContentState();
}

class _DesignDetailContentState extends State<_DesignDetailContent> {
  final _scrollController = ScrollController();

  double _rating = 0.0;
  int _reviewsCount = 0;
  bool _isLoadingRating = true;

  @override
  void initState() {
    super.initState();
    _loadRating();
  }

  @override
  void didUpdateWidget(covariant _DesignDetailContent oldWidget) {
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
    final design = widget.design;
    final ratingStr = _isLoadingRating ? '...' : _rating.toStringAsFixed(1);
    final reviewsCountStr = _isLoadingRating ? '...' : '$_reviewsCount';

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
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                  ),
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 100), // padding bottom 100 to avoid sticky bottom bar overlapping
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
                      const SizedBox(height: 6),
                      // Subtitle categories
                      Text(
                        design.categories.isEmpty
                            ? S.of(context).nailDesignFallback
                            : design.categories.map((c) => c.name).join(' • '),
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Rating block
                      Row(
                        children: [
                          const Icon(Icons.star_rounded, color: Color(0xFFFFB300), size: 20),
                          const SizedBox(width: 4),
                          Text(
                            ratingStr,
                            style: const TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '($reviewsCountStr)',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      // Highlight/Info box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFF4081).withValues(alpha: 0.03),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFFFF4081).withValues(alpha: 0.08),
                            width: 1.2,
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.sell_outlined, color: Color(0xFFFF4081), size: 18),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                S.of(context).priceFromTo(
                                  PriceFormatter.format(design.minPrice).replaceAll(' VNĐ', ''),
                                  PriceFormatter.format(design.maxPrice),
                                ),
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFC44569),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Introduction
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
                      const SizedBox(height: 10),
                      Text(
                        design.description.isEmpty
                            ? S.of(context).nailDescriptionDefault
                            : design.description,
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade700,
                          height: 1.6,
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Variants section
                      Row(
                        children: [
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
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFF4081).withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${design.nailVariants.length}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFFFF4081),
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
                              style: const TextStyle(color: AppColors.textSecondary),
                            ),
                          ),
                        )
                      else
                        ListView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          padding: EdgeInsets.zero,
                          itemCount: design.nailVariants.length,
                          itemBuilder: (context, index) {
                            return _VariantSection(
                              variant: design.nailVariants[index],
                              designName: design.name,
                            );
                          },
                        ),
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
                onTap: widget.onFavoriteToggle,
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  radius: 20,
                  child: Icon(
                    widget.isFavorited ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                    size: 20,
                    color: widget.isFavorited ? Colors.redAccent : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Sticky Bottom Bar
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context).variantsCount(design.nailVariants.length.toString()),
                        style: const TextStyle(
                          fontSize: 16,
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
                    height: 48,
                    child: ElevatedButton(
                      onPressed: _scrollToVariants,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 28),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
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
                    ? 'nail_image_${widget.nailDesignId}'
                    : 'nail_image_${widget.nailDesignId}_$index',
                child: Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    color: const Color(0xFFF5F5F7),
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
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

class _VariantSection extends StatelessWidget {
  final NailVariantModel variant;
  final String designName;

  const _VariantSection({required this.variant, required this.designName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFF0F5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFF4081).withValues(alpha: 0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => context.push(
          '/nail-variants/${variant.nailVariantId}',
          extra: {'designName': designName},
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: variant.imageUrl.isEmpty
                      ? Container(
                          color: const Color(0xFFF5F5F7),
                          child: const Icon(
                            Icons.spa_rounded,
                            color: Colors.grey,
                          ),
                        )
                      : Image.network(variant.imageUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      variant.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        fontFamily: 'Georgia',
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
                    if (variant.nailShape != null || variant.nailSurface != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        '${S.of(context).nailShapeLabel}: ${variant.nailShape?.name ?? S.of(context).noneLabel} • ${S.of(context).nailSurfaceLabel}: ${variant.nailSurface?.name ?? S.of(context).noneLabel}',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.grey.shade500,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      PriceFormatter.format(variant.price),
                      style: const TextStyle(
                        color: Color(0xFFFF4081),
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Outlined "Đặt" button like in Image 2
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFFFF4081), width: 1.5),
                ),
                child: Text(
                  S.of(context).bookBtn,
                  style: const TextStyle(
                    color: Color(0xFFFF4081),
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
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
                    borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
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
                      const SkeletonBox(width: double.infinity, height: 50, borderRadius: BorderRadius.all(Radius.circular(16))),
                      const SizedBox(height: 24),
                      const SkeletonBox(width: 100, height: 22),
                      const SizedBox(height: 12),
                      const SkeletonBox(width: double.infinity, height: 72, borderRadius: BorderRadius.all(Radius.circular(12))),
                      const SizedBox(height: 28),
                      const SkeletonBox(width: 150, height: 22),
                      const SizedBox(height: 16),
                      const SkeletonBox(width: double.infinity, height: 96, borderRadius: BorderRadius.all(Radius.circular(20))),
                      const SizedBox(height: 12),
                      const SkeletonBox(width: double.infinity, height: 96, borderRadius: BorderRadius.all(Radius.circular(20))),
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
                child: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: Colors.black87),
              ),
              CircleAvatar(
                backgroundColor: Colors.white.withValues(alpha: 0.9),
                radius: 20,
                child: const Icon(Icons.favorite_outline_rounded, size: 18, color: Colors.black87),
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
