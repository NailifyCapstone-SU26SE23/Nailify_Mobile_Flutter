import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class LengthSlider extends StatelessWidget {
  final double currentValue;
  final Function(double) onChanged;
  final String label;

  const LengthSlider({super.key, required this.currentValue, required this.onChanged, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
          decoration: BoxDecoration(color: AppColors.primary, borderRadius: BorderRadius.circular(20)),
          child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 20),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppColors.primary,
            inactiveTrackColor: Colors.grey.shade200,
            thumbColor: Colors.white,
            overlayColor: AppColors.primary.withOpacity(0.2),
            trackHeight: 8,
          ),
          child: Slider(
            value: currentValue,
            min: 0,
            max: 4,
            divisions: 4,
            onChanged: onChanged,
          ),
        ),
        // Các mốc text ở dưới
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Very Short', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Short', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Medium', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Long', style: TextStyle(fontSize: 10, color: Colors.grey)),
              Text('Very Long', style: TextStyle(fontSize: 10, color: Colors.grey)),
            ],
          ),
        )
      ],
    );
  }
}