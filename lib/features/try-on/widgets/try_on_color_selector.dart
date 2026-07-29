import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
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
    '#FF66C4', // Primary Pink
    '#C44569', // Primary Dark
    '#FF3B30', // Apple Red
    '#FF9500', // Sunset Orange
    '#FFCC00', // Yellow
    '#4CD964', // Emerald Green
    '#5AC8FA', // Sky Blue
    '#007AFF', // Cobalt Blue
    '#5856D6', // Deep Purple
    '#FF2D55', // Rose Pink
    '#F5CBA7', // Elegant Nude
    '#FFFFFF', // Pure White
    '#000000', // Velvet Black
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
          const Text(
            'Chọn màu sắc',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppColors.primaryDark,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 12),
        ],
        _CustomSegmentedControl(
          gradientEnabled: gradientEnabled,
          onChanged: (isGradient) {
            if (isGradient) {
              onGradientChanged([selectedColor, selectedColor]);
            } else {
              onGradientChanged(null);
            }
          },
        ),
        const SizedBox(height: 16),
        // Beautiful Preview Box
        Container(
          height: 76,
          decoration: BoxDecoration(
            color: gradientEnabled ? null : parseTryOnHexColor(selectedColor),
            gradient: gradientEnabled
                ? LinearGradient(
                    colors: displayedColors.map(parseTryOnHexColor).toList(),
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  )
                : null,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: (gradientEnabled
                        ? parseTryOnHexColor(displayedColors.first)
                        : parseTryOnHexColor(selectedColor))
                    .withOpacity(0.18),
                blurRadius: 14,
                spreadRadius: 1,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(17.5),
            child: Stack(
              children: [
                // Glossy glass overlay
                Positioned.fill(
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withOpacity(0.2),
                          Colors.transparent,
                        ],
                        stops: const [0.3, 1.0],
                      ),
                    ),
                  ),
                ),
                // Text overlay display
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.25),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      gradientEnabled
                          ? 'Gradient: ${displayedColors.join(" → ")}'
                          : 'Màu đơn sắc: ${selectedColor.toUpperCase()}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        // Color Picker Preset Options
        if (!gradientEnabled)
          SizedBox(
            height: 56,
            child: ListView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              children: [
                _CustomColorButton(
                  initialColor: selectedColor,
                  onSelected: onColorSelected,
                ),
                for (final colorHex in _presetColors)
                  _ColorCircle(
                    colorHex: colorHex,
                    selected:
                        selectedColor.toLowerCase() == colorHex.toLowerCase(),
                    onTap: () => onColorSelected(colorHex),
                  ),
              ],
            ),
          )
        else ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
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
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  child: OutlinedButton.icon(
                    onPressed: () => onGradientChanged([
                      ...gradientStops!,
                      gradientStops!.last,
                    ]),
                    icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                    label: const Text(
                      'Thêm màu',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primaryLight, width: 1.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 14, color: Colors.grey.shade400),
              const SizedBox(width: 6),
              Text(
                'Chọn từ 2 đến 3 tông màu để chuyển sắc.',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade500, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ],
      ],
    );
  }
}

class _CustomSegmentedControl extends StatelessWidget {
  final bool gradientEnabled;
  final ValueChanged<bool> onChanged;

  const _CustomSegmentedControl({
    required this.gradientEnabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildSegmentButton(
              context,
              label: 'Màu đơn sắc',
              icon: Icons.circle_rounded,
              isActive: !gradientEnabled,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _buildSegmentButton(
              context,
              label: 'Gradient',
              icon: Icons.gradient_rounded,
              isActive: gradientEnabled,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isActive ? AppColors.primaryGradient : null,
          boxShadow: isActive
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.25),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 14,
              color: isActive ? Colors.white : Colors.grey.shade600,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 12.5,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w600,
                color: isActive ? Colors.white : Colors.grey.shade600,
              ),
            ),
          ],
        ),
      ),
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
      child: AnimatedScale(
        scale: selected ? 1.15 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Container(
          margin: const EdgeInsets.only(right: 10),
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.5,
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 6,
                      spreadRadius: 1,
                    )
                  ]
                : null,
          ),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
              border: Border.all(
                color: Colors.white,
                width: 2,
              ),
            ),
            child: selected
                ? Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: color.computeLuminance() > 0.6
                        ? Colors.black87
                        : Colors.white,
                  )
                : null,
          ),
        ),
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
    final color = parseTryOnHexColor(colorHex);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.only(top: 6, right: 6),
          child: InkWell(
            onTap: () => _showColorPicker(context, colorHex, onSelect),
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade200, width: 1.5),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.03),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.black12, width: 0.5),
                      boxShadow: [
                        BoxShadow(
                          color: color.withOpacity(0.2),
                          blurRadius: 4,
                          spreadRadius: 0.5,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  Text(
                    'Màu ${index + 1}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: 16,
                    color: Colors.grey.shade500,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (canRemove)
          Positioned(
            right: 0,
            top: 0,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 4,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.close_rounded,
                  size: 10,
                  color: Colors.white,
                ),
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
          shape: BoxShape.circle,
          gradient: const SweepGradient(
            colors: [
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue,
              Colors.purple,
              Colors.red,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.12),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(2.5),
        child: Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.colorize_rounded,
            color: AppColors.primaryDark,
            size: 18,
          ),
        ),
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
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28),
        ),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
        contentPadding: const EdgeInsets.symmetric(horizontal: 24),
        actionsPadding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: const BoxDecoration(
                color: AppColors.primarySurface,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.color_lens_rounded,
                color: AppColors.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Chọn màu sắc',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.primaryDark,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: _SaturationValuePicker(
                    color: selected,
                    onChanged: (value) {
                      setDialogState(() => selected = value);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),
              // Beautiful Custom Hue Track
              Container(
                height: 12,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
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
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 0,
                  overlayColor: Colors.transparent,
                  thumbColor: Colors.white,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 10.0,
                    elevation: 4.0,
                  ),
                ),
                child: Slider(
                  value: selected.hue,
                  max: 360,
                  onChanged: (hue) {
                    setDialogState(() => selected = selected.withHue(hue));
                  },
                ),
              ),
              const SizedBox(height: 8),
              // Spec Code Preview Box
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: selected.toColor(),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.black12, width: 0.5),
                        boxShadow: [
                          BoxShadow(
                            color: selected.toColor().withOpacity(0.25),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MÃ HEX COLOR',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w800,
                            color: Colors.grey.shade500,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _colorToHex(selected.toColor()),
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w900,
                            color: Colors.grey.shade800,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Hủy',
              style: TextStyle(
                color: Colors.grey.shade600,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, selected.toColor()),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Chọn',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
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
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
      Paint()
        ..shader = LinearGradient(
          colors: [
            Colors.white,
            HSVColor.fromAHSV(1, color.hue, 1, 1).toColor(),
          ],
        ).createShader(rect),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(16)),
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
    
    // Outer white glow for selector reticle
    canvas.drawCircle(
      indicator,
      12,
      Paint()
        ..color = Colors.black.withOpacity(0.12)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
    );
    
    canvas.drawCircle(indicator, 9, Paint()..color = Colors.white);
    canvas.drawCircle(
      indicator,
      7,
      Paint()..color = color.toColor(),
    );
    canvas.drawCircle(
      indicator,
      9,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white,
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