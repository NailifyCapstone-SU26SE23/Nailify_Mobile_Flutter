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
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: 160,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: shapes.length,
            itemBuilder: (context, index) {
              final shape = shapes[index];
              final isSelected = selectedShape?.nailShapeId == shape.nailShapeId;

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
      child: Container(
        width: 120,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          border: Border.all(
            color: isSelected ? Colors.purple : Colors.grey.shade300,
            width: isSelected ? 2.5 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
          color: Colors.white,
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: Colors.purple.withAlpha(30),
              blurRadius: 8,
              offset: const Offset(0, 4),
            )
          ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Section
            Expanded(
              flex: 2,
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                child: shape.imageUrl.isNotEmpty
                    ? Image.network(
                  shape.imageUrl,
                  fit: BoxFit.cover,
                  width: double.infinity,
                  errorBuilder: (_, _, _) => const _FallbackIcon(),
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    );
                  },
                )
                    : const _FallbackIcon(),
              ),
            ),

            // Metadata Section (Name & Price)
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    shape.name,
                    style: TextStyle(
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                      fontSize: 13,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatPrice(shape.price),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.purple : Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPrice(double? price) {
    if (price == null) return 'Contact for price';
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
      child: Icon(
        Icons.search,
        size: 32,
        color: Colors.grey.shade400,
      ),
    );
  }
}
