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
  final List<Map<String, dynamic>> _favorites = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _page = 1;
  bool _hasNextPage = false;

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
    } catch (error) {
      if (!mounted) return;
      setState(() => _favorites.insert(index, item));
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Không thể bỏ yêu thích: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text('Móng yêu thích'),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadFavorites(refresh: true),
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _MessageState(
                message: _errorMessage!,
                onRetry: () => _loadFavorites(refresh: true),
              )
            else if (_favorites.isEmpty)
              const _MessageState(message: 'Chưa có móng yêu thích.')
            else ...[
              ..._favorites.map(_buildFavoriteCard),
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFavoriteCard(Map<String, dynamic> favorite) {
    final design = _readMap(favorite['nailDesign']);
    final variant = _readMap(favorite['nailVariant']);
    final isVariant = variant.isNotEmpty;
    final source = isVariant ? variant : design;
    final title = source['name']?.toString() ?? 'Móng yêu thích';
    final imageUrl = (source['imageUrl'] ?? source['image'])?.toString() ?? '';
    final createdAt = _formatDateTime(favorite['createdAt']);
    final targetId = _readInt(
      isVariant ? source['nailVariantId'] : source['nailDesignId'],
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: targetId == null
            ? null
            : () => context.push(
                isVariant ? '/nail-variants/$targetId' : '/nails/$targetId',
              ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: imageUrl.isEmpty
                      ? Container(
                          color: const Color(0xFFF5F5F7),
                          child: const Icon(Icons.spa_rounded),
                        )
                      : Image.network(imageUrl, fit: BoxFit.cover),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isVariant ? 'Phiên bản' : 'Thiết kế',
                      style: const TextStyle(color: AppColors.primary),
                    ),
                    if (createdAt.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        createdAt,
                        style: const TextStyle(
                          color: Colors.grey,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: () => _unfavorite(favorite),
                icon: const Icon(Icons.favorite_rounded),
                color: AppColors.primary,
              ),
            ],
          ),
        ),
      ),
    );
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

class _MessageState extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const _MessageState({required this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Center(
        child: Column(
          children: [
            const Icon(
              Icons.favorite_border_rounded,
              size: 42,
              color: Colors.grey,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onRetry, child: const Text('Thử lại')),
            ],
          ],
        ),
      ),
    );
  }
}
