import 'package:flutter/material.dart';

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
        padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.viewInsetsOf(context).bottom + 20),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.82),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Expanded(child: Text('Filter designs', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700))),
                  IconButton(tooltip: 'Close', onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Design name',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Categories', style: TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Expanded(
                child: widget.categoryTypes.isEmpty
                    ? const Center(child: Text('No categories available.'))
                    : ListView.separated(
                        itemCount: widget.categoryTypes.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final type = widget.categoryTypes[index];
                          final activeCategories = type.categories.where((category) => category.status.toLowerCase() != 'inactive').toList();
                          if (activeCategories.isEmpty) return const SizedBox.shrink();
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(type.name, style: const TextStyle(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: activeCategories.map((category) {
                                  final selected = _selectedCategoryIds.contains(category.categoryId);
                                  return FilterChip(
                                    label: Text(category.name),
                                    selected: selected,
                                    onSelected: (value) {
                                      setState(() {
                                        if (value) {
                                          _selectedCategoryIds.add(category.categoryId);
                                        } else {
                                          _selectedCategoryIds.remove(category.categoryId);
                                        }
                                      });
                                    },
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
                    child: OutlinedButton(onPressed: () => Navigator.pop(context, const NailFilters()), child: const Text('Reset')),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        Navigator.pop(
                          context,
                          NailFilters(
                            name: _nameController.text.trim(),
                            categoryIds: _selectedCategoryIds.toList(),
                          ),
                        );
                      },
                      child: const Text('Apply'),
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
