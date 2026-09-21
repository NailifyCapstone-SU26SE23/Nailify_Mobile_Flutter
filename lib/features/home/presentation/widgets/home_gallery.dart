import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/di/injection.dart';
import '../../../../core/utils/auth_guard.dart';
import '../../../../generated/l10n.dart';
import '../../../nails/data/repositories/favorite_nail_repository.dart';
import '../../data/models/home_data_models.dart';
import '../cubit/home_cubit.dart';

/// Khối Nail Gallery dạng Vuốt Ngang (Horizontal ListView):
/// - Thẻ ảnh tỉ lệ 4:5 thời thượng, bo góc mượt 16px
/// - Hỗ trợ nạp dữ liệu động từ API hoặc danh sách mặc định
class HomeGallery extends StatefulWidget {
  final List<HomeGalleryItem> items;
  final bool isLoading;

  const HomeGallery({
    super.key,
    this.items = const [],
    this.isLoading = false,
  });

  @override
  State<HomeGallery> createState() => _HomeGalleryState();
}

class _HomeGalleryState extends State<HomeGallery> {
  final Map<int, HomeGalleryItem> _itemsMap = {};

  @override
  void initState() {
    super.initState();
    _syncItems();
  }

  @override
  void didUpdateWidget(covariant HomeGallery oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.items != widget.items) {
      _syncItems();
    }
  }

  void _syncItems() {
    for (final item in widget.items) {
      _itemsMap[item.id] = item;
    }
  }

  Future<void> _toggleFavorite(HomeGalleryItem item) async {
    AuthGuard.check(context, () async {
      final previousItem = _itemsMap[item.id] ?? item;
      final shouldFavorite = !previousItem.isFavorite;

      setState(() {
        _itemsMap[item.id] = previousItem.copyWith(
          isFavorite: shouldFavorite,
          clearFavoriteNailId: !shouldFavorite,
        );
      });

      try {
        if (shouldFavorite) {
          final favoriteNailId = await getIt<FavoriteNailRepository>()
              .favoriteDesign(item.id);
          if (mounted) {
            final updated = previousItem.copyWith(
              isFavorite: true,
              favoriteNailId: favoriteNailId,
            );
            setState(() {
              _itemsMap[item.id] = updated;
            });
            context.read<HomeCubit>().updateFavoriteGalleryItem(
                  nailDesignId: item.id,
                  isFavorited: true,
                  favoriteNailId: favoriteNailId,
                );
          }
        } else {
          final favId = previousItem.favoriteNailId;
          if (favId != null) {
            await getIt<FavoriteNailRepository>().unfavorite(favId);
          }
          if (mounted) {
            final updated = previousItem.copyWith(
              isFavorite: false,
              clearFavoriteNailId: true,
            );
            setState(() {
              _itemsMap[item.id] = updated;
            });
            context.read<HomeCubit>().updateFavoriteGalleryItem(
                  nailDesignId: item.id,
                  isFavorited: false,
                );
          }
        }
      } catch (error) {
        if (mounted) {
          setState(() {
            _itemsMap[item.id] = previousItem;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Không thể cập nhật yêu thích: $error')),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading && widget.items.isEmpty) {
      return _buildSkeleton(context);
    }

    final List<HomeGalleryItem> baseItems = widget.items;
    /*
    final List<HomeGalleryItem> baseItems = widget.items.isNotEmpty
        ? widget.items
        : const [
            HomeGalleryItem(id: 1, title: 'Hoa Anh Đào', imageUrl: 'assets/images/Rectangle 1.png'),
            HomeGalleryItem(id: 2, title: 'Gel Kim Tuyến', imageUrl: 'assets/images/Rectangle 2.png'),
            HomeGalleryItem(id: 3, title: 'Ombre Hồng San Hô', imageUrl: 'assets/images/home-mid.jpg'),
            HomeGalleryItem(id: 4, title: 'Art Đính Đá Nổi', imageUrl: 'assets/images/image.png'),
          ];
    */

    if (baseItems.isEmpty) {
      return const SizedBox.shrink();
    }

    final displayItems = baseItems
        .map((item) => _itemsMap[item.id] ?? item)
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tiêu đề khối Gallery + nút Xem tất cả
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.auto_awesome,
                    color: Color(0xFFFF4B72),
                    size: 18,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    S.of(context).nailGalleryTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFFE02B6D),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.push('/nails'),
                child: const Row(
                  children: [
                    Text(
                      'Khám phá',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFE02B6D),
                      ),
                    ),
                    SizedBox(width: 2),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 16,
                      color: Color(0xFFE02B6D),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Danh sách Card vuốt ngang tỉ lệ 4:5
        SizedBox(
          height: 200,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            itemCount: displayItems.length,
            itemBuilder: (context, index) {
              final item = displayItems[index];
              final String name = item.title;
              final String imageUrl = item.imageUrl;
              final bool isFav = item.isFavorite;

              return Container(
                width: 150,
                margin: const EdgeInsets.only(right: 12.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.06),
                        blurRadius: 10,
                        spreadRadius: 1,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        // Ảnh mẫu móng tỉ lệ 4:5
                        imageUrl.startsWith('http')
                            ? Image.network(
                                imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: const Color(0xFFFFF5F7),
                                  child: const Icon(
                                    Icons.spa_outlined,
                                    color: Color(0xFFFF4B72),
                                    size: 36,
                                  ),
                                ),
                              )
                            : Image.asset(
                                imageUrl.isNotEmpty ? imageUrl : 'assets/images/Rectangle 1.png',
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: const Color(0xFFFFF5F7),
                                  child: const Icon(
                                    Icons.spa_outlined,
                                    color: Color(0xFFFF4B72),
                                    size: 36,
                                  ),
                                ),
                              ),

                        // Phủ mờ gradient đen sát đáy
                        Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  Colors.transparent,
                                  Colors.transparent,
                                  Colors.black.withValues(alpha: 0.2),
                                  Colors.black.withValues(alpha: 0.75),
                                ],
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                              ),
                            ),
                          ),
                        ),

                        // Ripple effect chạm vào toàn bộ Card
                        Positioned.fill(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () {
                                if (item.id > 0) {
                                  context.push('/nails/${item.id}');
                                } else {
                                  context.push('/nails');
                                }
                              },
                              borderRadius: BorderRadius.circular(16),
                              splashColor: Colors.white.withValues(alpha: 0.2),
                            ),
                          ),
                        ),

                        // Góc trên bên phải: Icon Trái Tim Yêu Thích
                        Positioned(
                          top: 8,
                          right: 8,
                          child: GestureDetector(
                            onTap: () => _toggleFavorite(item),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.85),
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withValues(alpha: 0.1),
                                    blurRadius: 4,
                                  ),
                                ],
                              ),
                              child: Icon(
                                isFav ? Icons.favorite_rounded : Icons.favorite_outline_rounded,
                                color: isFav ? const Color(0xFFFF4B72) : Colors.grey.shade600,
                                size: 16,
                              ),
                            ),
                          ),
                        ),

                        // Góc dưới: Tên mẫu móng
                        Positioned(
                          left: 10,
                          right: 10,
                          bottom: 10,
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 4,
                                ),
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSkeleton(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            children: [
              const Icon(
                Icons.auto_awesome,
                color: Color(0xFFFF4B72),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                S.of(context).nailGalleryTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFE02B6D),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: 3,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6.0),
                child: Container(
                  width: 135,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade200,
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}


