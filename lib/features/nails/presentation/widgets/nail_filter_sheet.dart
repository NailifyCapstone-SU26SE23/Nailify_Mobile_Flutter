import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/category_type_model.dart';
import '../../data/models/nail_filters.dart';

class NailFilterSheet extends StatefulWidget {
  final NailFilters initialFilters;
  final List<CategoryTypeModel> categoryTypes;

  const NailFilterSheet({
    super.key,
    required this.initialFilters,
    required this.categoryTypes,
  });

  @override
  State<NailFilterSheet> createState() => _NailFilterSheetState();
}

class _NailFilterSheetState extends State<NailFilterSheet> {
  final _nameController = TextEditingController();
  late final Set<int> _selectedCategoryIds;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.initialFilters.name ?? '';
    _selectedCategoryIds = widget.initialFilters.categoryIds.toSet();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.82,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Bộ lọc thiết kế',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Đóng',
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(
                      Icons.close_rounded,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                autofocus: false,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                ),
                decoration: InputDecoration(
                  labelText: 'Tên thiết kế',
                  labelStyle: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 13,
                  ),
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                    color: AppColors.textSecondary,
                    size: 20,
                  ),
                  filled: true,
                  fillColor: const Color(0xFFF5F5F7),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Danh mục',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: widget.categoryTypes.isEmpty
                    ? const Center(
                        child: Text(
                          'Không có danh mục nào.',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      )
                    : ListView.separated(
                        itemCount: widget.categoryTypes.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 18),
                        itemBuilder: (context, index) {
                          final type = widget.categoryTypes[index];
                          final activeCategories = type.categories
                              .where(
                                (category) =>
                                    category.status.toLowerCase() != 'inactive',
                              )
                              .toList();
                          if (activeCategories.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type.name,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: activeCategories.map((category) {
                                  final selected = _selectedCategoryIds
                                      .contains(category.categoryId);
                                  return FilterChip(
                                    label: Text(category.name),
                                    selected: selected,
                                    onSelected: (value) {
                                      setState(() {
                                        if (value) {
                                          _selectedCategoryIds.add(
                                            category.categoryId,
                                          );
                                        } else {
                                          _selectedCategoryIds.remove(
                                            category.categoryId,
                                          );
                                        }
                                      });
                                    },
                                    selectedColor: AppColors.primary.withValues(
                                      alpha: 0.12,
                                    ),
                                    checkmarkColor: AppColors.primary,
                                    backgroundColor: const Color(0xFFF5F5F7),
                                    labelStyle: TextStyle(
                                      color: selected
                                          ? AppColors.primary
                                          : AppColors.textPrimary,
                                      fontWeight: selected
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 13,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(30),
                                      side: BorderSide(
                                        color: selected
                                            ? AppColors.primary
                                            : Colors.transparent,
                                        width: 1.2,
                                      ),
                                    ),
                                    showCheckmark: false,
                                    materialTapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                      vertical: 4,
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        side: const BorderSide(
                          color: Color(0xFFE0E0E0),
                          width: 1.2,
                        ),
                      ),
                      onPressed: () =>
                          Navigator.pop(context, const NailFilters()),
                      child: const Text(
                        'Đặt lại',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      onPressed: () {
                        Navigator.pop(
                          context,
                          NailFilters(
                            name: _nameController.text.trim(),
                            categoryIds: _selectedCategoryIds.toList(),
                          ),
                        );
                      },
                      child: const Text(
                        'Áp dụng',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
