import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class DesignGridToolbar extends StatelessWidget {
  final int designCount;
  final String selectedSort;
  final List<String> sortOptions;
  final ValueChanged<String?> onSortChanged;

  const DesignGridToolbar({
    super.key,
    required this.designCount,
    required this.selectedSort,
    required this.sortOptions,
    required this.onSortChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          'Showing $designCount designs',
          style: const TextStyle(
            fontSize: 12,
            color: AppColors.textSecondary,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: selectedSort,
              isDense: true,
              icon: const Icon(Icons.keyboard_arrow_down, size: 18),
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textPrimary,
              ),
              items: sortOptions
                  .map(
                    (option) => DropdownMenuItem(
                      value: option,
                      child: Text(option),
                    ),
                  )
                  .toList(),
              onChanged: onSortChanged,
            ),
          ),
        ),
      ],
    );
  }
}
