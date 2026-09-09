import 'dart:convert';
import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../nails/data/models/nail_variant_model.dart';
import '../../../nails/data/models/shape_method_config_model.dart';
import '../../../nails/data/repositories/nail_variant_repository.dart';
import '../../../../generated/l10n.dart';

/// Bottom sheet hiển thị chi tiết nail variant.
///
/// Mở khi khách bấm "Xem chi tiết" từ danh sách gợi ý của thợ.
/// Nút "Chọn mẫu này" ở dưới cùng sẽ trả về variant đã chọn + shape method.
class NailVariantDetailSheet extends StatefulWidget {
  final NailVariantModel variant;
  final VoidCallback? onDismissed;

  const NailVariantDetailSheet({
    super.key,
    required this.variant,
    this.onDismissed,
  });

  /// Hiển thị sheet với variant bất kỳ.
  /// Trả về `true` nếu khách bấm "Chọn mẫu này".
  static Future<ShapeMethodConfigModel?> show(
    BuildContext context, {
    required NailVariantModel variant,
  }) async {
    return await showModalBottomSheet<ShapeMethodConfigModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NailVariantDetailSheet(
        variant: variant,
        onDismissed: () => Navigator.pop(context),
      ),
    );
  }

  @override
  State<NailVariantDetailSheet> createState() => _NailVariantDetailSheetState();
}

class _NailVariantDetailSheetState extends State<NailVariantDetailSheet> {
  late final Future<List<ShapeMethodConfigModel>> _shapeMethodsFuture;
  ShapeMethodConfigModel? _selectedShapeMethod;

