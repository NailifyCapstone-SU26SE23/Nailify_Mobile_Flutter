import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/price_formatter.dart';

import '../../../../core/di/injection.dart';
import '../../data/models/customer_nail_models.dart' as nails_model;
import '../../data/models/nail_component_model.dart';
import '../../data/models/nail_variant_model.dart';
import '../../data/models/shape_method_config_model.dart';
import '../../data/repositories/favorite_nail_repository.dart';
import '../../data/repositories/nail_variant_repository.dart';
import '../widgets/nail_variant_ratings_section.dart';
import '../../services/ar_try_on_service.dart';
import '../../../try-on/models/nail_variant_model.dart' as snapshot_models;
import '../../../../generated/l10n.dart';

class NailVariantDetailScreen extends StatefulWidget {
  final int nailVariantId;
  final String? designName;
  final String? sourceSalonId;
  final String? sourceArtistId;

  const NailVariantDetailScreen({
    super.key,
    required this.nailVariantId,
    this.designName,
    this.sourceSalonId,
    this.sourceArtistId,
  });

  @override
  State<NailVariantDetailScreen> createState() =>
      _NailVariantDetailScreenState();
}

class _NailVariantDetailScreenState extends State<NailVariantDetailScreen> {
  late Future<NailVariantModel> _future;
  bool _launching = false;
  bool _isFavorited = false;
  int? _favoriteNailId;
  bool _favoriteInitialized = false;

  @override
  void initState() {
    super.initState();
    _future = _loadVariant();
  }

  Future<NailVariantModel> _loadVariant() {
    return getIt<NailVariantRepository>().getNailVariantById(
      widget.nailVariantId,
    );
  }

