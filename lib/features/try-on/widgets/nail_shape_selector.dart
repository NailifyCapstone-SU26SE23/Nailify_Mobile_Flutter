import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../nails/data/models/nail_shape_model.dart';

class NailShapeSelector extends StatelessWidget {
  final List<NailShapeModel> shapes;
  final NailShapeModel? selectedShape;
  final ValueChanged<NailShapeModel> onSelected;
  final bool showTitle;

  const NailShapeSelector({
    super.key,
    required this.shapes,
    required this.selectedShape,
    required this.onSelected,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            'Select Nail Shape',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: 120, // Compact height matching card design
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: shapes.length,
            itemBuilder: (context, index) {
              final shape = shapes[index];
              final isSelected =
                  selectedShape?.nailShapeId == shape.nailShapeId;

              return _NailShapeCard(
                shape: shape,
                isSelected: isSelected,
                onTap: () => onSelected(shape),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _NailShapeCard extends StatelessWidget {
  final NailShapeModel shape;
  final bool isSelected;
  final VoidCallback onTap;

  const _NailShapeCard({
    required this.shape,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 110,
            margin: const EdgeInsets.only(right: 12, top: 4, bottom: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: Colors.white,
              border: Border.all(
                color: isSelected
                    ? const Color(0xFFE91E63)
                    : Colors.grey.shade200,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? const Color(0xFFE91E63).withValues(alpha: 0.12)
                      : Colors.black.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Section
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(14),
                    ),
                    child: Container(
                      color: Colors.grey.shade50,
                      child: shape.imageUrl.isNotEmpty
                          ? Image.network(
                              shape.imageUrl,
                              fit: BoxFit.contain,
                              width: double.infinity,
                              errorBuilder: (_, _, _) => const _FallbackIcon(),
                              loadingBuilder:
                                  (context, child, loadingProgress) {
                                    if (loadingProgress == null) return child;
                                    return const Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 1.5,
                                        ),
                                      ),
                                    );
                                  },
                            )
                          : const _FallbackIcon(),
                    ),
                  ),
                ),

                // Metadata Section (Name & Price)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _translateName(context, shape.name),
                        style: TextStyle(
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.w500,
                          fontSize: 12,
                          color: isSelected
                              ? const Color(0xFFE91E63)
                              : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatPrice(context, shape.price),
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: isSelected
                              ? const Color(0xFFC2185B)
                              : Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (isSelected)
            Positioned(
              top: 0,
              right: 8,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Color(0xFFE91E63),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check, color: Colors.white, size: 10),
              ),
            ),
        ],
      ),
    );
  }

  String _translateName(BuildContext context, String name) {
    if (Localizations.localeOf(context).languageCode == 'en') {
      var result = name;
      result = result.replaceAll('Dài', 'Long');
      result = result.replaceAll('Ngắn', 'Short');
      result = result.replaceAll('Vừa', 'Medium');
      return result;
    }
    return name;
  }

  String _formatPrice(BuildContext context, double? price) {
    if (price == null) {
      return Localizations.localeOf(context).languageCode == 'en'
          ? 'Contact'
          : 'Liên hệ';
    }
    if (price == 0) {
      return Localizations.localeOf(context).languageCode == 'en'
          ? 'Free'
          : 'Miễn phí';
    }
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    if (isEn) {
      final formatter = NumberFormat.currency(
        locale: 'en_US',
        symbol: '\$',
        decimalDigits: 0,
      );
      return formatter.format(price);
    }
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return formatter.format(price);
  }
}

class _FallbackIcon extends StatelessWidget {
  const _FallbackIcon();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.grey.shade100,
      width: double.infinity,
      child: Icon(Icons.search, size: 32, color: Colors.grey.shade400),
    );
  }
}
