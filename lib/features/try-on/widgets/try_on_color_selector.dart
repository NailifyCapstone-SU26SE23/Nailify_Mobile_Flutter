import 'package:flutter/material.dart';

import '../utils/try_on_setup_helpers.dart';

class TryOnColorSelector extends StatelessWidget {
  final String selectedColor;
  final ValueChanged<String> onColorSelected;
  final List<String>? gradientStops;
  final ValueChanged<List<String>?> onGradientChanged;
  final bool showTitle;

  const TryOnColorSelector({
    super.key,
    required this.selectedColor,
    required this.onColorSelected,
    required this.gradientStops,
    required this.onGradientChanged,
    this.showTitle = true,
  });

  static const _presetColors = [
    '#FF4081',
    '#FF0000',
    '#0000FF',
    '#F5CBA7',
    '#000000',
    '#FFFFFF',
    '#9C27B0',
    '#4CAF50',
    '#FFC107',
  ];

  @override
  Widget build(BuildContext context) {
    final gradientEnabled = gradientStops != null;
    final displayedColors = gradientEnabled
        ? gradientStops!
        : <String>[selectedColor];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (showTitle) ...[
          Text(
            'Select Color',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
        ],
        SegmentedButton<bool>(
          segments: const [
            ButtonSegment(
              value: false,
              icon: Icon(Icons.circle),
              label: Text('Solid'),
            ),
            ButtonSegment(
              value: true,
              icon: Icon(Icons.gradient),
              label: Text('Gradient'),
            ),
          ],
          selected: {gradientEnabled},
          onSelectionChanged: (selection) {
            if (selection.first) {
              onGradientChanged([selectedColor, selectedColor]);
            } else {
              onGradientChanged(null);
            }
          },
        ),
        const SizedBox(height: 14),
        Container(
          height: 64,
          decoration: BoxDecoration(
            color: gradientEnabled ? null : parseTryOnHexColor(selectedColor),
            gradient: gradientEnabled
                ? LinearGradient(
                    colors: displayedColors.map(parseTryOnHexColor).toList(),
                  )
                : null,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300),
          ),
        ),
        const SizedBox(height: 14),
        if (!gradientEnabled)
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final colorHex in _presetColors)
                  _ColorCircle(
                    colorHex: colorHex,
                    selected:
                        selectedColor.toLowerCase() == colorHex.toLowerCase(),
                    onTap: () => onColorSelected(colorHex),
                  ),
                _CustomColorButton(
                  initialColor: selectedColor,
                  onSelected: onColorSelected,
                ),
              ],
            ),
          )
        else ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (var index = 0; index < gradientStops!.length; index++)
                _GradientStopButton(
                  index: index,
                  colorHex: gradientStops![index],
                  canRemove: gradientStops!.length > 2,
                  onSelect: (color) {
                    final updated = [...gradientStops!];
                    updated[index] = color;
                    onGradientChanged(updated);
                  },
                  onRemove: () {
                    final updated = [...gradientStops!]..removeAt(index);
                    onGradientChanged(updated);
                  },
                ),
              if (gradientStops!.length < 3)
                OutlinedButton.icon(
                  onPressed: () => onGradientChanged([
                    ...gradientStops!,
                    gradientStops!.last,
                  ]),
                  icon: const Icon(Icons.add),
                  label: const Text('Add color'),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text(
            'Choose 2 or 3 colors.',
            style: TextStyle(fontSize: 12, color: Colors.grey),
          ),
        ],
      ],
    );
  }
}

class _ColorCircle extends StatelessWidget {
  final String colorHex;
  final bool selected;
  final VoidCallback onTap;

  const _ColorCircle({
    required this.colorHex,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = parseTryOnHexColor(colorHex);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        margin: const EdgeInsets.only(right: 12),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.purple : Colors.grey.shade300,
            width: selected ? 3 : 1,
          ),
        ),
        child: selected
            ? Icon(
                Icons.check,
                color: color.computeLuminance() > 0.5
                    ? Colors.black
                    : Colors.white,
              )
            : null,
      ),
    );
  }
}

