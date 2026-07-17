import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/discover_data.dart';

class DiscoverFilterSheet extends StatefulWidget {
  final Set<String> selectedCategories;
  final Set<String> selectedStyles;
  final Set<String> selectedThemes;
  final Set<String> selectedDesigns;
  final Set<String> selectedVariants;
  final Set<String> selectedDetails;
  final Set<String> selectedElements;
  final Set<String> selectedOccasions;
  final ValueChanged<DiscoverFilterResult> onApply;
  final VoidCallback onClear;

  const DiscoverFilterSheet({
    super.key,
    required this.selectedCategories,
    required this.selectedStyles,
    required this.selectedThemes,
    required this.selectedDesigns,
    required this.selectedVariants,
    required this.selectedDetails,
    required this.selectedElements,
    required this.selectedOccasions,
    required this.onApply,
    required this.onClear,
  });

  static Future<void> show(
    BuildContext context, {
    required Set<String> selectedCategories,
    required Set<String> selectedStyles,
    required Set<String> selectedThemes,
    required Set<String> selectedDesigns,
    required Set<String> selectedVariants,
    required Set<String> selectedDetails,
    required Set<String> selectedElements,
    required Set<String> selectedOccasions,
    required ValueChanged<DiscoverFilterResult> onApply,
    required VoidCallback onClear,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => DiscoverFilterSheet(
        selectedCategories: Set.from(selectedCategories),
        selectedStyles: Set.from(selectedStyles),
        selectedThemes: Set.from(selectedThemes),
        selectedDesigns: Set.from(selectedDesigns),
        selectedVariants: Set.from(selectedVariants),
        selectedDetails: Set.from(selectedDetails),
        selectedElements: Set.from(selectedElements),
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
  final Set<String> categories;
  final Set<String> styles;
  final Set<String> themes;
  final Set<String> designs;
  final Set<String> variants;
  final Set<String> details;
  final Set<String> elements;
  final Set<String> occasions;

  const DiscoverFilterResult({
    required this.categories,
    required this.styles,
    required this.themes,
    required this.designs,
    required this.variants,
    required this.details,
    required this.elements,
    required this.occasions,
  });
}

class _DiscoverFilterSheetState extends State<DiscoverFilterSheet> {
  late Set<String> _categories;
  late Set<String> _styles;
  late Set<String> _themes;
  late Set<String> _designs;
  late Set<String> _variants;
  late Set<String> _details;
  late Set<String> _elements;
  late Set<String> _occasions;

  @override
  void initState() {
    super.initState();
    _categories = Set.from(widget.selectedCategories);
    _styles = Set.from(widget.selectedStyles);
    _themes = Set.from(widget.selectedThemes);
    _designs = Set.from(widget.selectedDesigns);
    _variants = Set.from(widget.selectedVariants);
    _details = Set.from(widget.selectedDetails);
    _elements = Set.from(widget.selectedElements);
    _occasions = Set.from(widget.selectedOccasions);
  }

  void _toggle(Set<String> set, String id) {
    setState(() {
      if (set.contains(id)) {
        set.remove(id);
      } else {
        set.add(id);
      }
    });
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
                    _buildFilterSection(
                      title: 'Category',
                      options: DiscoverMockData.categoryFilters,
                      selected: _categories,
                      onToggle: (id) => _toggle(_categories, id),
                    ),
                    _buildFilterSection(
                      title: 'Style',
                      options: DiscoverMockData.styleFilters,
                      selected: _styles,
                      onToggle: (id) => _toggle(_styles, id),
                    ),
                    _buildFilterSection(
                      title: 'Theme',
                      options: DiscoverMockData.themeFilters,
                      selected: _themes,
                      onToggle: (id) => _toggle(_themes, id),
                    ),
                    _buildFilterSection(
                      title: 'Design',
                      options: DiscoverMockData.designFilters,
                      selected: _designs,
                      onToggle: (id) => _toggle(_designs, id),
                    ),
                    _buildFilterSection(
                      title: 'Variant',
                      options: DiscoverMockData.variantFilters,
                      selected: _variants,
                      onToggle: (id) => _toggle(_variants, id),
                    ),
                    _buildFilterSection(
                      title: 'Detail',
                      options: DiscoverMockData.detailFilters,
                      selected: _details,
                      onToggle: (id) => _toggle(_details, id),
                    ),
                    _buildFilterSection(
                      title: 'Elements',
                      options: DiscoverMockData.elementFilters,
                      selected: _elements,
                      onToggle: (id) => _toggle(_elements, id),
                    ),
                    _buildOccasionSection(),
                    const SizedBox(height: 8),
                    OutlinedButton(
                      onPressed: () {
                        widget.onClear();
                        Navigator.pop(context);
                      },
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 48),
                        side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
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
                                categories: _categories,
                                styles: _styles,
                                themes: _themes,
                                designs: _designs,
                                variants: _variants,
                                details: _details,
                                elements: _elements,
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

  Widget _buildFilterSection({
    required String title,
    required List<DiscoverFilterOption> options,
    required Set<String> selected,
    required ValueChanged<String> onToggle,
    bool isLast = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(title),
        const SizedBox(height: 10),
        ...options.map((item) {
          final isSelected = selected.contains(item.id);
          return _FilterListTile(
            label: item.label,
            trailing: item.count > 0 ? '${item.count}' : null,
            selected: isSelected,
            onTap: () => onToggle(item.id),
          );
        }),
        SizedBox(height: isLast ? 16 : 20),
      ],
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title.toUpperCase(),
      style: const TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
        color: AppColors.textSecondary,
      ),
    );
  }

  Widget _buildOccasionSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle('Occasion of use'),
        const SizedBox(height: 10),
        ...DiscoverMockData.occasionFilters.map((occasion) {
          final selected = _occasions.contains(occasion.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () => _toggle(_occasions, occasion.id),
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
        const SizedBox(height: 16),
      ],
    );
  }
}

class _FilterListTile extends StatelessWidget {
  final String label;
  final String? trailing;
  final bool selected;
  final VoidCallback onTap;

  const _FilterListTile({
    required this.label,
    this.trailing,
    required this.selected,
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
                Icon(
                  selected ? Icons.check_box : Icons.check_box_outline_blank,
                  size: 18,
                  color: selected ? AppColors.primary : AppColors.border,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color:
                          selected ? AppColors.primary : AppColors.textPrimary,
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
