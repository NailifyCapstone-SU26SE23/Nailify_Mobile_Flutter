import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../../../core/utils/price_formatter.dart';

import '../../../../core/di/injection.dart';
import '../../data/models/customer_nail_models.dart' as nails_model;
import '../../data/models/nail_component_model.dart';
import '../../data/models/nail_variant_model.dart';
import '../../data/models/shape_method_config_model.dart';
import '../../data/repositories/nail_variant_repository.dart';
import '../../services/ar_try_on_service.dart';
import '../../../../generated/l10n.dart';

class NailVariantDetailScreen extends StatefulWidget {
  final int nailVariantId;
  final String? designName;

  const NailVariantDetailScreen({
    super.key,
    required this.nailVariantId,
    this.designName,
  });

  @override
  State<NailVariantDetailScreen> createState() =>
      _NailVariantDetailScreenState();
}

class _NailVariantDetailScreenState extends State<NailVariantDetailScreen> {
  late Future<NailVariantModel> _future;
  bool _launching = false;
  bool _isFavorited = false;

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
          return _DetailContent(
            variant: snapshot.data!,
            designName: widget.designName,
            launching: _launching,
            onTryOn: _openTryOn,
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

class _DetailContent extends StatefulWidget {
  final NailVariantModel variant;
  final String? designName;
  final bool launching;
  final Future<void> Function(nails_model.CustomerNailModel customerNail)
  onTryOn;
  final bool isFavorited;
  final VoidCallback onFavoriteToggle;

  const _DetailContent({
    required this.variant,
    this.designName,
    required this.launching,
    required this.onTryOn,
    required this.isFavorited,
    required this.onFavoriteToggle,
  });

  @override
  State<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends State<_DetailContent> {
  late final Future<List<ShapeMethodConfigModel>> _shapeMethodsFuture;
  ShapeMethodConfigModel? _selectedShapeMethod;

  double _rating = 0.0;
  int _reviewsCount = 0;
  bool _isLoadingRating = true;

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

  List<Color> _parseColors(String? colorJson) {
    if (colorJson == null || colorJson.trim().isEmpty) return [];
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
      for (final hex in hexStrings.toSet()) {
        final cleanHex = hex.replaceAll('#', '').trim();
        if (cleanHex.length == 6) {
          colors.add(Color(int.parse('FF$cleanHex', radix: 16)));
        } else if (cleanHex.length == 8) {
          colors.add(Color(int.parse(cleanHex, radix: 16)));
        }
      }
      return colors;
    } catch (_) {
      return [];
    }
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
                    100,
                  ), // padding bottom 100 to avoid sticky bottom bar overlapping
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
                      // Price
                      Text(
                        PriceFormatter.format(variant.price),
                        style: const TextStyle(
                          fontSize: 22,
                          color: Color(0xFFFF4081),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Rating block
                      Row(
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: Color(0xFFFFB300),
                            size: 20,
                          ),
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
                      const SizedBox(height: 24),

                      // Specs Grid
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
                                value: S
                                    .of(context)
                                    .minutesLabel(variant.duration!),
                              ),
                            );
                          }
                          final colors = _parseColors(variant.colorJson);
                          if (colors.isNotEmpty) {
                            specItems.add(
                              _buildSpecColorsCard(
                                context,
                                label: S.of(context).colorLabel,
                                colors: colors,
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
                                  childAspectRatio: 1.85,
                                ),
                            itemBuilder: (context, index) => specItems[index],
                          );
                        },
                      ),
                      const SizedBox(height: 24),
                      _buildShapeMethodSelection(),
                      const SizedBox(height: 28),