  Future<void> _openTryOn(nails_model.CustomerNailModel customerNail) async {
    setState(() => _launching = true);
    try {
      final service = getIt<ArTryOnService>();
      if (!await service.isAvailable()) {
        throw UnsupportedError(
          'Virtual try-on is not available on this build.',
        );
      }
      await service.launchCustomerLive(customerNail);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'vi'
                  ? 'Lỗi khi mở AR: $e'
                  : 'Error opening AR: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _launching = false);
      }
    }
  }

  Future<void> _openPhotoTryOn(
    nails_model.CustomerNailModel customerNail,
  ) async {
    setState(() => _launching = true);
    try {
      final service = getIt<ArTryOnService>();
      if (!await service.isAvailable()) {
        throw UnsupportedError(
          'Virtual try-on is not available on this build.',
        );
      }

      // Route photo try-on through Snapshot so users can choose camera/gallery
      // before previewing this exact variant.
      if (mounted) {
        context.push(
          '/snapshot-try-on',
          extra: _toSnapshotVariant(customerNail),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              Localizations.localeOf(context).languageCode == 'vi'
                  ? 'Lỗi khi mở AR: $e'
                  : 'Error opening AR: $e',
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _launching = false);
      }
    }
  }

  snapshot_models.NailVariantModel _toSnapshotVariant(
    nails_model.CustomerNailModel nail,
  ) {
    return snapshot_models.NailVariantModel(
      nailVariantId: nail.customerNailId,
      name: nail.name,
      imageUrl: nail.imageUrl,
      colorConfig: snapshot_models.ColorJsonConfig.fromJson(
        nail.customColor ?? '{}',
      ),
      nailShape: snapshot_models.NailShape(
        nailShapeId: nail.nailShapeId ?? nail.nailShape?.nailShapeId ?? 0,
        name: nail.nailShape?.name ?? '',
        imageUrl: nail.nailShape?.imageUrl ?? '',
      ),
      nailSurface: snapshot_models.NailSurface(
        nailSurfaceId:
            nail.nailSurfaceId ?? nail.nailSurface?.nailSurfaceId ?? 0,
        name: nail.nailSurface?.name ?? '',
        shaderParam: nail.nailSurface?.shaderParam ?? '{}',
        lightnessOffset: nail.nailSurface?.lightnessOffset ?? 0,
        saturationOffset: nail.nailSurface?.saturationOffset ?? 0,
        hueOffset: nail.nailSurface?.hueOffset ?? 0,
      ),
      nailComponents: nail.customerNailComponents.map((component) {
        final source = component.component;
        final customerSource = component.customerComponent;
        final config = _decodeComponentConfig(component.configJson);
        return snapshot_models.NailComponentItem(
          nailComponentId: component.customerNailComponentId,
          posX: component.posX,
          posY: component.posY,
          fingerIndex: component.fingerIndex,
          scale: (config['scale'] as num?)?.toDouble() ?? 1.0,
          rotation: (config['rotation'] as num?)?.toDouble() ?? 0.0,
          component: snapshot_models.ComponentDetail(
            componentId:
                component.componentId ??
                component.customerComponentId ??
                component.customerNailComponentId,
            name: source?.name ?? customerSource?.name ?? '',
            imageUrl: source?.imageUrl ?? customerSource?.imageUrl ?? '',
            componentType:
                source?.componentType ?? customerSource?.componentType ?? '',
          ),
        );
      }).toList(),
    );
  }

  Map<String, dynamic> _decodeComponentConfig(String rawConfig) {
    if (rawConfig.trim().isEmpty) return const <String, dynamic>{};
    try {
      final decoded = jsonDecode(rawConfig);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
    } catch (_) {}
    return const <String, dynamic>{};
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: FutureBuilder<NailVariantModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const NailVariantSkeleton();
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Scaffold(
              appBar: AppBar(
                title: Text(S.of(context).variantDetailsTitle),
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded),
                  onPressed: () => context.pop(),
                ),
              ),
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      S.of(context).loadDataError(snapshot.error.toString()),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => setState(() => _future = _loadVariant()),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.refresh),
                      label: Text(S.of(context).retryBtn),
                    ),
                  ],
                ),
              ),
            );
          }
          final variant = snapshot.data!;
          if (!_favoriteInitialized) {
            _isFavorited = variant.isFavorited;
            _favoriteNailId = variant.favoriteNailId;
            _favoriteInitialized = true;
          }
          return _DetailContent(
            variant: variant,
            designName: widget.designName,
            sourceSalonId: widget.sourceSalonId,
            sourceArtistId: widget.sourceArtistId,
            launching: _launching,
            onTryOn: _openTryOn,
            onPhotoTryOn: _openPhotoTryOn,
            isFavorited: _isFavorited,
            onFavoriteToggle: _toggleFavorite,
          );
        },
      ),
    );
  }

  Future<void> _toggleFavorite() async {
    AuthGuard.check(context, () {
      _toggleFavoriteAfterAuth();
    });
  }

  Future<void> _toggleFavoriteAfterAuth() async {
    final previousIsFavorited = _isFavorited;
    final previousFavoriteNailId = _favoriteNailId;
    final shouldFavorite = !_isFavorited;
    setState(() {
      _isFavorited = shouldFavorite;
      if (!shouldFavorite) _favoriteNailId = null;
    });
    try {
      if (shouldFavorite) {
        final favoriteNailId = await getIt<FavoriteNailRepository>()
            .favoriteVariant(widget.nailVariantId);
        if (mounted) {
          setState(() => _favoriteNailId = favoriteNailId);
        }
      } else {
        if (previousFavoriteNailId == null) {
          throw StateError('Missing favoriteNailId');
        }
        await getIt<FavoriteNailRepository>().unfavorite(
          previousFavoriteNailId,
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isFavorited = previousIsFavorited;
          _favoriteNailId = previousFavoriteNailId;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Khong the cap nhat yeu thich: $error')),
        );
      }
    }
  }
}

class _DetailContent extends StatefulWidget {
  final NailVariantModel variant;
  final String? designName;
  final String? sourceSalonId;
  final String? sourceArtistId;
  final bool launching;
  final Future<void> Function(nails_model.CustomerNailModel customerNail)
  onTryOn;
  final Future<void> Function(nails_model.CustomerNailModel customerNail)
  onPhotoTryOn;
  final bool isFavorited;
  final VoidCallback onFavoriteToggle;

