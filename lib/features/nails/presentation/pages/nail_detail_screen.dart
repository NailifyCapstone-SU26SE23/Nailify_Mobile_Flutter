import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
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
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 18),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/nails');
            }
          },
        ),
        title: const Text(
          'Chi tiết thiết kế',
          style: TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.bold,
            fontSize: 18,
            letterSpacing: -0.5,
          ),
        ),
        centerTitle: true,
      ),
      body: FutureBuilder<NailDesignModel>(
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
                      snapshot.error?.toString() ?? 'Không thể tải chi tiết thiết kế.',
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
                        _future = getIt<NailDesignRepository>().getNailDesignById(
                          widget.nailDesignId,
                        );
                      }),
                      icon: const Icon(Icons.refresh),
                      label: const Text('Thử lại'),
                    ),
                  ],
                ),
              ),
            );
          }
          return _DesignDetailContent(design: snapshot.data!);
        },
      ),
    );
  }
}

class _DesignDetailContent extends StatelessWidget {
  final NailDesignModel design;

  const _DesignDetailContent({required this.design});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
      children: [
        _ImageGallery(imageUrls: design.imageUrls),
        const SizedBox(height: 20),
        Text(
          design.name,
          style: const TextStyle(
            fontSize: 24, 
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${PriceFormatter.format(design.minPrice).replaceAll(' VNĐ', '')} - ${PriceFormatter.format(design.maxPrice)}',
          style: const TextStyle(
            color: Color(0xFFFF4081),
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        if (design.description.isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            design.description, 
            style: const TextStyle(
              height: 1.5,
              fontSize: 14,
              color: Colors.black87,
            ),
          ),
        ],
        if (design.categories.isNotEmpty) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: design.categories
                .map((category) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF5F5F7),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Text(
                        category.name,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ))
                .toList(),
          ),
        ],
        const SizedBox(height: 28),
        Row(
          children: [
            const Text(
              'Phiên bản móng',
              style: TextStyle(
                fontSize: 18, 
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                '${design.nailVariants.length}',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (design.nailVariants.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Hiện chưa có phiên bản nào cho thiết kế này.',
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
          )
        else
          for (final variant in design.nailVariants)
            _VariantSection(variant: variant, designName: design.name),
      ],
    );
  }
}

class _ImageGallery extends StatefulWidget {
  final List<String> imageUrls;

  const _ImageGallery({required this.imageUrls});

  @override
  State<_ImageGallery> createState() => _ImageGalleryState();
}

class _ImageGalleryState extends State<_ImageGallery> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    if (widget.imageUrls.isEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: AspectRatio(
          aspectRatio: 1.2,
          child: Container(
            color: const Color(0xFFF5F5F7),
            alignment: Alignment.center,
            child: const Icon(Icons.spa_rounded, size: 48, color: Colors.grey),
          ),
        ),
      );
    }

    return Column(
      children: [
        Container(
          height: 280,
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
            child: PageView.builder(
              itemCount: widget.imageUrls.length,
              onPageChanged: (index) {
                setState(() => _currentIndex = index);
              },
              itemBuilder: (context, index) {
                return Image.network(
                  widget.imageUrls[index],
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: const Color(0xFFF5F5F7),
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                  ),
                );
              },
            ),
          ),
        ),
        if (widget.imageUrls.length > 1) ...[
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              widget.imageUrls.length,
              (index) => Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: _currentIndex == index ? 16 : 6,
                height: 6,
                decoration: BoxDecoration(
                  color: _currentIndex == index ? AppColors.primary : Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
          ),
        ],
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
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFF0F5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
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
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: variant.imageUrl.isEmpty
                      ? Container(
                          color: const Color(0xFFF5F5F7),
                          child: const Icon(Icons.spa_rounded, color: Colors.grey),
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
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                    ),
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
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.chevron_right_rounded, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
