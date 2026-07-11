import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/discover_data.dart';

class DiscoverFilterSheet extends StatefulWidget {
  final Set<String> selectedPersonalities;
  final Set<String> selectedColors;
  final String selectedShape;
  final Set<String> selectedOccasions;
  final ValueChanged<DiscoverFilterResult> onApply;
  final VoidCallback onClear;

  const DiscoverFilterSheet({
    super.key,
    required this.selectedPersonalities,
    required this.selectedColors,
    required this.selectedShape,
    required this.selectedOccasions,
    required this.onApply,
    required this.onClear,
  });

  static Future<void> show(
    BuildContext context, {
    required Set<String> selectedPersonalities,
    required Set<String> selectedColors,
    required String selectedShape,
    required Set<String> selectedOccasions,
    required ValueChanged<DiscoverFilterResult> onApply,
    required VoidCallback onClear,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DiscoverFilterSheet(
        selectedPersonalities: Set.from(selectedPersonalities),
        selectedColors: Set.from(selectedColors),
        selectedShape: selectedShape,
        selectedOccasions: Set.from(selectedOccasions),
        onApply: onApply,
        onClear: onClear,
      ),
    );
  }

  @override
  State<DiscoverFilterSheet> createState() => _DiscoverFilterSheetState();
}

class DiscoverFilterResult {
  final Set<String> personalities;
  final Set<String> colors;
  final String shape;
  final Set<String> occasions;

  const DiscoverFilterResult({
    required this.personalities,
    required this.colors,
    required this.shape,
    required this.occasions,
  });
}

class _DiscoverFilterSheetState extends State<DiscoverFilterSheet> {
  late Set<String> _personalities;
  late Set<String> _colors;
  late String _shape;
  late Set<String> _occasions;

  @override
  void initState() {
    super.initState();
    _personalities = Set.from(widget.selectedPersonalities);
    _colors = Set.from(widget.selectedColors);
    _shape = widget.selectedShape;
    _occasions = Set.from(widget.selectedOccasions);
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.88,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.borderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 12, 0),
                child: Row(
                  children: [
                    const Text(
                      'Filter',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                  children: [
                    _sectionTitle('YOUR PERSONALITY'),
                    const SizedBox(height: 10),
                    ...DiscoverMockData.personalityFilters.map((item) {
                      final selected = _personalities.contains(item.id);
                      return _FilterListTile(
                        label: item.label,
                        trailing: '${item.count}',
                        selected: selected,
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _personalities.remove(item.id);
                            } else {
                              _personalities.add(item.id);
                            }
                          });
                        },
                      );
                    }),
                    const SizedBox(height: 20),
                    _sectionTitle('COLOR TONES'),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: DiscoverMockData.colorFilters.map((swatch) {
                        final selected = _colors.contains(swatch.id);
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _colors.remove(swatch.id);
                              } else {
                                _colors.add(swatch.id);
                              }
                            });
                          },
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: swatch.color,
                              gradient: swatch.gradientColors != null
                                  ? LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: swatch.gradientColors!,
                                    )
                                  : null,
                              border: selected
                                  ? Border.all(
                                      color: AppColors.primary,
                                      width: 3,
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('NAIL SHAPE'),
                    const SizedBox(height: 10),
                    ...DiscoverMockData.shapeFilters.map((shape) {
                      final selected = _shape == shape.id;
                      return _FilterListTile(
                        label: shape.label,
                        selected: selected,
                        showRadio: true,
                        onTap: () => setState(() => _shape = shape.id),
                      );
                    }),
                    const SizedBox(height: 20),
                    _sectionTitle('OCCASION OF USE'),
                    const SizedBox(height: 10),
                    ...DiscoverMockData.occasionFilters.map((occasion) {
                      final selected = _occasions.contains(occasion.id);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: GestureDetector(
                          onTap: () {
                            setState(() {
                              if (selected) {
                                _occasions.remove(occasion.id);
                              } else {
                                _occasions.add(occasion.id);
                              }
                            });
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: selected
                                  ? AppColors.primary.withOpacity(0.1)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.borderLight,
                              ),
                            ),
                            child: Text(
                              occasion.label,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: selected
                                    ? AppColors.primary
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      onPressed: () {
                        widget.onClear();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: BorderSide(
                          color: AppColors.primary.withOpacity(0.4),
                        ),
                        backgroundColor: AppColors.primary.withOpacity(0.06),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: const Text(
                        'Clear filter',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        gradient: AppColors.bannerGradient,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () {
                            widget.onApply(
                              DiscoverFilterResult(
                                personalities: _personalities,
                                colors: _colors,
                                shape: _shape,
                                occasions: _occasions,
                              ),
                            );
                            Navigator.pop(context);
                          },
                          borderRadius: BorderRadius.circular(24),
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              'Apply filter',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      ),
    );
  }
}

class _FilterListTile extends StatelessWidget {
  final String label;
  final String? trailing;
  final bool selected;
  final bool showRadio;
  final VoidCallback onTap;

  const _FilterListTile({
    required this.label,
    this.trailing,
    required this.selected,
    this.showRadio = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: selected
                  ? AppColors.primary.withOpacity(0.1)
                  : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: selected
                    ? AppColors.primary.withOpacity(0.3)
                    : AppColors.borderLight,
              ),
            ),
            child: Row(
              children: [
                if (showRadio)
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_off,
                    size: 18,
                    color: selected ? AppColors.primary : AppColors.border,
                  ),
                if (showRadio) const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textPrimary,
                    ),
                  ),
                ),
                if (trailing != null)
                  Text(
                    trailing!,
                    style: TextStyle(
                      fontSize: 13,
                      color: selected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
