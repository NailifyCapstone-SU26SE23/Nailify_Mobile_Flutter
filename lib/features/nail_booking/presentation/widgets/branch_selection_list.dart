import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class BranchSelectionList extends StatelessWidget {
  final List<dynamic> salons;
  final bool isLoading;
  final String? selectedBranchId;
  final Function(dynamic) onBranchSelected;

  const BranchSelectionList({super.key, required this.salons, required this.isLoading, required this.selectedBranchId, required this.onBranchSelected});

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Center(child: CircularProgressIndicator());
    if (salons.isEmpty) return const Text('Không có chi nhánh nào.');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: salons.map((salon) {
        bool isSelected = selectedBranchId == salon['salonId'];
        return GestureDetector(
          onTap: () => onBranchSelected(salon),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
                border: Border.all(color: isSelected ? AppColors.primary : Colors.grey.shade300),
                borderRadius: BorderRadius.circular(12)
            ),
            child: Row(
              children: [
                const Icon(Icons.storefront, size: 30, color: AppColors.primary),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(salon['name'], style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: isSelected ? AppColors.primary : Colors.black)),
                      const SizedBox(height: 4),
                      Text(salon['address'], style: const TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
                if (isSelected) const Icon(Icons.check_circle, color: AppColors.primary),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}