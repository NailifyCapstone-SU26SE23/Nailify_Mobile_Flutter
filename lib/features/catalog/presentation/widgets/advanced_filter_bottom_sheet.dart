import 'package:flutter/material.dart';
import '../../data/models/catalog_mock_data.dart';

class AdvancedFilterBottomSheet extends StatefulWidget {
  // Nhận trạng thái bộ lọc hiện tại để duy trì UI khi mở lại bottom sheet
  final Map<String, Set<String>> initialFilters;

  const AdvancedFilterBottomSheet({super.key, required this.initialFilters});

  @override
  State<AdvancedFilterBottomSheet> createState() => _AdvancedFilterBottomSheetState();
}

class _AdvancedFilterBottomSheetState extends State<AdvancedFilterBottomSheet> {
  // Các Set lưu trữ tag đang được chọn
  late Set<String> _selectedStyles;
  late Set<String> _selectedThemes;
  late Set<String> _selectedDesigns;
  late Set<String> _selectedVariants;
  late Set<String> _selectedDetailElements;

  @override
  void initState() {
    super.initState();
    // Khởi tạo state bằng dữ liệu được truyền vào từ màn hình chính
    _selectedStyles = Set.from(widget.initialFilters['styles'] ?? {});
    _selectedThemes = Set.from(widget.initialFilters['themes'] ?? {});
    _selectedDesigns = Set.from(widget.initialFilters['designs'] ?? {});
    _selectedVariants = Set.from(widget.initialFilters['variants'] ?? {});
    _selectedDetailElements = Set.from(widget.initialFilters['detailElements'] ?? {});
  }

  void _clearFilters() {
    setState(() {
      _selectedStyles.clear();
      _selectedThemes.clear();
      _selectedDesigns.clear();
      _selectedVariants.clear();
      _selectedDetailElements.clear();
    });
  }

  Widget _buildFilterSection(String title, List<String> options, Set<String> selectedSet) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((option) {
            final isSelected = selectedSet.contains(option);
            return ChoiceChip(
              label: Text(option),
              selected: isSelected,
              selectedColor: const Color(0xFFFF66C4).withOpacity(0.2),
              backgroundColor: Colors.grey.shade100,
              labelStyle: TextStyle(
                color: isSelected ? const Color(0xFFFF66C4) : Colors.black87,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFFFF66C4) : Colors.transparent,
              ),
              onSelected: (selected) {
                setState(() {
                  selected ? selectedSet.add(option) : selectedSet.remove(option);
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Advanced Filter', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Flexible(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildFilterSection('Style', CatalogMockData.styles, _selectedStyles),
                  _buildFilterSection('Theme', CatalogMockData.themes, _selectedThemes),
                  _buildFilterSection('Design', CatalogMockData.designs, _selectedDesigns),
                  _buildFilterSection('Variants', CatalogMockData.variants, _selectedVariants),
                  _buildFilterSection('Detail Elements', CatalogMockData.detailElement, _selectedDetailElements),
                ],
              ),
            ),
          ),

          Row(
            children: [
              TextButton(
                onPressed: _clearFilters,
                child: const Text('Clear filter', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    // Trả dữ liệu filter về cho CatalogPage xử lý
                    Navigator.pop(context, {
                      'styles': _selectedStyles,
                      'themes': _selectedThemes,
                      'designs': _selectedDesigns,
                      'variants': _selectedVariants,
                      'detailElements': _selectedDetailElements,
                    });
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFF66C4),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Apply Filters', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}