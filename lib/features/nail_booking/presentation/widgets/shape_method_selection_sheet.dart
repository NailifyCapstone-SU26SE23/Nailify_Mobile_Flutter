import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../nails/data/models/nail_variant_model.dart';
import '../../../nails/data/models/shape_method_config_model.dart';
import '../../../nails/data/repositories/nail_variant_repository.dart';
import '../../../../generated/l10n.dart';

/// Bottom sheet đơn giản chỉ hiển thị lựa chọn Phương pháp tạo form
class ShapeMethodSelectionSheet extends StatefulWidget {
  final NailVariantModel variant;
  final ShapeMethodConfigModel? initialSelection;

  const ShapeMethodSelectionSheet({
    super.key,
    required this.variant,
    this.initialSelection,
  });

  static Future<ShapeMethodConfigModel?> show(
    BuildContext context, {
    required NailVariantModel variant,
    ShapeMethodConfigModel? initialSelection,
  }) async {
    return await showModalBottomSheet<ShapeMethodConfigModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ShapeMethodSelectionSheet(
        variant: variant,
        initialSelection: initialSelection,
      ),
    );
  }

  @override
  State<ShapeMethodSelectionSheet> createState() =>
      _ShapeMethodSelectionSheetState();
}

class _ShapeMethodSelectionSheetState extends State<ShapeMethodSelectionSheet> {
  late final Future<List<ShapeMethodConfigModel>> _shapeMethodsFuture;
  ShapeMethodConfigModel? _selectedShapeMethod;

  @override
  void initState() {
    super.initState();
    _selectedShapeMethod = widget.initialSelection;
    _shapeMethodsFuture = getIt<NailVariantRepository>()
        .getShapeMethodConfigsByNailShape(widget.variant.nailShapeId);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Header title & Close button
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        S.of(context).shapeMethodLabel,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Mẫu: ${widget.variant.name}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey.shade600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.pop(context, _selectedShapeMethod),
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, size: 18),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // List shape methods
            FutureBuilder<List<ShapeMethodConfigModel>>(
              future: _shapeMethodsFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  );
                }

                if (snapshot.hasError) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Không thể tải danh sách phương pháp tạo form',
                      style: TextStyle(
                        color: Colors.red.shade400,
                        fontSize: 13,
                      ),
                    ),
                  );
                }

                final methods =
                    (snapshot.data ?? const <ShapeMethodConfigModel>[])
                        .where((m) => m.status.toLowerCase() != 'inactive')
                        .toList();

                if (methods.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      'Mẫu móng này không có phương pháp tạo form riêng',
                      style: TextStyle(color: Colors.grey, fontSize: 13),
                    ),
                  );
                }

                _selectedShapeMethod ??= methods.first;

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: methods.map((method) {
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
                              : Colors.grey.shade200,
                          width: selected ? 1.8 : 1,
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
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                            color: selected
                                ? AppColors.primary
                                : AppColors.textPrimary,
                          ),
                        ),
                        subtitle: Text(
                          DurationFormatter.format(
                            method.duration,
                            context: context,
                          ),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
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
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 2,
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
            const SizedBox(height: 16),

            // Confirm button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context, _selectedShapeMethod);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text(
                  'Xác nhận',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
