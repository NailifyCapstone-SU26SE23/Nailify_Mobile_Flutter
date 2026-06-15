import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/another_design_mock_data.dart';
import '../widgets/design_gallery_cta.dart';
import '../widgets/design_gallery_header.dart';
import '../widgets/design_grid_card.dart';
import '../widgets/design_grid_toolbar.dart';
import '../widgets/style_filter_bar.dart';

class AnotherDesignPage extends StatefulWidget {
  const AnotherDesignPage({super.key});

  @override
  State<AnotherDesignPage> createState() => _AnotherDesignPageState();
}

class _AnotherDesignPageState extends State<AnotherDesignPage> {
  String _selectedFilter = AnotherDesignMockData.styleFilters.first;
  String _selectedSort = AnotherDesignMockData.sortOptions.first;

  List<NailDesignItem> get _filteredDesigns {
    var result = List<NailDesignItem>.from(AnotherDesignMockData.designs);

    if (_selectedFilter != 'All styles') {
      result = result.where((d) => d.style == _selectedFilter).toList();
    }

    switch (_selectedSort) {
      case 'Oldest':
        result.sort((a, b) => a.sortDate.compareTo(b.sortDate));
      case 'A-Z':
        result.sort((a, b) => a.name.compareTo(b.name));
      case 'Newest':
      default:
        result.sort((a, b) => b.sortDate.compareTo(a.sortDate));
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final designs = _filteredDesigns;

    return Container(
      color: AppColors.background,
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 402),
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const DesignGalleryHeader(),
                const SizedBox(height: 24),
                StyleFilterBar(
                  filters: AnotherDesignMockData.styleFilters,
                  selectedFilter: _selectedFilter,
                  onFilterSelected: (filter) {
                    setState(() => _selectedFilter = filter);
                  },
                ),
                const SizedBox(height: 20),
                DesignGridToolbar(
                  designCount: designs.length,
                  selectedSort: _selectedSort,
                  sortOptions: AnotherDesignMockData.sortOptions,
                  onSortChanged: (value) {
                    if (value != null) setState(() => _selectedSort = value);
                  },
                ),
                const SizedBox(height: 16),
                _buildDesignGrid(designs),
                const SizedBox(height: 28),
                DesignGalleryCta(
                  onBookPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Booking feature coming soon.')),
                    );
                  },
                  onCustomPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Custom design feature coming soon.')),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesignGrid(List<NailDesignItem> designs) {
    if (designs.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40),
        child: Text(
          'No designs match this style.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
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
      itemCount: designs.length,
      itemBuilder: (context, index) {
        return DesignGridCard(design: designs[index]);
      },
    );
  }
}
