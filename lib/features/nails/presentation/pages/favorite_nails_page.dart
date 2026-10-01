import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';

import '../../data/repositories/favorite_nail_repository.dart';

class FavoriteNailsPage extends StatefulWidget {
  const FavoriteNailsPage({super.key});

  @override
  State<FavoriteNailsPage> createState() => _FavoriteNailsPageState();
}

class _FavoriteNailsPageState extends State<FavoriteNailsPage> {
  final FavoriteNailRepository _repository = getIt<FavoriteNailRepository>();
  final ScrollController _scrollController = ScrollController();
  final TextEditingController _searchController = TextEditingController();

  final List<Map<String, dynamic>> _favorites = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _page = 1;
  bool _hasNextPage = false;
  bool _isGridView = true; // Toggle between Grid (default) and List view
  String _selectedFilter = 'ALL'; // 'ALL', 'VARIANT', 'DESIGN'
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadFavorites(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.extentAfter < 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (!_hasNextPage || _isLoadingMore || _isLoading) return;
    await _loadFavorites(refresh: false);
  }

  Future<void> _loadFavorites({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _page = 1;
        _hasNextPage = false;
        _favorites.clear();
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      final result = await _repository.getFavoriteNails(
        page: refresh ? 1 : _page + 1,
      );
      if (!mounted) return;
      setState(() {
        _favorites.addAll(result.items);
        _page = result.page;
        _hasNextPage = result.hasNextPage;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _unfavorite(Map<String, dynamic> item) async {
    final favoriteNailId = _readInt(item['favoriteNailId']);
    if (favoriteNailId == null) return;
    final index = _favorites.indexOf(item);

    setState(() => _favorites.removeAt(index));

    try {
      await _repository.unfavorite(favoriteNailId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Row(
            children: [
              Icon(Icons.heart_broken_rounded, color: Colors.white, size: 18),
              SizedBox(width: 8),
              Text('Đã xóa khỏi danh sách yêu thích'),
            ],
          ),
          backgroundColor: Colors.grey.shade800,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _favorites.insert(index, item));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Không thể bỏ yêu thích: $error'),
          backgroundColor: Colors.red.shade600,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  List<Map<String, dynamic>> get _filteredFavorites {
    return _favorites.where((item) {
      final isVariant = _readMap(item['nailVariant']).isNotEmpty;
      if (_selectedFilter == 'VARIANT' && !isVariant) return false;
      if (_selectedFilter == 'DESIGN' && isVariant) return false;

      if (_searchQuery.isNotEmpty) {
        final source = isVariant
            ? _readMap(item['nailVariant'])
            : _readMap(item['nailDesign']);
        final title = (source['name']?.toString() ?? '').toLowerCase();
        if (!title.contains(_searchQuery.toLowerCase())) return false;
      }
      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredFavorites;

    return Scaffold(
      backgroundColor: const Color(0xFFFAFAFB),
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18, color: AppColors.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Móng yêu thích',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            if (!_isLoading && _favorites.isNotEmpty) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFFD1DC)),
                ),
                child: Text(
                  '${_favorites.length}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFE02B6D),
                  ),
                ),
              ),
            ],
          ],
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        actions: [
          IconButton(
            tooltip: _isGridView ? 'Xem dạng danh sách' : 'Xem dạng lưới',
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: AppColors.primary,
              size: 22,
            ),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          // ── SEARCH & FILTER HEADER BAR ──────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                // Thanh tìm kiếm
                Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey.shade200),
                  ),
                  child: TextField(
                    controller: _searchController,
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    style: const TextStyle(fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'Tìm kiếm mẫu móng yêu thích...',
                      hintStyle: TextStyle(fontSize: 13, color: Colors.grey.shade500),
                      prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Colors.grey),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? GestureDetector(
                              onTap: () {
                                _searchController.clear();
                                setState(() => _searchQuery = '');
                              },
                              child: const Icon(Icons.cancel_rounded, size: 18, color: Colors.grey),
                            )
                          : null,
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                  ),
                ),
                const SizedBox(height: 10),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('Tất cả', 'ALL'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Thiết kế', 'DESIGN'),
                      const SizedBox(width: 8),
                      _buildFilterChip('Phiên bản mẫu', 'VARIANT'),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: Color(0xFFF0F0F0)),

          // ── MAIN CONTENT LIST / GRID ─────────────────────────────────────────
          Expanded(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: () => _loadFavorites(refresh: true),
              child: _isLoading
                  ? _buildSkeletonLoading()
                  : _errorMessage != null
                      ? _buildErrorState()
                      : filtered.isEmpty
                          ? _buildEmptyState()
                          : CustomScrollView(
                              controller: _scrollController,
                              physics: const AlwaysScrollableScrollPhysics(),
                              slivers: [
                                const SliverToBoxAdapter(child: SizedBox(height: 12)),
                                if (_isGridView)
                                  SliverPadding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    sliver: SliverGrid(
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 2,
                                        mainAxisSpacing: 14,
                                        crossAxisSpacing: 14,
                                        childAspectRatio: 0.78,
                                      ),
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) => _buildGridCard(filtered[index]),
                                        childCount: filtered.length,
                                      ),
                                    ),
                                  )
                                else
                                  SliverPadding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    sliver: SliverList(
                                      delegate: SliverChildBuilderDelegate(
                                        (context, index) => _buildListCard(filtered[index]),
                                        childCount: filtered.length,
                                      ),
                                    ),
                                  ),
                                if (_isLoadingMore)
                                  const SliverToBoxAdapter(
                                    child: Padding(
                                      padding: EdgeInsets.all(20),
                                      child: Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SliverToBoxAdapter(child: SizedBox(height: 24)),
                              ],
                            ),
            ),
          ),
        ],
      ),
    );
  }

  // ── FILTER CHIP WIDGET ──────────────────────────────────────────────────────
  Widget _buildFilterChip(String label, String key) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFFFFF0F5) : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? const Color(0xFFFFB6C1) : Colors.transparent,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? const Color(0xFFE02B6D) : Colors.grey.shade700,
          ),
        ),
      ),
    );
  }

  // ── GRID ITEM CARD ─────────────────────────────────────────────────────────
  Widget _buildGridCard(Map<String, dynamic> favorite) {
    final design = _readMap(favorite['nailDesign']);
    final variant = _readMap(favorite['nailVariant']);
    final isVariant = variant.isNotEmpty;
    final source = isVariant ? variant : design;
    final title = source['name']?.toString() ?? 'Móng nghệ thuật';
    final imageUrl = _getCleanImageUrl(source);
    final targetId = _readInt(
      isVariant
          ? (source['nailVariantId'] ?? source['NailVariantId'])
          : (source['nailDesignId'] ?? source['NailDesignId']),
    );



    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: targetId == null
            ? null
            : () => context.push(
                  isVariant ? '/nail-variants/$targetId' : '/nails/$targetId',
                ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image Stack Container
            Expanded(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: imageUrl.isEmpty
                        ? Container(
                            color: const Color(0xFFFFF0F5),
                            child: const Center(
                              child: Icon(Icons.spa_rounded, size: 36, color: AppColors.primary),
                            ),
                          )
                        : Image.network(
                            imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: const Color(0xFFFFF0F5),
                              child: const Icon(Icons.broken_image_rounded, color: AppColors.primary),
                            ),
                          ),
                  ),

                  // Tag type (Thiết kế / Phiên bản)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        isVariant ? 'Phiên bản' : 'Thiết kế',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  // Heart Unfavorite Button
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () => _unfavorite(favorite),
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.9),
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.favorite_rounded,
                          color: Color(0xFFE02B6D),
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Card Information
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 13.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFF0F5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Color(0xFFE02B6D),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── LIST ITEM CARD ─────────────────────────────────────────────────────────
  Widget _buildListCard(Map<String, dynamic> favorite) {
    final design = _readMap(favorite['nailDesign']);
    final variant = _readMap(favorite['nailVariant']);
    final isVariant = variant.isNotEmpty;
    final source = isVariant ? variant : design;
    final title = source['name']?.toString() ?? 'Móng nghệ thuật';
    final imageUrl = _getCleanImageUrl(source);
    final createdAt = _formatDateTime(favorite['createdAt']);
    final targetId = _readInt(
      isVariant
          ? (source['nailVariantId'] ?? source['NailVariantId'])
          : (source['nailDesignId'] ?? source['NailDesignId']),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0F0F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: targetId == null
            ? null
            : () => context.push(
                  isVariant ? '/nail-variants/$targetId' : '/nails/$targetId',
                ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              // Image Thumbnail
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 84,
                  height: 84,
                  child: imageUrl.isEmpty
                      ? Container(
                          color: const Color(0xFFFFF0F5),
                          child: const Icon(Icons.spa_rounded, color: AppColors.primary, size: 28),
                        )
                      : Image.network(
                          imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) => Container(
                            color: const Color(0xFFFFF0F5),
                            child: const Icon(Icons.broken_image_rounded, color: AppColors.primary),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 14),

              // Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F5),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isVariant ? 'Phiên bản' : 'Thiết kế',
                            style: const TextStyle(
                              color: Color(0xFFE02B6D),
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (createdAt.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Text(
                            createdAt,
                            style: TextStyle(
                              color: Colors.grey.shade500,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14.5,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

              // Actions
              IconButton(
                onPressed: () => _unfavorite(favorite),
                icon: const Icon(Icons.favorite_rounded),
                color: const Color(0xFFE02B6D),
                iconSize: 22,
                tooltip: 'Bỏ yêu thích',
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── EMPTY STATE WIDGET ──────────────────────────────────────────────────────
  Widget _buildEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: const BoxDecoration(
                color: Color(0xFFFFF0F5),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.favorite_outline_rounded,
                size: 46,
                color: Color(0xFFE02B6D),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Không tìm thấy mẫu móng'
                  : 'Chưa có mẫu móng yêu thích',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _searchQuery.isNotEmpty
                  ? 'Không có kết quả phù hợp với từ khóa "$_searchQuery".'
                  : 'Hãy khám phá bộ sưu tập mẫu móng xinh và bấm tim để lưu lại thiết kế bạn ưng ý nhé!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            if (_searchQuery.isEmpty)
              SizedBox(
                height: 44,
                child: ElevatedButton.icon(
                  onPressed: () => context.go('/nails'),
                  icon: const Icon(Icons.explore_rounded, size: 18),
                  label: const Text('Khám phá Mẫu Móng', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── ERROR STATE WIDGET ──────────────────────────────────────────────────────
  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline_rounded, size: 48, color: Colors.redAccent),
            const SizedBox(height: 12),
            Text(
              _errorMessage ?? 'Đã xảy ra lỗi khi tải dữ liệu.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: () => _loadFavorites(refresh: true),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppColors.primary),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('Thử lại', style: TextStyle(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }

  // ── SKELETON SHIMMER LOADING ────────────────────────────────────────────────
  Widget _buildSkeletonLoading() {
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.65,
      ),
      itemCount: 6,
      itemBuilder: (context, index) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFF0F0F0)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(height: 12, width: 100, color: Colors.grey.shade200),
                    const SizedBox(height: 8),
                    Container(height: 14, width: 60, color: Colors.grey.shade200),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ── HELPERS ────────────────────────────────────────────────────────────────
  String _getCleanImageUrl(Map<String, dynamic> source) {
    final imageUrls = source['imageUrls'] ?? source['ImageUrls'];
    String imageUrl = (source['imageUrl'] ??
            source['ImageUrl'] ??
            source['primaryImageUrl'] ??
            source['PrimaryImageUrl'] ??
            source['image'] ??
            '')
        .toString()
        .trim();

    if (imageUrl.isEmpty && imageUrls is List && imageUrls.isNotEmpty) {
      imageUrl = imageUrls.first.toString().trim();
    }
    return imageUrl;
  }

  Map<String, dynamic> _readMap(dynamic value) {
    if (value is Map) return Map<String, dynamic>.from(value);
    return const <String, dynamic>{};
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  String _formatDateTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }
}
