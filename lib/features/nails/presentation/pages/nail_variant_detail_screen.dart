import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../../../core/utils/price_formatter.dart';

import '../../../../core/di/injection.dart';
import '../../data/models/component_model.dart';
import '../../data/models/customer_nail_models.dart' as nails_model;
import '../../data/models/nail_component_model.dart';
import '../../data/models/nail_surface_model.dart';
import '../../data/models/nail_variant_model.dart';
import '../../data/models/shape_method_config_model.dart';
import '../../data/repositories/nail_variant_repository.dart';
import '../../services/ar_try_on_service.dart';

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

  Future<void> _openTryOn(
    Future<void> Function(NailVariantModel, NailSurfaceModel?) launcher, {
    NailSurfaceModel? surface,
  }) async {
    setState(() => _launching = true);
    try {
      final variant = await _future;
      await launcher(variant, surface);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Lỗi khi mở AR: $e')));
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
      appBar: AppBar(
        title: const Text(
          'Chi tiết phiên bản',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            size: 18,
            color: AppColors.textPrimary,
          ),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/nails');
            }
          },
        ),
      ),
      body: FutureBuilder<NailVariantModel>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Lỗi khi tải dữ liệu: ${snapshot.error}',
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
                    label: const Text('Thử lại'),
                  ),
                ],
              ),
            );
          }
          return _DetailContent(
            variant: snapshot.data!,
            designName: widget.designName,
            launching: _launching,
            onTryOn: _openTryOn,
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
  final void Function(
    Future<void> Function(NailVariantModel, NailSurfaceModel?) launcher, {
    NailSurfaceModel? surface,
  })
  onTryOn;

  const _DetailContent({
    required this.variant,
    this.designName,
    required this.launching,
    required this.onTryOn,
  });

  @override
  State<_DetailContent> createState() => _DetailContentState();
}

class _DetailContentState extends State<_DetailContent> {
  late final Future<List<ShapeMethodConfigModel>> _shapeMethodsFuture;
  ShapeMethodConfigModel? _selectedShapeMethod;

  @override
  void initState() {
    super.initState();
    _shapeMethodsFuture = getIt<NailVariantRepository>()
        .getShapeMethodConfigsByNailShape(widget.variant.nailShapeId);
  }

