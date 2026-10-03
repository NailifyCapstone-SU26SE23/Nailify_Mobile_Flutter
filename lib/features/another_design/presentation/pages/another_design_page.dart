import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n_x.dart';
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
  String _searchQuery = '';

  List<NailDesignItem> get _filteredDesigns {
    var result = List<NailDesignItem>.from(AnotherDesignMockData.designs);

    // Search query filter
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.trim().toLowerCase();
      result = result
          .where(
            (d) =>
                d.name.toLowerCase().contains(query) ||
                d.style.toLowerCase().contains(query),
          )
          .toList();
    }

    // Category style filter
    if (_selectedFilter != 'All styles') {
      result = result.where((d) => d.style == _selectedFilter).toList();
    }

    // Sort order
    switch (_selectedSort) {
      case 'Oldest':
        result.sort((a, b) => a.sortDate.compareTo(b.sortDate));
        break;
      case 'A-Z':
        result.sort((a, b) => a.name.compareTo(b.name));
        break;
      case 'Newest':
      default:
        result.sort((a, b) => b.sortDate.compareTo(a.sortDate));
        break;
    }

    return result;
  }

  @override
  Widget build(BuildContext context) {
    final designs = _filteredDesigns;
    final l10n = _tryGetL10n(context);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 500),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Hero Header Banner
                  const DesignGalleryHeader(),
                  const SizedBox(height: 20),

                  // 2. Horizontal Capsule Style Filter Bar
                  StyleFilterBar(
                    filters: AnotherDesignMockData.styleFilters,
                    selectedFilter: _selectedFilter,
                    onFilterSelected: (filter) {
                      setState(() => _selectedFilter = filter);
                    },
                  ),
                  const SizedBox(height: 18),

                  // 3. Search & Count Toolbar
                  DesignGridToolbar(
                    designCount: designs.length,
                    selectedSort: _selectedSort,
                    sortOptions: AnotherDesignMockData.sortOptions,
                    onSearchChanged: (val) {
                      setState(() => _searchQuery = val);
                    },
                    onSortChanged: (value) {
                      if (value != null) setState(() => _selectedSort = value);
                    },
                  ),
                  const SizedBox(height: 16),

                  // 4. Product Design Grid
                  _buildDesignGrid(designs, l10n),
                  const SizedBox(height: 28),

                  // 5. VIP AI Custom Studio CTA Card
                  DesignGalleryCta(
                    onBookPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Booking feature coming soon.'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    },
                    onCustomPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Custom design feature coming soon.'),
                          backgroundColor: AppColors.primaryDark,
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesignGrid(List<NailDesignItem> designs, dynamic l10n) {
    if (designs.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
        decoration: BoxDecoration(
          color: AppColors.primarySurface.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primaryLight),
        ),
        child: Column(
          children: [
            const Icon(
              Icons.search_off_rounded,
              size: 48,
              color: AppColors.primary,
            ),
            const SizedBox(height: 12),
            Text(
              l10n?.galleryNoDesigns ?? 'No designs match your criteria',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                setState(() {
                  _selectedFilter = AnotherDesignMockData.styleFilters.first;
                  _searchQuery = '';
                });
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reset filters'),
              style: TextButton.styleFrom(foregroundColor: AppColors.primary),
            ),
          ],
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
        childAspectRatio: 0.68,
      ),
      itemCount: designs.length,
      itemBuilder: (context, index) {
        return DesignGridCard(design: designs[index]);
      },
    );
  }

  dynamic _tryGetL10n(BuildContext context) {
    try {
      return context.l10n;
    } catch (_) {
      return null;
    }
  }
}
