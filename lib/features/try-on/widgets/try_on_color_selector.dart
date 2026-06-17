import 'package:flutter/material.dart';

import '../utils/try_on_setup_helpers.dart';

class TryOnColorSelector extends StatelessWidget {
  final String selectedColor;
  final ValueChanged<String> onColorSelected;
  final bool showTitle;

  const TryOnColorSelector({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
    this.showTitle = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = [
      '#FF4081', // Pink
      '#FF0000', // Red
      '#0000FF', // Blue
      '#F5CBA7', // Nude
      '#000000', // Black
      '#FFFFFF', // White
      '#9C27B0', // Purple
      '#4CAF50', // Green
      '#FFC107', // Amber
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            'Select Color',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
        ],
        SizedBox(
          height: 50,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: colors.length + 1,
            itemBuilder: (context, index) {
              if (index == colors.length) {
                return _TryOnCustomColorButton(
                  selectedColor: selectedColor,
                  onColorSelected: onColorSelected,
                );
              }
              final colorHex = colors[index];
              final isSelected = selectedColor.toLowerCase() == colorHex.toLowerCase();
              final color = parseTryOnHexColor(colorHex);

              return GestureDetector(
                onTap: () => onColorSelected(colorHex),
                child: Container(
                  width: 44,
                  height: 44,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? Colors.purple : Colors.grey.shade300,
                      width: isSelected ? 3 : 1,
                    ),
                    boxShadow: isSelected
                        ? [
                            BoxShadow(
                              color: Colors.purple.withOpacity(0.3),
                              blurRadius: 6,
                              spreadRadius: 2,
                            )
                          ]
                        : null,
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check,
                          color: color.computeLuminance() > 0.5 ? Colors.black : Colors.white,
                          size: 20,
                        )
                      : null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TryOnCustomColorButton extends StatelessWidget {
  final String selectedColor;
  final ValueChanged<String> onColorSelected;

  const _TryOnCustomColorButton({
    required this.selectedColor,
    required this.onColorSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCustomColorDialog(context),
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: const Icon(Icons.colorize, color: Colors.grey),
      ),
    );
  }

  void _showCustomColorDialog(BuildContext context) {
    final controller = TextEditingController(text: selectedColor);
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Custom Color Hex'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: '#FF4081',
              border: OutlineInputBorder(),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                final text = controller.text.trim();
                if (text.isNotEmpty) {
                  onColorSelected(text);
                }
                Navigator.pop(context);
              },
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }
}
