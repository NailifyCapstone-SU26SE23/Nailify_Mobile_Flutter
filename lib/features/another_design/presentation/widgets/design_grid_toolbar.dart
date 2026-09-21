import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n_x.dart';

class DesignGridToolbar extends StatelessWidget {
  final int designCount;
  final String selectedSort;
  final List<String> sortOptions;
  final ValueChanged<String?> onSortChanged;
  final ValueChanged<String>? onSearchChanged;

  const DesignGridToolbar({
    super.key,
    required this.designCount,
    required this.selectedSort,
    required this.sortOptions,
    required this.onSortChanged,
    this.onSearchChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = _tryGetL10n(context);

    return Column(
      children: [
        // Search Input Box
        if (onSearchChanged != null) ...[
          Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight, width: 1),
              boxShadow: [
                BoxShadow(
                  color: AppColors.textPrimary.withValues(alpha: 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              onChanged: onSearchChanged,
              decoration: InputDecoration(
                hintText: l10n?.gallerySearchHint ?? 'Search designs...',
                hintStyle: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                prefixIcon: const Icon(
                  Icons.search_rounded,
                  color: AppColors.primary,
                  size: 20,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Toolbar Row: Count + Sort Dropdown
        Row(
          children: [
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  l10n?.galleryShowingCount(designCount) ??
                      'Showing $designCount designs',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const Spacer(),

            // Sort Dropdown Button
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.borderLight),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.textPrimary.withValues(alpha: 0.02),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: selectedSort,
                  isDense: true,
                  icon: const Icon(
                    Icons.sort_rounded,
                    size: 18,
                    color: AppColors.primary,
                  ),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                  items: sortOptions.map((option) {
                    String label = option;
                    if (option == 'Newest') {
                      label = l10n?.gallerySortNewest ?? 'Newest';
                    } else if (option == 'Oldest') {
                      label = l10n?.gallerySortOldest ?? 'Oldest';
                    } else if (option == 'A-Z') {
                      label = l10n?.gallerySortAZ ?? 'A - Z';
                    }
                    return DropdownMenuItem(
                      value: option,
                      child: Text(label),
                    );
                  }).toList(),
                  onChanged: onSortChanged,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  dynamic _tryGetL10n(BuildContext context) {
    try {
      return context.l10n;
    } catch (_) {
      return null;
    }
  }
}
