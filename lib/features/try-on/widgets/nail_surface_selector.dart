import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../nails/data/models/nail_surface_model.dart';

class NailSurfaceSelector extends StatelessWidget {
  final List<NailSurfaceModel> surfaces;
  final NailSurfaceModel? selectedSurface;
  final ValueChanged<NailSurfaceModel> onSelected;

  const NailSurfaceSelector({
    super.key,
    required this.surfaces,
    required this.selectedSurface,
    required this.onSelected,
  });

  IconData _getSurfaceIcon(String shaderParam) {
    final param = shaderParam.toLowerCase();
    if (param.contains('matte')) return Icons.layers_clear_outlined;
    if (param.contains('gradient')) return Icons.gradient_outlined;
    if (param.contains('stripe')) return Icons.line_style_outlined;
    if (param.contains('rainbow')) return Icons.looks_outlined;
    if (param.contains('metallic')) return Icons.hdr_strong_outlined;
    if (param.contains('shine')) return Icons.light_mode_outlined;
    return Icons.auto_awesome_outlined;
  }

  String _formatPrice(double price) {
    if (price == 0) return 'Miễn phí';
    final formatter = NumberFormat.currency(
      locale: 'vi_VN',
      symbol: '₫',
      decimalDigits: 0,
    );
    return '+${formatter.format(price)}';
  }

  @override
  Widget build(BuildContext context) {
    if (surfaces.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Không có bề mặt móng nào khả dụng', style: TextStyle(color: Colors.grey)),
        ),
      );
    }

    return SizedBox(
      height: 100,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        itemCount: surfaces.length,
        itemBuilder: (context, index) {
          final surface = surfaces[index];
          final isSelected = selectedSurface?.nailSurfaceId == surface.nailSurfaceId;

          return GestureDetector(
            onTap: () => onSelected(surface),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 105,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white,
                    border: Border.all(
                      color: isSelected ? const Color(0xFFE91E63) : Colors.grey.shade200,
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
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        _getSurfaceIcon(surface.shaderParam),
                        color: isSelected ? const Color(0xFFE91E63) : Colors.grey.shade500,
                        size: 24,
                      ),
                      const SizedBox(height: 6),
                      Text(
                        surface.name,
                        style: TextStyle(
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 12,
                          color: isSelected ? const Color(0xFFE91E63) : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _formatPrice(surface.price),
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: isSelected ? const Color(0xFFC2185B) : Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (isSelected)
                  Positioned(
                    top: -4,
                    right: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE91E63),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.check,
                        color: Colors.white,
                        size: 8,
                      ),
                    ),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
