import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/utils/price_formatter.dart';
import '../../../../core/di/injection.dart';
import '../../data/models/nail_component_model.dart';
import '../../data/models/nail_design_model.dart';
import '../../data/models/nail_variant_model.dart';
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
    _future = getIt<NailDesignRepository>().getNailDesignById(widget.nailDesignId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<NailDesignModel>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError || !snapshot.hasData) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(snapshot.error?.toString() ?? 'Could not load nail design.', textAlign: TextAlign.center),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => setState(() {
                      _future = getIt<NailDesignRepository>().getNailDesignById(widget.nailDesignId);
                    }),
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            ),
          );
        }
        return _DesignDetailContent(design: snapshot.data!);
      },
    );
  }
}

class _DesignDetailContent extends StatelessWidget {
  final NailDesignModel design;

  const _DesignDetailContent({required this.design});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: () {
              if (context.canPop()) {
                context.pop();
              } else {
                context.go('/nails');
              }
            },
            icon: const Icon(Icons.arrow_back),
            label: const Text('Back to designs'),
          ),
        ),
        const SizedBox(height: 8),
        _ImageGallery(imageUrls: design.imageUrls),
        const SizedBox(height: 16),
        Text(design.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          '${PriceFormatter.format(design.minPrice).replaceAll(' VNĐ', '')} - ${PriceFormatter.format(design.maxPrice)}',
          style: const TextStyle(color: Color(0xFFFF66C4), fontWeight: FontWeight.w800),
        ),
        if (design.description.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(design.description, style: const TextStyle(height: 1.45)),
        ],
        if (design.categories.isNotEmpty) ...[
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: design.categories.map((category) => Chip(label: Text(category.name))).toList(),
          ),
        ],
        const SizedBox(height: 24),
        Text('Variants (${design.nailVariants.length})', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        const SizedBox(height: 12),
        if (design.nailVariants.isEmpty)
          const Text('No variants are available for this design yet.', style: TextStyle(color: Colors.black54))
        else
          for (final variant in design.nailVariants) _VariantSection(variant: variant),
      ],
    );
  }
}

class _ImageGallery extends StatelessWidget {
  final List<String> imageUrls;

  const _ImageGallery({required this.imageUrls});

  @override
  Widget build(BuildContext context) {
    if (imageUrls.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: AspectRatio(
          aspectRatio: 1.2,
          child: Container(
            color: const Color(0xFFF7E8F1),
            alignment: Alignment.center,
            child: const Icon(Icons.spa_outlined, size: 48),
          ),
        ),
      );
    }

    return SizedBox(
      height: 280,
      child: PageView.builder(
        itemCount: imageUrls.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: EdgeInsets.only(right: index == imageUrls.length - 1 ? 0 : 8),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrls[index],
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Container(
                  color: const Color(0xFFF7E8F1),
                  alignment: Alignment.center,
                  child: const Icon(Icons.broken_image_outlined),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _VariantSection extends StatelessWidget {
  final NailVariantModel variant;

  const _VariantSection({required this.variant});

  @override
  Widget build(BuildContext context) {
    final grouped = <int, List<NailComponentModel>>{};
    for (final component in variant.nailComponents) {
      grouped.putIfAbsent(component.fingerIndex, () => []).add(component);
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  width: 82,
                  height: 82,
                  child: variant.imageUrl.isEmpty
                      ? Container(color: const Color(0xFFF7E8F1), child: const Icon(Icons.spa_outlined))
                      : Image.network(variant.imageUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(variant.name, style: const TextStyle(fontWeight: FontWeight.w800)),
                    const SizedBox(height: 6),
                    Text(PriceFormatter.format(variant.price), style: const TextStyle(color: Color(0xFFFF66C4), fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        _SmallChip(label: variant.nailShape?.name ?? 'Shape'),
                        _SmallChip(label: variant.nailSurface?.name ?? 'Surface'),
                        if (variant.duration != null) _SmallChip(label: '${variant.duration} min'),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => context.push(
                    '/nail-variants/${variant.nailVariantId}',
                  ),
                  icon: const Icon(Icons.keyboard_arrow_up),
                  label: const Text('Variant detail'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Components', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          for (var finger = 0; finger < 5; finger++) _FingerComponents(fingerIndex: finger, components: grouped[finger] ?? const []),
          if (grouped[-1]?.isNotEmpty == true) _FingerComponents(fingerIndex: -1, components: grouped[-1]!, title: 'Shared'),
        ],
      ),
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
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 58,
            child: Text(title ?? _fingerName(fingerIndex), style: Theme.of(context).textTheme.bodySmall),
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
    const names = ['Thumb', 'Index', 'Middle', 'Ring', 'Pinky'];
    return index >= 0 && index < names.length ? names[index] : 'Finger $index';
  }
}

class _ComponentChip extends StatelessWidget {
  final NailComponentModel component;

  const _ComponentChip({required this.component});

  @override
  Widget build(BuildContext context) {
    final config = component.config;
    final subtitle = 'x ${component.posX.toStringAsFixed(2)}, y ${component.posY.toStringAsFixed(2)}, scale ${config.scale.toStringAsFixed(2)}';
    return Container(
      constraints: const BoxConstraints(maxWidth: 230),
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7FB),
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 34,
            height: 34,
            child: component.component?.imageUrl.isNotEmpty == true
                ? Image.network(component.component!.imageUrl, fit: BoxFit.contain)
                : const Icon(Icons.auto_awesome, color: Color(0xFFFF66C4)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(component.component?.name ?? 'Component ${component.componentId}', maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(subtitle, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SmallChip extends StatelessWidget {
  final String label;

  const _SmallChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}
