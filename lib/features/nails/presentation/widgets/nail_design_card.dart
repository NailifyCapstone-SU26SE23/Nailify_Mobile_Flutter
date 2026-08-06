import 'package:flutter/material.dart';

import '../../data/models/nail_design_model.dart';
import '../../../../core/utils/price_formatter.dart';

class NailDesignCard extends StatefulWidget {
  final NailDesignModel design;
  final VoidCallback onTap;
  final int? matchPercentage;

  /// Current favorite state, controlled by the parent (e.g. from the design
  /// model or a favorites cubit). Defaults to false if not provided.
  final bool isFavorited;

  /// Called when the user taps the heart icon. Parent is responsible for
  /// persisting the change (API call / cubit update) and passing the new
  /// value back down via [isFavorited].
  final ValueChanged<bool>? onFavoriteToggle;

  const NailDesignCard({
    super.key,
    required this.design,
    required this.onTap,
    this.matchPercentage,
    this.isFavorited = false,
    this.onFavoriteToggle,
  });

  @override
  State<NailDesignCard> createState() => _NailDesignCardState();
}

class _NailDesignCardState extends State<NailDesignCard> {
  double _scale = 1.0;
  late bool _isFavorited;

  @override
  void initState() {
    super.initState();
    _isFavorited = widget.isFavorited || widget.design.isFavorited;
  }

  @override
  void didUpdateWidget(covariant NailDesignCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isFavorited != widget.isFavorited ||
        oldWidget.design.isFavorited != widget.design.isFavorited) {
      _isFavorited = widget.isFavorited || widget.design.isFavorited;
    }
  }

  void _handleTapDown(TapDownDetails _) => setState(() => _scale = 0.97);
  void _handleTapUp(TapUpDetails _) => setState(() => _scale = 1.0);
  void _handleTapCancel() => setState(() => _scale = 1.0);

  void _toggleFavorite() {
    if (widget.onFavoriteToggle == null) return;
    widget.onFavoriteToggle!.call(!_isFavorited);
  }

  @override
  Widget build(BuildContext context) {
    final design = widget.design;

    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFFFFF0F5), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.05),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // --- Ảnh chính ---
                    ClipRRect(
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(18),
                      ),
                      child: design.primaryImageUrl.isEmpty
                          ? Container(
                              color: const Color(0xFFF5F5F7),
                              alignment: Alignment.center,
                              child: const Icon(
                                Icons.spa_rounded,
                                size: 36,
                                color: Colors.grey,
                              ),
                            )
                          : Hero(
                              tag: 'nail_image_${design.nailDesignId}',
                              child: Image.network(
                                design.primaryImageUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, progress) {
                                  if (progress == null) return child;
                                  return Container(
                                    color: const Color(0xFFF5F5F7),
                                    alignment: Alignment.center,
                                    child: const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Color(0xFFFF4081),
                                      ),
                                    ),
                                  );
                                },
                                errorBuilder: (_, _, _) => Container(
                                  color: const Color(0xFFF5F5F7),
                                  alignment: Alignment.center,
                                  child: const Icon(
                                    Icons.broken_image_rounded,
                                    color: Colors.grey,
                                  ),
                                ),
                              ),
                            ),
                    ),

                    // --- Gradient overlay để badge/tim luôn dễ đọc ---
                    Positioned.fill(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withValues(alpha: 0.18),
                              Colors.transparent,
                            ],
                            stops: const [0.0, 0.35],
                          ),
                        ),
                      ),
                    ),

                    // --- Nút yêu thích (toggle thật) ---
                    Positioned(
                      top: 10,
                      right: 10,
                      child: GestureDetector(
                        onTap: _toggleFavorite,
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(
                            begin: 1.0,
                            end: _isFavorited ? 1.15 : 1.0,
                          ),
                          duration: const Duration(milliseconds: 180),
                          curve: Curves.elasticOut,
                          builder: (context, scale, child) {
                            return Transform.scale(scale: scale, child: child);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.92),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isFavorited
                                  ? Icons.favorite_rounded
                                  : Icons.favorite_border_rounded,
                              size: 18,
                              color: _isFavorited
                                  ? const Color(0xFFFF4081)
                                  : Colors.grey.shade400,
                            ),
                          ),
                        ),
                      ),
                    ),

                    // --- Badge % phù hợp (gradient pill) ---
                    if (widget.matchPercentage != null)
                      Positioned(
                        top: 10,
                        left: 10,
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
                                color: const Color(
                                  0xFFFF66C4,
                                ).withValues(alpha: 0.35),
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
                  ],
                ),
              ),

              // --- Thông tin bên dưới ảnh ---
              Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      design.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                        fontFamily: 'Georgia',
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${design.nailVariants.length} phiên bản',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade500,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      design.minPrice == design.maxPrice
                          ? PriceFormatter.format(
                              design.minPrice,
                            ).replaceAll(' VNĐ', 'đ')
                          : '${PriceFormatter.format(design.minPrice).replaceAll(' VNĐ', '')} - ${PriceFormatter.format(design.maxPrice).replaceAll(' VNĐ', 'đ')}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFFFF4081),
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
