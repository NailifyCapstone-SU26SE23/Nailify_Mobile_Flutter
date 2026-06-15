import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/booking_mock_data.dart';

class BranchSelectionList extends StatelessWidget {
  final String? selectedBranchId;
  final Function(Map<String, String>) onBranchSelected;

  const BranchSelectionList({
    super.key,
    required this.selectedBranchId,
    required this.onBranchSelected,
  });

  @override
  Widget build(BuildContext context) {
    final branches = BookingMockData.branches;

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: branches.length,
      itemBuilder: (context, index) {
        final branch = branches[index];
        final bool isSelected = selectedBranchId == branch['id'];

        return GestureDetector(
          onTap: () => onBranchSelected(branch),
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.borderLight,
                width: isSelected ? 2 : 1,
              ),
              boxShadow: [
                if (isSelected)
                  BoxShadow(color: AppColors.primary.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, 4)),
              ],
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icon định vị
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.grey.shade100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.storefront, color: isSelected ? Colors.white : Colors.grey.shade600, size: 24),
                ),
                const SizedBox(width: 16),
                // Thông tin chi nhánh
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              branch['name']!,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 14),
                              const SizedBox(width: 4),
                              Text(branch['rating']!, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(branch['address']!, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.4)),
                      const SizedBox(height: 8),
                      // Row(
                      //   children: [
                      //     const Icon(Icons.near_me, size: 14, color: AppColors.primary),
                      //     const SizedBox(width: 4),
                      //     Text('Có 1 bà mẹ đơn thân Cách bạn ${branch['distance']}', style: const TextStyle(fontSize: 13, color: AppColors.primary, fontWeight: FontWeight.w500)),
                      //   ],
                      // ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}