  @override
  void initState() {
    super.initState();
    _shapeMethodsFuture = getIt<NailVariantRepository>()
        .getShapeMethodConfigsByNailShape(widget.variant.nailShapeId);
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
    final grouped = <int, List<dynamic>>{};
    for (final component in variant.nailComponents) {
      grouped.putIfAbsent(component.fingerIndex, () => []).add(component);
    }

    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // ── Drag handle + close ────────────────────────────────
              Padding(
                padding: const EdgeInsets.only(top: 12, right: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.close, size: 18),
                      ),
                    ),
                  ],
                ),
              ),
              // ── Scrollable content ─────────────────────────────────
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Image
                      ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 260,
                          child: variant.imageUrl.isEmpty
                              ? Container(
                                  color: const Color(0xFFF5F5F7),
                                  child: const Icon(
                                    Icons.spa_rounded,
                                    size: 64,
                                    color: AppColors.primary,
                                  ),
                                )
                              : Image.network(
                                  variant.imageUrl,
                                  fit: BoxFit.cover,
                                ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Name & price
                      Text(
                        variant.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          fontFamily: 'Georgia',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text.rich(
                        TextSpan(
                          children: [
                            const TextSpan(text: 'Giá tham khảo: '),
                            TextSpan(
                              text: PriceFormatter.format(
                                variant.estimatedPrice ?? variant.price,
                              ),
                            ),
                          ],
                        ),
                        style: const TextStyle(
                          fontSize: 20,
                          color: Color(0xFFFF4081),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Specs grid
                      _buildSpecsGrid(variant),
                      const SizedBox(height: 24),

                      // Shape method selection
                      _buildShapeMethodSection(),
                      const SizedBox(height: 24),

                      // Component chips
                      if (grouped.values.any((v) => v.isNotEmpty)) ...[
                        _buildComponentChips(grouped),
                        const SizedBox(height: 24),
                      ],

                      // Component price table
                      _buildComponentPriceTable(variant),
                    ],
                  ),
                ),
              ),
              // ── Sticky footer: Chọn mẫu này ───────────────────────
              Container(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.06),
                      blurRadius: 10,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: SafeArea(
                  top: false,
                  child: SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton(
                      onPressed: () =>
                          Navigator.pop(context, _selectedShapeMethod),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: const Text(
                        'Chọn mẫu này',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSpecsGrid(NailVariantModel variant) {
    final specItems = <Widget>[];
    if (variant.nailShape != null) {
      specItems.add(
        _buildSpecCard(
          icon: Icons.gesture_rounded,
          label: S.of(context).nailFormLabel,
          value: variant.nailShape!.name,
        ),
      );
    }
    if (variant.nailSurface != null) {
      specItems.add(
        _buildSpecCard(
          icon: Icons.layers_rounded,
          label: S.of(context).nailSurfaceLabel,
          value: variant.nailSurface!.name,
        ),
      );
    }
    if (variant.duration != null) {
      specItems.add(
        _buildSpecCard(
          icon: Icons.access_time_filled_rounded,
          label: S.of(context).bookingDurationLabel,
          value: S.of(context).minutesLabel('${variant.duration}'),
        ),
      );
    }
    final colors = _parseColors(variant.colorJson);
    if (colors.isNotEmpty) {
      specItems.add(_buildSpecColorsCard(colors: colors));
    }
    if (specItems.isEmpty) return const SizedBox.shrink();
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: specItems.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.85,
      ),
      itemBuilder: (context, index) => specItems[index],
    );
  }

  Widget _buildSpecCard({
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

  Widget _buildSpecColorsCard({required List<Color> colors}) {
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
              Text(
                S.of(context).colorLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade500,
                  fontWeight: FontWeight.w500,
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

  Widget _buildShapeMethodSection() {
    return FutureBuilder<List<ShapeMethodConfigModel>>(
      future: _shapeMethodsFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        final methods = (snapshot.data ?? const <ShapeMethodConfigModel>[])
            .where((m) => m.status.toLowerCase() != 'inactive')
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
                    S.of(context).minutesLabel('${method.duration}'),
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

  Widget _buildComponentChips(Map<int, List<dynamic>> grouped) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          S.of(context).designComponentsLabel,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Georgia',
          ),
        ),
        const SizedBox(height: 16),
        for (var finger = 0; finger < 5; finger++)
          if (grouped[finger]?.isNotEmpty == true)
            _buildFingerRow(finger, grouped[finger]!),
        if (grouped[-1]?.isNotEmpty == true)
          _buildFingerRow(-1, grouped[-1]!, title: S.of(context).sharedLabel),
      ],
    );
  }

  Widget _buildFingerRow(
    int fingerIndex,
    List<dynamic> components, {
    String? title,
  }) {
    final fingerNames = [
      S.of(context).fingerThumb,
      S.of(context).fingerIndex,
      S.of(context).fingerMiddle,
      S.of(context).fingerRing,
      S.of(context).fingerPinky,
    ];
    final name =
        title ??
        (fingerIndex >= 0 && fingerIndex < fingerNames.length
            ? fingerNames[fingerIndex]
            : S.of(context).fingerOther(fingerIndex.toString()));
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(
                name,
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
              children: components.map((component) {
                final comp = component.component;
                final typeText = comp?.componentType?.isNotEmpty == true
                    ? comp!.componentType
                    : S.of(context).decorationLabel;
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
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
                          child: comp?.imageUrl?.isNotEmpty == true
                              ? Image.network(
                                  comp!.imageUrl!,
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
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              comp?.name ??
                                  S
                                      .of(context)
                                      .componentNameFallback(
                                        component.componentId.toString(),
                                      ),
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
                              style: const TextStyle(
                                fontSize: 10,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComponentPriceTable(NailVariantModel variant) {
    final rows = <Map<String, dynamic>>[];
    if (variant.nailSurface != null) {
      rows.add({
        'name': variant.nailSurface!.name,
        'price': variant.nailSurface!.price,
        'quantity': 1,
      });
    }
    final shapeMethod = _selectedShapeMethod;
    if (shapeMethod != null) {
      rows.add({
        'name': shapeMethod.name,
        'price': shapeMethod.price,
        'quantity': 1,
      });
    }
    final componentRowsByKey = <String, Map<String, dynamic>>{};
    for (final component in variant.nailComponents) {
      final detail = component.component;
      final name = detail?.name ?? S.of(context).bookingComponentDefault;
      final type = detail?.componentType.trim() ?? '';
      final label = type.isEmpty ? name : '$type: $name';
      final price = detail?.price ?? 0;
      final quantity = component.fingerIndex == -1 ? 5 : 1;
      final key =
          '${detail?.componentId ?? component.componentId}|$label|$price';
      final existing = componentRowsByKey[key];
      if (existing == null) {
        componentRowsByKey[key] = {
          'name': label,
          'price': price,
          'quantity': quantity,
        };
      } else {
        existing['quantity'] = (existing['quantity'] as int) + quantity;
      }
    }
    rows.addAll(componentRowsByKey.values);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Bảng thành phần',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            fontFamily: 'Georgia',
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Column(
            children: [
              const _TableHeader(),
              const SizedBox(height: 6),
              ...rows.map(_buildPriceLine),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPriceLine(Map<String, dynamic> row) {
    final price = row['price'] as num? ?? 0;
    final count = row['quantity'] as int? ?? 1;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Expanded(
            flex: 5,
            child: Text(
              row['name']?.toString() ?? S.of(context).bookingComponentDefault,
              style: const TextStyle(color: Colors.grey, fontSize: 13),
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 38,
            child: Text(
              'x$count',
              style: const TextStyle(
                color: Colors.grey,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(width: 10),
          SizedBox(
            width: 92,
            child: Text(
              price > 0 ? PriceFormatter.format(price * count) : '-',
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader();
  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      color: AppColors.textSecondary,
      fontSize: 12,
      fontWeight: FontWeight.bold,
    );
    return Row(
      children: [
        const Expanded(flex: 5, child: Text('Thành phần', style: style)),
        const SizedBox(width: 10),
        SizedBox(
          width: 38,
          child: Text('SL', style: style, textAlign: TextAlign.center),
        ),
        const SizedBox(width: 10),
        SizedBox(
          width: 92,
          child: Text('Giá', style: style, textAlign: TextAlign.right),
        ),
      ],
    );
  }
}
