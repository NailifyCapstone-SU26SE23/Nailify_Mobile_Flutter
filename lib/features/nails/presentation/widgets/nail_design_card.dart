import 'package:flutter/material.dart';

import '../../data/models/nail_design_model.dart';
import '../../../../core/utils/price_formatter.dart';

class NailDesignCard extends StatelessWidget {
  final NailDesignModel design;
  final VoidCallback onTap;
  final int? matchPercentage;

  const NailDesignCard({
    super.key,
    required this.design,
    required this.onTap,
    this.matchPercentage,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black12),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
                      child: design.primaryImageUrl.isEmpty
                          ? Container(
                              color: const Color(0xFFF7E8F1),
                              alignment: Alignment.center,
                              child: const Icon(Icons.spa_outlined, size: 32),
                            )
                          : Image.network(
                              design.primaryImageUrl,
                              width: double.infinity,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => Container(
                                color: const Color(0xFFF7E8F1),
                                alignment: Alignment.center,
                                child: const Icon(Icons.broken_image_outlined),
                              ),
                            ),
                    ),
                  ),
                  if (matchPercentage != null)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: const Color(0xFFFFD1E1), width: 0.5),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Text(
                          '$matchPercentage% match',
                          style: const TextStyle(
                            color: Color(0xFFFF66C4),
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(design.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text(
                    '${design.nailVariants.length} variants',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${PriceFormatter.format(design.minPrice).replaceAll(' VNĐ', '')} - ${PriceFormatter.format(design.maxPrice)}',
                    style: const TextStyle(color: Color(0xFFFF66C4), fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