class _GradientStopButton extends StatelessWidget {
  final int index;
  final String colorHex;
  final bool canRemove;
  final ValueChanged<String> onSelect;
  final VoidCallback onRemove;

  const _GradientStopButton({
    required this.index,
    required this.colorHex,
    required this.canRemove,
    required this.onSelect,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        OutlinedButton.icon(
          onPressed: () => _showColorPicker(context, colorHex, onSelect),
          icon: CircleAvatar(
            radius: 12,
            backgroundColor: parseTryOnHexColor(colorHex),
          ),
          label: Text('Color ${index + 1}'),
        ),
        if (canRemove)
          Positioned(
            right: -8,
            top: -10,
            child: InkWell(
              onTap: onRemove,
              child: const CircleAvatar(
                radius: 10,
                child: Icon(Icons.close, size: 14),
              ),
            ),
          ),
      ],
    );
  }
}

class _CustomColorButton extends StatelessWidget {
  final String initialColor;
  final ValueChanged<String> onSelected;

  const _CustomColorButton({
    required this.initialColor,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showColorPicker(context, initialColor, onSelected),
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
}

Future<void> _showColorPicker(
  BuildContext context,
  String initialColor,
  ValueChanged<String> onSelected,
) async {
  var selected = HSVColor.fromColor(parseTryOnHexColor(initialColor));
  final result = await showDialog<Color>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setDialogState) => AlertDialog(
        title: const Text('Choose color'),
        content: SizedBox(
          width: 300,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _SaturationValuePicker(
                color: selected,
                onChanged: (value) {
                  setDialogState(() => selected = value);
                },
              ),
              const SizedBox(height: 16),
              Container(
                height: 20,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  gradient: const LinearGradient(
                    colors: [
                      Colors.red,
                      Colors.yellow,
                      Colors.green,
                      Colors.cyan,
                      Colors.blue,
                      Colors.purple,
                      Colors.red,
                    ],
                  ),
                ),
              ),
              Slider(
                value: selected.hue,
                max: 360,
                onChanged: (hue) {
                  setDialogState(() => selected = selected.withHue(hue));
                },
              ),
              Container(
                height: 48,
                decoration: BoxDecoration(
                  color: selected.toColor(),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, selected.toColor()),
            child: const Text('Select'),
          ),
        ],
      ),
    ),
  );

  if (result != null) onSelected(_colorToHex(result));
}

class _SaturationValuePicker extends StatelessWidget {
  final HSVColor color;
  final ValueChanged<HSVColor> onChanged;

  const _SaturationValuePicker({required this.color, required this.onChanged});

  void _update(Offset position, Size size) {
    final saturation = (position.dx / size.width).clamp(0.0, 1.0);
    final value = (1 - position.dy / size.height).clamp(0.0, 1.0);
    onChanged(color.withSaturation(saturation).withValue(value));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, 200);
        return GestureDetector(
          onPanDown: (details) => _update(details.localPosition, size),
          onPanUpdate: (details) => _update(details.localPosition, size),
          child: CustomPaint(
            size: size,
            painter: _SaturationValuePainter(color),
          ),
        );
      },
    );
  }
}

class _SaturationValuePainter extends CustomPainter {
  final HSVColor color;

  const _SaturationValuePainter(this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white,
            HSVColor.fromAHSV(1, color.hue, 1, 1).toColor(),
          ],
        ).createShader(rect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(12)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.transparent, Colors.black],
        ).createShader(rect),
    );
    final indicator = Offset(
      color.saturation * size.width,
      (1 - color.value) * size.height,
    );
    canvas.drawCircle(indicator, 8, Paint()..color = Colors.white);
    canvas.drawCircle(
      indicator,
      8,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.black,
    );
  }

  @override
  bool shouldRepaint(covariant _SaturationValuePainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

String _colorToHex(Color color) {
  final value = color.toARGB32() & 0xFFFFFF;
  return '#${value.toRadixString(16).padLeft(6, '0').toUpperCase()}';
}
