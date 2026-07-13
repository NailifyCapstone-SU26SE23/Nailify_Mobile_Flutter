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
    _future = getIt<NailDesignRepository>().getNailDesignById(
      widget.nailDesignId,
    );
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
                  Text(
                    snapshot.error?.toString() ?? 'Could not load nail design.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () => setState(() {
                      _future = getIt<NailDesignRepository>().getNailDesignById(
                        widget.nailDesignId,
                      );
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
        Text(
          design.name,
          style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          '${PriceFormatter.format(design.minPrice).replaceAll(' VNĐ', '')} - ${PriceFormatter.format(design.maxPrice)}',
          style: const TextStyle(
            color: Color(0xFFFF66C4),
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
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
            children: design.categories
                .map((category) => Chip(label: Text(category.name)))
                .toList(),
          ),
        ],
        const SizedBox(height: 24),
        Text(
          'Variants (${design.nailVariants.length})',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        if (design.nailVariants.isEmpty)
          const Text(
            'No variants are available for this design yet.',
            style: TextStyle(color: Colors.black54),
          )
        else
          for (final variant in design.nailVariants)
            _VariantSection(variant: variant, designName: design.name),
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
            padding: EdgeInsets.only(
              right: index == imageUrls.length - 1 ? 0 : 8,
            ),
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
  final String designName;

  const _VariantSection({required this.variant, required this.designName});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.black12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
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
                  borderRadius: BorderRadius.circular(8),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: variant.imageUrl.isEmpty
                        ? Container(
                            color: const Color(0xFFF7E8F1),
                            child: const Icon(Icons.spa_outlined),
                          )
                        : Image.network(variant.imageUrl, fit: BoxFit.cover),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        variant.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        PriceFormatter.format(variant.price),
                        style: const TextStyle(
                          color: Color(0xFFFF66C4),
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.only(left: 8),
                  child: Icon(Icons.chevron_right, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


