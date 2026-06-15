import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/auth_guard.dart';

import '../../../../core/di/injection.dart';
import '../../data/models/nail_component_model.dart';
import '../../data/models/nail_variant_model.dart';
import '../../data/repositories/nail_repository.dart';
import '../../services/ar_try_on_service.dart';

class NailVariantDetailScreen extends StatefulWidget {
  final int nailVariantId;

  const NailVariantDetailScreen({super.key, required this.nailVariantId});

  @override
  State<NailVariantDetailScreen> createState() => _NailVariantDetailScreenState();
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
    return getIt<NailRepository>().getNailVariantById(widget.nailVariantId);
  }

  Future<void> _openTryOn(Future<void> Function(NailVariantModel) launcher) async {
    setState(() => _launching = true);
    try {
      final variant = await _future;
      await launcher(variant);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi khi mở AR: $e')));
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Chi tiết biến thể', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.textPrimary),
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
                  Text('Lỗi khi tải dữ liệu: ${snapshot.error}', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: () => setState(() => _future = _loadVariant()),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Thử lại'),
                  )
                ],
              ),
            );
          }
          return _DetailContent(
            variant: snapshot.data!,
            launching: _launching,
            onTryOn: _openTryOn,
          );
        },
      ),
    );
  }
}

class _DetailContent extends StatelessWidget {
  final NailVariantModel variant;
  final bool launching;
  final ValueChanged<Future<void> Function(NailVariantModel)> onTryOn;

  const _DetailContent({
    required this.variant,
    required this.launching,
    required this.onTryOn,
  });

  @override
  Widget build(BuildContext context) {
    // Nhóm các component theo từng ngón tay
    final grouped = <int, List<NailComponentModel>>{};
    for (final component in variant.nailComponents) {
      grouped.putIfAbsent(component.fingerIndex, () => []).add(component);
    }

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(20),
            physics: const BouncingScrollPhysics(),
            children: [
              // 1. Hình ảnh
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  width: double.infinity,
                  height: 300,
                  child: variant.imageUrl.isEmpty
                      ? Container(color: AppColors.primary.withOpacity(0.1), child: const Icon(Icons.spa_outlined, size: 64, color: AppColors.primary))
                      : Image.network(variant.imageUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(height: 24),

              // 2. Tên & Giá tiền
              Text(variant.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 8),
              Text(
                '${variant.price.toStringAsFixed(0)} VND',
                style: const TextStyle(fontSize: 20, color: AppColors.primary, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),

              // 3. Các đặc điểm nổi bật (Chips)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (variant.nailShape != null) _DetailChip(label: variant.nailShape!.name),
                  if (variant.nailSurface != null) _DetailChip(label: variant.nailSurface!.name),
                  if (variant.duration != null) _DetailChip(label: '${variant.duration} phút'),
                ],
              ),
              const SizedBox(height: 32),

              // 4. Các thành phần chi tiết (Components)
              const Text('Thành phần (Components)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
              const SizedBox(height: 16),
              for (var finger = 0; finger < 5; finger++)
                _FingerComponents(fingerIndex: finger, components: grouped[finger] ?? const []),
              if (grouped[-1]?.isNotEmpty == true)
                _FingerComponents(fingerIndex: -1, components: grouped[-1]!, title: 'Dùng chung (Shared)'),
            ],
          ),
        ),

        // FOOTER CHỨA NÚT AR TRY ON & BOOK NOW
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))],
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
                      // BỎ async và await đi
                      onPressed: launching
                          ? null
                          : () {
                        final service = getIt<ArTryOnService>();
                        onTryOn((nailVariant) => service.launch(nailVariant));
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: launching
                          ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary)
                      )
                          : const Icon(Icons.view_in_ar, size: 24),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Nút Book Now
                Expanded(
                  flex: 3,
                  child: SizedBox(
                    height: 50,
                    child: ElevatedButton(
                      onPressed: () {
                        // Đóng gói dữ liệu mẫu variant để truyền sang trang booking
                        AuthGuard.check(context, () {
                          final Map<String, dynamic> bookingData = {
                            'id': variant.nailVariantId.toString(),
                            'name': variant.name,
                            'image': variant.imageUrl,
                            'price': variant.price,
                          };
                          context.push('/nail-booking', extra: bookingData);
                        });

                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
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
}

class _FingerComponents extends StatelessWidget {
  final int fingerIndex;
  final List<NailComponentModel> components;
  final String? title;

  const _FingerComponents({required this.fingerIndex, required this.components, this.title});

  @override
  Widget build(BuildContext context) {
    if (components.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 60,
            child: Text(
              title ?? _fingerName(fingerIndex),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.textSecondary),
            ),
          ),
          Expanded(
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: components.map((component) => _ComponentChip(component: component)).toList(),
            ),
          ),
        ],
      ),
    );
  }

  String _fingerName(int index) {
    const names = ['Ngón cái', 'Ngón trỏ', 'Ngón giữa', 'Ngón áp út', 'Ngón út'];
    return index >= 0 && index < names.length ? names[index] : 'Ngón $index';
  }
}

class _ComponentChip extends StatelessWidget {
  final NailComponentModel component;

  const _ComponentChip({required this.component});

  @override
  Widget build(BuildContext context) {
    final config = component.config;
    final subtitle = 'x: ${component.posX.toStringAsFixed(1)}, y: ${component.posY.toStringAsFixed(1)}, scale: ${config.scale.toStringAsFixed(1)}';
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 30,
            height: 30,
            child: component.component?.imageUrl.isNotEmpty == true
                ? Image.network(component.component!.imageUrl, fit: BoxFit.contain)
                : const Icon(Icons.auto_awesome, color: AppColors.primary, size: 20),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  component.component?.name ?? 'Component ${component.componentId}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailChip extends StatelessWidget {
  final String label;

  const _DetailChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.bold),
      ),
    );
  }
}