  @override
  Widget build(BuildContext context) {
    // Nhóm các component theo từng ngón tay
    final grouped = <int, List<NailComponentModel>>{};
    for (final component in widget.variant.nailComponents) {
      grouped.putIfAbsent(component.fingerIndex, () => []).add(component);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 32),
            physics: const BouncingScrollPhysics(),
            children: [
              // 1. Hình ảnh
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: SizedBox(
                    width: double.infinity,
                    height: 300,
                    child: widget.variant.imageUrl.isEmpty
                        ? Container(
                            color: AppColors.primary.withValues(alpha: 0.08),
                            child: const Icon(
                              Icons.spa_rounded,
                              size: 64,
                              color: AppColors.primary,
                            ),
                          )
                        : Image.network(
                            widget.variant.imageUrl,
                            fit: BoxFit.cover,
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // 2. Tên & Giá tiền
              Text(
                widget.variant.name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              if (widget.designName != null) ...[
                const SizedBox(height: 6),
                Text(
                  'Bộ sưu tập: ${widget.designName}',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade500,
                  ),
                ),
              ],
              const SizedBox(height: 8),
              Text(
                PriceFormatter.format(widget.variant.price),
                style: const TextStyle(
                  fontSize: 20,
                  color: Color(0xFFFF4081),
                  fontWeight: FontWeight.bold,
                ),
              ),

              const SizedBox(height: 24),

              // 3. Thông số kỹ thuật (Specs Table)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: const Color(0xFFFFF0F5), width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.02),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    if (widget.variant.nailShape != null)
                      _buildSpecRow('Form móng', widget.variant.nailShape!.name),
                    if (widget.variant.nailSurface != null) ...[
                      if (widget.variant.nailShape != null)
                        const Divider(height: 24, color: Color(0xFFFFF0F5)),
                      _buildSpecRow('Bề mặt', widget.variant.nailSurface!.name),
                    ],
                    if (widget.variant.duration != null) ...[
                      if (widget.variant.nailShape != null || widget.variant.nailSurface != null)
                        const Divider(height: 24, color: Color(0xFFFFF0F5)),
                      _buildSpecRow('Thời gian thực hiện', '${widget.variant.duration} phút'),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _buildShapeMethodSelection(),
              const SizedBox(height: 28),

              // 4. Các thành phần chi tiết (Components)
              const Text(
                'Thành phần thiết kế',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
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
                  title: 'Dùng chung',
                ),
            ],
          ),
        ),

        // FOOTER CHỨA NÚT AR TRY ON & ĐẶT LỊCH NGAY
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Row(
              children: [
                // Nút AR Try On
                Expanded(
                  flex: 1,
                  child: SizedBox(
                    height: 50,
                    child: OutlinedButton(
                      onPressed: () {
                        final customerNail = nails_model.CustomerNailModel(
                          customerNailId: 0,
                          name: widget.variant.name,
                          imageUrl: widget.variant.imageUrl,
                          nailShapeId: widget.variant.nailShapeId,
                          nailSurfaceId: widget.variant.nailSurfaceId,
                          price: widget.variant.price,
                          customColor: widget.variant.colorJson,
                          duration: widget.variant.duration,
                          isPublic: true,
                          nailShape: widget.variant.nailShape,
                          nailSurface: widget.variant.nailSurface,
                          customerNailComponents: widget.variant.nailComponents.map((c) {
                            return nails_model.CustomerNailComponentModel(
                              customerNailComponentId: 0,
                              customerNailId: 0,
                              componentId: c.componentId,
                              customerComponentId: null,
                              posX: c.posX,
                              posY: c.posY,
                              fingerIndex: c.fingerIndex,
                              configJson: c.configJson,
                              component: c.component != null ? ComponentModel(
                                componentId: c.component!.componentId,
                                name: c.component!.name,
                                imageUrl: c.component!.imageUrl,
                                componentType: c.component!.componentType,
                                price: c.component!.price,
                              ) : null,
                            );
                          }).toList(),
                        );
                        context.push('/try-on', extra: customerNail);
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

                // Nút Đặt lịch ngay
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // Đóng gói dữ liệu mẫu variant để truyền sang trang booking
                        AuthGuard.check(context, () {
                          final Map<String, dynamic> bookingData = {
                            'id': widget.variant.nailVariantId.toString(),
                            'name': widget.variant.name,
                            'image': widget.variant.imageUrl,
                            'price': widget.variant.price,
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
                      child: const Text(
                        'Đặt lịch ngay',
                        style: TextStyle(
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
      ],
    );
  }

  Widget _buildSpecRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        ),
        Text(
          value,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontSize: 14,
          ),
        ),
      ],
    );
  }

  Widget _buildShapeMethodSelection() {
    return FutureBuilder<List<ShapeMethodConfigModel>>(
      future: _shapeMethodsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const SizedBox(
            height: 40,
            child: Align(
              alignment: Alignment.centerLeft,
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
            const Text(
              'Phương pháp tạo form',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
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
                    color: selected ? AppColors.primary : const Color(0xFFFFF0F5),
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
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text('${method.duration} phút', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
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
                title ?? _fingerName(fingerIndex),
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

  String _fingerName(int index) {
    const names = [
      'Ngón cái',
      'Ngón trỏ',
      'Ngón giữa',
      'Ngón áp út',
      'Ngón út',
    ];
    return index >= 0 && index < names.length ? names[index] : 'Ngón $index';
  }
}

class _ComponentChip extends StatelessWidget {
  final NailComponentModel component;

  const _ComponentChip({required this.component});

  @override
  Widget build(BuildContext context) {
    final config = component.config;
    final subtitle =
        'x: ${component.posX.toStringAsFixed(1)}, y: ${component.posY.toStringAsFixed(1)}, scale: ${config.scale.toStringAsFixed(1)}';
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFF5F5F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: SizedBox(
              width: 30,
              height: 30,
              child: component.component?.imageUrl.isNotEmpty == true
                  ? Image.network(
                      component.component!.imageUrl,
                      fit: BoxFit.contain,
                    )
                  : const Icon(
                      Icons.auto_awesome,
                      color: AppColors.primary,
                      size: 20,
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
                      'Thành phần ${component.componentId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  subtitle,
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

