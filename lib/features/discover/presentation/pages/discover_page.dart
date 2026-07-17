import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

import '../../data/discover_data.dart';

import '../widgets/discover_explore_section.dart';

import '../widgets/discover_filter_sheet.dart';

import '../widgets/discover_hero_banner.dart';

import '../widgets/discover_nail_card.dart';

import '../widgets/discover_section_header.dart';

import '../widgets/discover_toolbar.dart';

import '../widgets/profile_suggestions_banner.dart';



class DiscoverPage extends StatefulWidget {

  const DiscoverPage({super.key});



  @override

  State<DiscoverPage> createState() => _DiscoverPageState();

}



class _DiscoverPageState extends State<DiscoverPage> {

  bool _isGridView = true;

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

    _resetFilters();

  }



  void _resetFilters() {

    _categories = Set.from(DiscoverMockData.initialCategories);

    _styles = Set.from(DiscoverMockData.initialStyles);

    _themes = Set.from(DiscoverMockData.initialThemes);

    _designs = Set.from(DiscoverMockData.initialDesigns);

    _variants = Set.from(DiscoverMockData.initialVariants);

    _details = Set.from(DiscoverMockData.initialDetails);

    _elements = Set.from(DiscoverMockData.initialElements);

    _occasions = Set.from(DiscoverMockData.initialOccasions);

  }



  List<DiscoverNailItem> get _filteredDesigns {

    return DiscoverMockData.filterDesigns(

      designs: DiscoverMockData.allDesigns,

      categories: _categories,

      styles: _styles,

      themes: _themes,

      selectedDesigns: _designs,

      variants: _variants,

      details: _details,

      elements: _elements,

      occasions: _occasions,

    );

  }



  void _openFilterMenu() {

    DiscoverFilterSheet.show(

      context,

      selectedCategories: _categories,

      selectedStyles: _styles,

      selectedThemes: _themes,

      selectedDesigns: _designs,

      selectedVariants: _variants,

      selectedDetails: _details,

      selectedElements: _elements,

      selectedOccasions: _occasions,

      onApply: (result) {

        setState(() {

          _categories = result.categories;

          _styles = result.styles;

          _themes = result.themes;

          _designs = result.designs;

          _variants = result.variants;

          _details = result.details;

          _elements = result.elements;

          _occasions = result.occasions;

        });

      },

      onClear: () => setState(_resetFilters),

    );

  }



  @override

  Widget build(BuildContext context) {

    final designs = _filteredDesigns;

    final exclusive = designs

        .where((d) => d.tier == DiscoverMatchTier.exclusive)

        .toList();

    final highlySuitable = designs

        .where((d) => d.tier == DiscoverMatchTier.highlySuitable)

        .toList();

    final explore = designs

        .where((d) => d.tier == DiscoverMatchTier.explore)

        .toList();



    return Container(

      color: AppColors.surfaceLight,

      child: SingleChildScrollView(

        physics: const BouncingScrollPhysics(),

        child: Center(

          child: Container(

            constraints: const BoxConstraints(maxWidth: 402),

            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [

                const DiscoverHeroBanner(),

                const SizedBox(height: 16),

                ProfileSuggestionsBanner(

                  onAiDesign: () {

                    ScaffoldMessenger.of(context).showSnackBar(

                      const SnackBar(content: Text('AI design coming soon.')),

                    );

                  },

                  onCustomNail: () {

                    ScaffoldMessenger.of(context).showSnackBar(

                      const SnackBar(content: Text('Custom nail coming soon.')),

                    );

                  },

                ),

                const SizedBox(height: 20),

                DiscoverToolbar(

                  designCount: designs.length,

                  isGridView: _isGridView,

                  onGridToggle: () => setState(() => _isGridView = !_isGridView),

                  onFilterPressed: _openFilterMenu,

                ),

                const SizedBox(height: 24),

                if (exclusive.isNotEmpty) ...[

                  const DiscoverSectionHeader(

                    badge: '✨ VERY SUITABLE',

                    title: 'Exclusively for you',

                    subtitle: 'Matches 90–100% of personalities',

                  ),

                  const SizedBox(height: 16),

                  _buildDesignGrid(exclusive),

                  const SizedBox(height: 28),

                ],

                if (highlySuitable.isNotEmpty) ...[

                  const DiscoverSectionHeader(

                    badge: '◆ HIGHLY SUITABLE',

                    title: 'You might also like',

                    subtitle: '65–89% personality match',

                    badgeColor: Color(0xFFFFF8E1),

                    badgeTextColor: Color(0xFF8D6E63),

                  ),

                  const SizedBox(height: 16),

                  _buildDesignGrid(highlySuitable),

                  const SizedBox(height: 28),

                ],

                DiscoverExploreSection(

                  featuredItem: explore.isNotEmpty ? explore.first : null,

                ),

              ],

            ),

          ),

        ),

      ),

    );

  }



  Widget _buildDesignGrid(List<DiscoverNailItem> items) {

    if (!_isGridView) {

      return Column(

        children: items

            .map(

              (item) => Padding(

                padding: const EdgeInsets.only(bottom: 12),

                child: SizedBox(

                  height: 220,

                  child: DiscoverNailCard(item: item),

                ),

              ),

            )

            .toList(),

      );

    }



    return GridView.builder(

      shrinkWrap: true,

      physics: const NeverScrollableScrollPhysics(),

      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(

        crossAxisCount: 2,

        crossAxisSpacing: 12,

        mainAxisSpacing: 12,

        childAspectRatio: 0.72,

      ),

      itemCount: items.length,

      itemBuilder: (context, index) => DiscoverNailCard(item: items[index]),

    );

  }

}