  const _DetailContent({
    required this.variant,
    this.designName,
    this.sourceSalonId,
    this.sourceArtistId,
    required this.launching,
    required this.onTryOn,
    required this.onPhotoTryOn,
    required this.isFavorited,
    required this.onFavoriteToggle,
  });

  @override
  State<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends State<_DetailContent> {
  late final Future<List<ShapeMethodConfigModel>> _shapeMethodsFuture;
  ShapeMethodConfigModel? _selectedShapeMethod;
  final ScrollController _scrollController = ScrollController();

  double _rating = 0.0;
  int _reviewsCount = 0;
  bool _isLoadingRating = true;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _shapeMethodsFuture = getIt<NailVariantRepository>()
        .getShapeMethodConfigsByNailShape(widget.variant.nailShapeId);
    _loadRating();
  }

  @override
  void didUpdateWidget(covariant _DetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.variant.nailVariantId != widget.variant.nailVariantId) {
      _loadRating();
    }
  }

  Future<void> _loadRating() async {
    if (!mounted) return;
    setState(() {
      _isLoadingRating = true;
    });

    final stats = await getIt<NailVariantRepository>()
        .getRatingStatsForVariants([widget.variant.nailVariantId]);

    if (mounted) {
      setState(() {
        _rating = stats['rating'] as double;
        _reviewsCount = stats['reviewsCount'] as int;
        _isLoadingRating = false;
      });
    }
  }

  String _formatDurationText(BuildContext context, int? minutes) {
    return DurationFormatter.format(minutes, context: context);
  }

  Map<String, dynamic> _parseColorsWithDetails(
    BuildContext context,
    String? colorJson,
  ) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final fallbackText = isVi ? 'Màu hồng' : 'Pink';
    if (colorJson == null || colorJson.trim().isEmpty) {
      return {'colors': <Color>[], 'colorNames': fallbackText};
    }
    try {
      final decoded = jsonDecode(colorJson);
      final hexStrings = <String>[];
      if (decoded is List) {
        for (final item in decoded) {
          if (item != null) hexStrings.add(item.toString());
        }
      } else if (decoded is Map) {
        final color = decoded['color'] ?? decoded['Color'];
        if (color != null) {
          hexStrings.add(color.toString());
        } else {
          final fingers = decoded['fingers'] ?? decoded['Fingers'];
          if (fingers is List) {
            for (final f in fingers) {
              if (f is Map) {
                final col = f['color'] ?? f['Color'];
                if (col != null) hexStrings.add(col.toString());
              }
            }
          }
        }
      }

      final colors = <Color>[];
      final colorNameSet = <String>{};

      for (final hex in hexStrings.toSet()) {
        final cleanHex = hex.replaceAll('#', '').trim();
        Color? colorObj;
        if (cleanHex.length == 6) {
          colorObj = Color(int.parse('FF$cleanHex', radix: 16));
        } else if (cleanHex.length == 8) {
          colorObj = Color(int.parse(cleanHex, radix: 16));
        }
        if (colorObj != null) {
          colors.add(colorObj);
          colorNameSet.add(_getColorNameText(context, colorObj, cleanHex));
        }
      }
      return {
        'colors': colors,
        'colorNames': colorNameSet.isEmpty
            ? fallbackText
            : colorNameSet.join(', '),
      };
    } catch (_) {
      return {'colors': <Color>[], 'colorNames': fallbackText};
    }
  }

  String _getColorNameText(BuildContext context, Color color, String hexCode) {
    final isVi = Localizations.localeOf(context).languageCode == 'vi';
    final clean = hexCode.toUpperCase().replaceAll('#', '').trim();

    String rawName = '';
    if (clean == 'FFFFFF' || clean == 'FFF') {
      rawName = isVi ? 'Trắng' : 'White';
    } else if (clean == '000000' || clean == '000') {
      rawName = isVi ? 'Đen' : 'Black';
    } else if (clean.startsWith('FF66') ||
        clean.startsWith('FF40') ||
        clean.startsWith('FFC0') ||
        clean.startsWith('FF14')) {
      rawName = isVi ? 'Hồng' : 'Pink';
    } else if (clean.startsWith('FF00') ||
        clean.startsWith('F443') ||
        clean.startsWith('E539')) {
      rawName = isVi ? 'Đỏ' : 'Red';
    } else if (clean.startsWith('0000') ||
        clean.startsWith('2196') ||
        clean.startsWith('1E88')) {
      rawName = isVi ? 'Xanh dương' : 'Blue';
    } else if (clean.startsWith('0080') ||
        clean.startsWith('4CAF') ||
        clean.startsWith('2E7D')) {
      rawName = isVi ? 'Xanh lá' : 'Green';
    } else if (clean.startsWith('FFFF') ||
        clean.startsWith('FFEB') ||
        clean.startsWith('FDD8')) {
      rawName = isVi ? 'Vàng' : 'Yellow';
    } else if (clean.startsWith('8000') ||
        clean.startsWith('9C27') ||
        clean.startsWith('8E24')) {
      rawName = isVi ? 'Tím' : 'Purple';
    } else if (clean.startsWith('FFA5') ||
        clean.startsWith('FF98') ||
        clean.startsWith('FB8C')) {
      rawName = isVi ? 'Cam' : 'Orange';
    } else if (clean.startsWith('8080') ||
        clean.startsWith('9E9E') ||
        clean.startsWith('7575')) {
      rawName = isVi ? 'Xám' : 'Grey';
    } else if (clean.startsWith('A52A') ||
        clean.startsWith('7955') ||
        clean.startsWith('6D4C')) {
      rawName = isVi ? 'Nâu' : 'Brown';
    } else if (clean.startsWith('F5F5') ||
        clean.startsWith('FFF8') ||
        clean.startsWith('FEF9')) {
      rawName = isVi ? 'Kem' : 'Beige';
    } else {
      final hsv = HSVColor.fromColor(color);
      if (hsv.value < 0.15) {
        rawName = isVi ? 'Đen' : 'Black';
      } else if (hsv.value > 0.92 && hsv.saturation < 0.1) {
        rawName = isVi ? 'Trắng' : 'White';
      } else if (hsv.saturation < 0.15) {
        rawName = isVi ? 'Xám' : 'Grey';
      } else {
        final hue = hsv.hue;
        if (hue >= 330 || hue < 15) {
          rawName = isVi ? 'Hồng' : 'Pink';
        } else if (hue >= 15 && hue < 45) {
          rawName = isVi ? 'Cam' : 'Orange';
        } else if (hue >= 45 && hue < 70) {
          rawName = isVi ? 'Vàng' : 'Yellow';
        } else if (hue >= 70 && hue < 165) {
          rawName = isVi ? 'Xanh lá' : 'Green';
        } else if (hue >= 165 && hue < 260) {
          rawName = isVi ? 'Xanh dương' : 'Blue';
        } else if (hue >= 260 && hue < 330) {
          rawName = isVi ? 'Tím' : 'Purple';
        } else {
          rawName = isVi ? 'Hồng' : 'Pink';
        }
      }
    }

    return isVi ? 'Màu $rawName' : rawName;
  }

  @override
  Widget build(BuildContext context) {
    final variant = widget.variant;
    final grouped = <int, List<NailComponentModel>>{};
    for (final component in variant.nailComponents) {
      grouped.putIfAbsent(component.fingerIndex, () => []).add(component);
    }
    final ratingStr = _isLoadingRating ? '...' : _rating.toStringAsFixed(1);
    final reviewsCountStr = _isLoadingRating ? '...' : '$_reviewsCount';

    return Stack(
      children: [
        // 1. Body content
        SingleChildScrollView(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image header
              SizedBox(
                width: double.infinity,
                height: 350,
                child: variant.imageUrl.isEmpty
                    ? Container(
                        color: const Color(0xFFF5F5F7),
                        child: const Icon(
                          Icons.spa_rounded,
                          size: 64,
                          color: AppColors.primary,
                        ),
                      )
                    : Image.network(variant.imageUrl, fit: BoxFit.cover),
              ),

              // Overlapping white card content
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
                      // Name
                      Text(
                        variant.name,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontFamily: 'Georgia',
                          letterSpacing: -0.5,
                        ),
                      ),
                      if (widget.designName != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          S.of(context).collectionLabel(widget.designName!),
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 12),
                      // Reference price
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: PriceFormatter.format(variant.price),
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 22,
                          color: Color(0xFFFF4081),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Rating block (Premium Interactive Pill)
                      Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            if (_scrollController.hasClients) {
                              _scrollController.animateTo(
                                _scrollController.position.maxScrollExtent,
                                duration: const Duration(milliseconds: 500),
                                curve: Curves.easeInOut,
                              );
                            }
                          },
                          borderRadius: BorderRadius.circular(20),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              gradient: const LinearGradient(
                                colors: [Color(0xFFFFF4F8), Color(0xFFFFF0F5)],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AppColors.primary.withValues(
                                  alpha: 0.22,
                                ),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primary.withValues(
                                    alpha: 0.05,
                                  ),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(3),
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFFF0B3),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.star_rounded,
                                    color: Color(0xFFFFB300),
                                    size: 14,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  ratingStr,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.textPrimary,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 3,
                                  height: 3,
                                  decoration: BoxDecoration(
                                    color: Colors.grey.shade400,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  Localizations.localeOf(
                                            context,
                                          ).languageCode ==
                                          'vi'
                                      ? '$reviewsCountStr đánh giá'
                                      : '$reviewsCountStr reviews',
                                  style: const TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Icon(
                                  Icons.keyboard_arrow_down_rounded,
                                  size: 16,
                                  color: AppColors.primary,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Specs Grid (Forms, Surface, Duration formatted to 2h20m, Colors with names & swatches)
                      Builder(
                        builder: (context) {
                          final specItems = <Widget>[];
                          if (variant.nailShape != null) {
                            specItems.add(
                              _buildSpecCard(
                                context,
                                icon: Icons.gesture_rounded,
                                label: S.of(context).nailFormLabel,
                                value: variant.nailShape!.name,
                              ),
                            );
                          }
                          if (variant.nailSurface != null) {
                            specItems.add(
                              _buildSpecCard(
                                context,
                                icon: Icons.layers_rounded,
                                label: S.of(context).nailSurfaceLabel,
                                value: variant.nailSurface!.name,
                              ),
                            );
                          }
                          if (variant.duration != null) {
                            specItems.add(
                              _buildSpecCard(
                                context,
                                icon: Icons.access_time_filled_rounded,
                                label: S.of(context).bookingDurationLabel,
                                value: _formatDurationText(
                                  context,
                                  variant.duration,
                                ),
                              ),
                            );
                          }
                          final colorDetails = _parseColorsWithDetails(
                            context,
                            variant.colorJson,
                          );
                          final colors = colorDetails['colors'] as List<Color>;
                          final colorNames =
                              colorDetails['colorNames'] as String;
                          if (colors.isNotEmpty || colorNames.isNotEmpty) {
                            specItems.add(
                              _buildSpecColorsCard(
                                context,
                                label: S.of(context).colorLabel,
                                colors: colors,
                                colorNames: colorNames,
                              ),
                            );
                          }

                          if (specItems.isEmpty) return const SizedBox.shrink();

                          return GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: specItems.length,
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 2,
                                  crossAxisSpacing: 12,
                                  mainAxisSpacing: 12,
                                  childAspectRatio: 2.15,
                                ),
                            itemBuilder: (context, index) => specItems[index],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildShapeMethodSelection(),
                      NailVariantRatingsSection(
                        nailVariantId: variant.nailVariantId,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // 2. Overlaid floating buttons
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
              // Favorite & Share buttons
              GestureDetector(
                onTap: widget.onFavoriteToggle,
                child: CircleAvatar(
                  backgroundColor: Colors.white.withValues(alpha: 0.9),
                  radius: 20,
                  child: Icon(
                    widget.isFavorited
                        ? Icons.favorite_rounded
                        : Icons.favorite_outline_rounded,
                    size: 20,
                    color: widget.isFavorited
                        ? Colors.redAccent
                        : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),

        // 3. Floating sticky footer buttons
        Positioned(
          bottom: 12,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(24),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 18,
                  spreadRadius: 1,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(color: const Color(0xFFF2F2F7), width: 1.2),
            ),
            child: SafeArea(
              top: false,
              child: Row(
                children: [
                  // Live camera try-on
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: widget.launching
                          ? null
                          : () {
                              widget.onTryOn(_toCustomerNail(variant));
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: EdgeInsets.zero,
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: widget.launching
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: AppColors.primary,
                              ),
                            )
                          : const Icon(Icons.videocam_rounded, size: 22),
                    ),
                  ),
                  const SizedBox(width: 8),

                  // Photo try-on
                  SizedBox(
                    width: 44,
                    height: 44,
                    child: OutlinedButton(
                      onPressed: widget.launching
                          ? null
                          : () {
                              widget.onPhotoTryOn(_toCustomerNail(variant));
                            },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        padding: EdgeInsets.zero,
                        side: const BorderSide(
                          color: AppColors.primary,
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Icon(Icons.photo_camera_rounded, size: 22),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Book Appointment Button
                  Expanded(
                    child: SizedBox(
                      height: 44,
                      child: ElevatedButton(
                        onPressed: _selectedShapeMethod == null
                            ? null
                            : () {
                                final selectedShapeMethod =
                                    _selectedShapeMethod!;
                                AuthGuard.check(context, () {
                                  final Map<String, dynamic> bookingData = {
                                    'id': variant.nailVariantId.toString(),
                                    'name': variant.name,
                                    'image': variant.imageUrl,
                                    'price': variant.price,
                                    'duration': variant.duration,
                                    'shapeMethodConfigId':
                                        selectedShapeMethod.shapeMethodConfigId,
                                    'shapeMethodName': selectedShapeMethod.name,
                                    'shapeMethodPrice':
                                        selectedShapeMethod.price,
                                    'shapeMethodDuration':
                                        selectedShapeMethod.duration,
                                    if (widget.sourceSalonId?.isNotEmpty ==
                                        true)
                                      'sourceSalonId': widget.sourceSalonId,
                                    if (widget.sourceArtistId?.isNotEmpty ==
                                        true)
                                      'sourceArtistId': widget.sourceArtistId,
                                  };
                                  context.push(
                                    '/nail-booking',
                                    extra: bookingData,
                                  );
                                });
                              },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          disabledBackgroundColor: AppColors.primary.withValues(
                            alpha: 0.35,
                          ),
                          foregroundColor: Colors.white,
                          disabledForegroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          S.of(context).bookAppointmentNow,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
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

  Widget _buildSpecCard(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCE4EC), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: Icon(icon, color: AppColors.primary, size: 15),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecColorsCard(
    BuildContext context, {
    required String label,
    required List<Color> colors,
    required String colorNames,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFFCE4EC), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.15),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  blurRadius: 4,
                  offset: const Offset(0, 1),
                ),
              ],
            ),
            child: const Icon(
              Icons.palette_rounded,
              color: AppColors.primary,
              size: 15,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.2,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    if (colors.isNotEmpty) ...[
                      Row(
                        children: colors
                            .take(3)
                            .map(
                              (color) => Container(
                                margin: const EdgeInsets.only(right: 3),
                                width: 12,
                                height: 12,
                                decoration: BoxDecoration(
                                  color: color,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                    width: 1,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                      const SizedBox(width: 3),
                    ],
                    Expanded(
                      child: Text(
                        colorNames,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildShapeMethodSelection() {
    return FutureBuilder<List<ShapeMethodConfigModel>>(
      future: _shapeMethodsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          );
        }

        final methods = (snapshot.data ?? const <ShapeMethodConfigModel>[])
            .where((method) => method.status.toLowerCase() != 'inactive')
            .toList();
        if (methods.isEmpty) return const SizedBox.shrink();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  S.of(context).shapeMethodLabel,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Georgia',
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '(Chọn 1)',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: methods.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 1.8,
              ),
              itemBuilder: (context, index) {
                final method = methods[index];
                final selected =
                    _selectedShapeMethod?.shapeMethodConfigId ==
                    method.shapeMethodConfigId;
                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedShapeMethod = method;
                    });
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? const Color(0xFFFFF7FA) : Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? AppColors.primary
                            : const Color(0xFFEFEFEF),
                        width: selected ? 1.6 : 1.0,
                      ),
                      boxShadow: selected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.1),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.02),
                                blurRadius: 4,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Text(
                                method.name,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.textPrimary,
                                  height: 1.2,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 18,
                              height: 18,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: selected
                                    ? AppColors.primary
                                    : Colors.transparent,
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: selected
                                  ? const Icon(
                                      Icons.check,
                                      size: 11,
                                      color: Colors.white,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: 11,
                              color: selected
                                  ? AppColors.primary.withValues(alpha: 0.8)
                                  : Colors.grey.shade500,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                DurationFormatter.format(
                                  method.duration,
                                  context: context,
                                ),
                                style: TextStyle(
                                  color: selected
                                      ? AppColors.primary.withValues(alpha: 0.9)
                                      : Colors.grey.shade600,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 5),
                        Text(
                          PriceFormatter.format(method.price),
                          style: TextStyle(
                            color: selected
                                ? AppColors.primary
                                : AppColors.primaryDark,
                            fontWeight: FontWeight.w800,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }

  nails_model.CustomerNailModel _toCustomerNail(NailVariantModel variant) {
    return nails_model.CustomerNailModel(
      customerNailId: variant.nailVariantId,
      name: variant.name,
      imageUrl: variant.imageUrl,
      nailShapeId: variant.nailShapeId,
      nailSurfaceId: variant.nailSurfaceId,
      price: variant.price,
      customColor: variant.colorJson,
      duration: variant.duration,
      nailShape: variant.nailShape,
      nailSurface: variant.nailSurface,
      customerNailComponents: variant.nailComponents
          .map<nails_model.CustomerNailComponentModel>((component) {
            final source = component.component;
            return nails_model.CustomerNailComponentModel(
              customerNailComponentId: component.nailComponentId,
              customerNailId: variant.nailVariantId,
              componentId: component.componentId,
              customerComponentId: null,
              posX: component.posX,
              posY: component.posY,
              fingerIndex: component.fingerIndex,
              configJson: jsonEncode({
                'scale': component.config.scale,
                'rotation': component.config.rotation,
                'color': component.config.color,
                'gradient': component.config.gradient,
                'type': component.config.type,
                'imageSrc': component.config.imageSrc,
                'x': component.config.x,
                'y': component.config.y,
              }),
              component: source,
            );
          })
          .toList(),
    );
  }
}

class NailVariantSkeleton extends StatelessWidget {
  const NailVariantSkeleton({super.key});

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
                      const SkeletonBox(width: 200, height: 26),
                      const SizedBox(height: 8),
                      const SkeletonBox(width: 120, height: 16),
                      const SizedBox(height: 12),
                      const SkeletonBox(width: 100, height: 22),
                      const SizedBox(height: 20),
                      const SkeletonBox(
                        width: double.infinity,
                        height: 120,
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      const SizedBox(height: 24),
                      const SkeletonBox(
                        width: double.infinity,
                        height: 80,
                        borderRadius: BorderRadius.all(Radius.circular(16)),
                      ),
                      const SizedBox(height: 28),
                      const SkeletonBox(width: 160, height: 22),
                      const SizedBox(height: 16),
                      const SkeletonBox(
                        width: double.infinity,
                        height: 60,
                        borderRadius: BorderRadius.all(Radius.circular(16)),
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
