import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/custom_nail_mock_data.dart'; //mock data

class ShapeSelectionGrid extends StatelessWidget {
  final String selectedShape;
  final Function(String) onChanged;

  const ShapeSelectionGrid({super.key, required this.selectedShape, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    // gọi mock data
    final shapes = CustomNailMockData.shapes;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 15,
        mainAxisSpacing: 15,
        childAspectRatio: 0.85,
      ),
      itemCount: shapes.length,
      itemBuilder: (context, index) {
        bool isSelected = selectedShape == shapes[index];
        return GestureDetector(
          onTap: () => onChanged(shapes[index]),
          child: Container(
            decoration: BoxDecoration(
              color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: isSelected ? AppColors.primary : AppColors.borderLight, width: 2),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.whatshot_outlined, color: isSelected ? AppColors.primary : Colors.grey),
                const SizedBox(height: 8),
                Text(shapes[index], style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              ],
            ),
          ),
        );
      },
    );
  }
}