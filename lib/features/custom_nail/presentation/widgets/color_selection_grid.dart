import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/custom_nail_mock_data.dart'; // Import file mock data

class ColorSelectionGrid extends StatefulWidget {
  final String selectedColor;
  final Function(String) onChanged;

  const ColorSelectionGrid({super.key, required this.selectedColor, required this.onChanged});

  @override
  State<ColorSelectionGrid> createState() => _ColorSelectionGridState();
}

class _ColorSelectionGridState extends State<ColorSelectionGrid> {
  String _selectedCategory = 'Solid';

  @override
  Widget build(BuildContext context) {
    // Gọi Map danh mục màu sắc từ file Mock Data
    final colorPalettes = CustomNailMockData.colorPalettes;
    final currentPalette = colorPalettes[_selectedCategory] ?? [];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: colorPalettes.keys.map((category) {
              bool isSelected = _selectedCategory == category;
              return Padding(
                padding: const EdgeInsets.only(right: 8.0),
                child: ChoiceChip(
                  label: Text(category),
                  selected: isSelected,
                  selectedColor: AppColors.primary.withOpacity(0.15),
                  backgroundColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? AppColors.primary : Colors.grey.shade600,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  ),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  ),
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedCategory = category;
                      });
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 24,
            childAspectRatio: 0.8,
          ),
          itemCount: currentPalette.length,
          itemBuilder: (context, index) {
            final colorItem = currentPalette[index];
            final String colorName = colorItem['name'];
            final Color colorValue = colorItem['color'];
            final bool isSelected = widget.selectedColor == colorName;

            return GestureDetector(
              onTap: () => widget.onChanged(colorName),
              child: Column(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: colorValue,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected ? AppColors.primary : Colors.grey.shade300,
                        width: isSelected ? 3 : 1,
                      ),
                      boxShadow: [
                        if (isSelected)
                          BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 4))
                      ],
                    ),
                    child: isSelected
                        ? Icon(Icons.check, color: colorValue.computeLuminance() > 0.5 ? Colors.black87 : Colors.white, size: 24)
                        : null,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    colorName,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: isSelected ? AppColors.textPrimary : Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}