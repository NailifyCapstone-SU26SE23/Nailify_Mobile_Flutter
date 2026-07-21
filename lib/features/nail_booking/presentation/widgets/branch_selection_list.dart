import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import 'nearby_salon_map_dialog.dart';

class BranchSelectionList extends StatelessWidget {
  final List<dynamic> salons;
  final bool isLoading;
  final String? selectedBranchId;
  final Function(dynamic) onBranchSelected;
  final Function(dynamic)? onBranchConfirmedOnMap;

  const BranchSelectionList({
    super.key,
    required this.salons,
    required this.isLoading,
    required this.selectedBranchId,
    required this.onBranchSelected,
    this.onBranchConfirmedOnMap,
  });

  void _openNearbyMapSearch(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return FractionallySizedBox(
          heightFactor: 0.9,
          child: NearbySalonMapDialog(
            salons: salons,
            onBranchConfirmed: (branch) {
              if (onBranchConfirmedOnMap != null) {
                onBranchConfirmedOnMap!(branch);
              } else {
                onBranchSelected(branch);
              }
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 1. Sleek Search Nearby Button
        SizedBox(
          width: double.infinity,
          height: 48,
          child: ElevatedButton.icon(
            onPressed: salons.isEmpty ? null : () => _openNearbyMapSearch(context),
            icon: const Icon(Icons.near_me_rounded, color: Colors.white, size: 18),
            label: const Text('Tìm kiếm salon gần đây', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 2. Salon Cards list
        if (salons.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: Text('Không có chi nhánh nào.', style: TextStyle(color: Colors.grey))),
          )
        else
          ...salons.map((salon) {
            bool isSelected = selectedBranchId == salon['salonId'];

            return GestureDetector(
              onTap: () => onBranchSelected(salon),
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(
                    color: isSelected ? AppColors.primary : const Color(0xFFF3EFEA),
                    width: isSelected ? 1.8 : 1.2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.04)
                          : Colors.black.withValues(alpha: 0.01),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: isSelected ? const Color(0xFFFFF0F5) : const Color(0xFFFDFBF7),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: isSelected ? const Color(0xFFFFD1E1) : const Color(0xFFF3EFEA),
                        ),
                      ),
                      child: Icon(
                        Icons.storefront_rounded,
                        color: isSelected ? AppColors.primary : Colors.grey.shade600,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            salon['name'] ?? '',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            salon['address'] ?? '',
                            style: TextStyle(fontSize: 13, color: Colors.grey.shade500, height: 1.3),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    if (isSelected) ...[
                      const SizedBox(width: 8),
                      const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 24),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
      ],
    );
  }
}