                      // Detailed Components
                      Text(
                        S.of(context).designComponentsLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontFamily: 'Georgia',
                          letterSpacing: -0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      for (var finger = 0; finger < 5; finger++)
                        _FingerComponents(
                          fingerIndex: finger,
                          components: grouped[finger] ?? const [],
                        ),
                      if (grouped[-1]?.isNotEmpty == true)
                        _FingerComponents(
                          fingerIndex: -1,
                          components: grouped[-1]!,
                          title: S.of(context).sharedLabel,
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

        // 3. Sticky footer buttons
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
                children: [
                  // AR Try-On Button
                  Expanded(
                    flex: 1,
                    child: SizedBox(
                      height: 50,
                      child: OutlinedButton(
                        onPressed: widget.launching
                            ? null
                            : () {
                                widget.onTryOn(_toCustomerNail(variant));
                              },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(
                            color: AppColors.primary,
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
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
                            : const Icon(Icons.view_in_ar_rounded, size: 24),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Book Appointment Button
                  Expanded(
                    flex: 3,
                    child: SizedBox(
                      height: 50,
                      child: ElevatedButton(
                        onPressed: () {
                          AuthGuard.check(context, () {
                            final Map<String, dynamic> bookingData = {
                              'id': variant.nailVariantId.toString(),
                              'name': variant.name,
                              'image': variant.imageUrl,
                              'price': variant.price,
                              'shapeMethodConfigId':
                                  _selectedShapeMethod?.shapeMethodConfigId,
                              'shapeMethodName': _selectedShapeMethod?.name,
                              'shapeMethodPrice': _selectedShapeMethod?.price,
                              'shapeMethodDuration':
                                  _selectedShapeMethod?.duration,
                            };
                            context.push('/nail-booking', extra: bookingData);
                          });
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          S.of(context).bookAppointmentNow,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
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
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4081).withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF4081).withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, color: const Color(0xFFFF4081), size: 20),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSpecColorsCard(
    BuildContext context, {
    required String label,
    required List<Color> colors,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4081).withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFFF4081).withValues(alpha: 0.08),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              const Icon(
                Icons.palette_rounded,
                color: Color(0xFFFF4081),
                size: 20,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: colors
                  .map(
                    (color) => Container(
                      margin: const EdgeInsets.only(right: 6),
                      width: 18,
                      height: 18,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.grey.shade300,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.1),
                            blurRadius: 3,
                            offset: const Offset(0, 1),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
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

        _selectedShapeMethod ??= methods.first;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
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
            const SizedBox(height: 12),
            ...methods.map((method) {
              final selected =
                  _selectedShapeMethod?.shapeMethodConfigId ==
                  method.shapeMethodConfigId;
              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: selected
                      ? AppColors.primary.withValues(alpha: 0.05)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: selected
                        ? AppColors.primary
                        : const Color(0xFFFFF0F5),
                    width: 1.5,
                  ),
                ),
                child: RadioListTile<int>(
                  value: method.shapeMethodConfigId,
                  groupValue: _selectedShapeMethod?.shapeMethodConfigId,
                  onChanged: (_) {
                    setState(() => _selectedShapeMethod = method);
                  },
                  title: Text(
                    method.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    S.of(context).minutesLabel(method.duration),
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                  ),
                  secondary: Text(
                    PriceFormatter.format(method.price),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  activeColor: AppColors.primary,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              );
            }),
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

class _FingerComponents extends StatelessWidget {
  final int fingerIndex;
  final List<NailComponentModel> components;
  final String? title;

  const _FingerComponents({
    required this.fingerIndex,
    required this.components,
    this.title,
  });

  @override
  Widget build(BuildContext context) {
    if (components.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Padding(
              padding: const EdgeInsets.only(top: 10.0),
              child: Text(
                title ?? _fingerName(context, fingerIndex),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: components
                  .map((component) => _ComponentChip(component: component))
                  .toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _fingerName(BuildContext context, int index) {
    final s = S.of(context);
    final names = [
      s.fingerThumb,
      s.fingerIndex,
      s.fingerMiddle,
      s.fingerRing,
      s.fingerPinky,
    ];
    return index >= 0 && index < names.length
        ? names[index]
        : s.fingerOther(index);
  }
}

class _ComponentChip extends StatelessWidget {
  final NailComponentModel component;

  const _ComponentChip({required this.component});

  @override
  Widget build(BuildContext context) {
    final typeText = component.component?.componentType.isNotEmpty == true
        ? component.component!.componentType
        : S.of(context).decorationLabel;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFF4081).withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: const Color(0xFFFF4081).withValues(alpha: 0.06),
          width: 1.2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 28,
              height: 28,
              child: component.component?.imageUrl.isNotEmpty == true
                  ? Image.network(
                      component.component!.imageUrl,
                      fit: BoxFit.contain,
                    )
                  : const Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary,
                      size: 18,
                    ),
            ),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  component.component?.name ??
                      S
                          .of(context)
                          .componentNameFallback(component.componentId),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  typeText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
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
