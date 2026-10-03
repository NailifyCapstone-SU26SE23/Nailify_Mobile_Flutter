import 'package:flutter/material.dart';

class TryOnFingerSelector extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const TryOnFingerSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    const fingers = [
      MapEntry(-1, 'All'),
      MapEntry(1, 'Thumb'),
      MapEntry(2, 'Index'),
      MapEntry(3, 'Middle'),
      MapEntry(4, 'Ring'),
      MapEntry(5, 'Pinky'),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final finger in fingers)
          ChoiceChip(
            label: Text(finger.value),
            selected: value == finger.key,
            onSelected: (_) => onChanged(finger.key),
          ),
      ],
    );
  }
}
