import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n.dart';
import '../../data/models/home_data_models.dart';

/// Khối Featured Services dạng Vuốt Ngang (Horizontal Scroll):
/// - Hỗ trợ nạp dữ liệu động từ API hoặc danh sách mặc định
class HomeServices extends StatelessWidget {
  final List<HomeCategoryItem> categories;
  final bool isLoading;

  const HomeServices({
    super.key,
    this.categories = const [],
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading && categories.isEmpty) {
      return _buildSkeleton(context);
    }

    final List<HomeCategoryItem> displayList = categories;
    /*
    final List<HomeCategoryItem> displayList = categories.isNotEmpty
        ? categories
        : [
            HomeCategoryItem(id: 1, title: S.of(context).serviceCare, imagePath: 'assets/images/image 1.png'),
            HomeCategoryItem(id: 2, title: S.of(context).serviceGel, imagePath: 'assets/images/image 2.png'),
            HomeCategoryItem(id: 3, title: S.of(context).serviceArt, imagePath: 'assets/images/image 3.png'),
            HomeCategoryItem(id: 4, title: S.of(context).serviceAcrylic, imagePath: 'assets/images/image 4.png'),
            const HomeCategoryItem(id: 5, title: 'Dưỡng', imagePath: 'assets/images/home-mid.jpg'),
          ];
    */

    if (displayList.isEmpty) {
      return const SizedBox.shrink();
    }

    final gradients = [
      [const Color(0xFFFF66C4), const Color(0xFFFFB347)],
      [const Color(0xFFFF4B72), const Color(0xFFFF7E53)],
      [const Color(0xFFE02B6D), const Color(0xFFFF66C4)],
      [const Color(0xFFB39DDB), const Color(0xFF7E57C2)],
      [const Color(0xFF81D4FA), const Color(0xFF29B6F6)],
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Tiêu đề dịch vụ tinh gọn + nút xem tất cả
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 4,
                    height: 18,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE02B6D),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    S.of(context).servicesTitle,
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
              GestureDetector(
                onTap: () => context.push('/services'),
                child: const Row(
                  children: [
                    Text(
                      'Tất cả',
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

        // Hàng icon tròn nằm ngang vuốt mượt (Horizontal Scroll)
        SizedBox(
          height: 98,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: displayList.length,
            itemBuilder: (context, index) {
              final item = displayList[index];
              final String title = item.title;
              final String? imagePath = item.imagePath;
              final String? iconUrl = item.iconUrl;
              final gradient = gradients[index % gradients.length];

              return Container(
                margin: const EdgeInsets.symmetric(horizontal: 6.0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () {
                      final idStr = item.id?.toString() ?? '';
                      if (idStr.isNotEmpty && idStr != '0') {
                        context.push('/services/$idStr');
                      } else {
                        context.push('/services');
                      }
                    },
                    borderRadius: BorderRadius.circular(36),
                    splashColor: const Color(
                      0xFFFF4B72,
                    ).withValues(alpha: 0.15),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 4,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Icon Tròn với viền gradient nhẹ
                          Container(
                            width: 62,
                            height: 62,
                            padding: const EdgeInsets.all(2.5),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: gradient,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: gradient.first.withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Container(
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: ClipOval(
                                child:
                                    iconUrl != null &&
                                        iconUrl.startsWith('http')
                                    ? Image.network(
                                        iconUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Icon(
                                                  Icons.spa_rounded,
                                                  color: gradient.first,
                                                  size: 26,
                                                ),
                                      )
                                    : Image.asset(
                                        imagePath ??
                                            'assets/images/image 1.png',
                                        fit: BoxFit.cover,
                                        errorBuilder:
                                            (context, error, stackTrace) =>
                                                Icon(
                                                  Icons.spa_rounded,
                                                  color: gradient.first,
                                                  size: 26,
                                                ),
                                      ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 8),

                          // Tên dịch vụ
                          SizedBox(
                            width: 68,
                            child: Text(
                              title,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textPrimary,
                                height: 1.1,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
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
              Container(
                width: 4,
                height: 18,
                decoration: BoxDecoration(
                  color: const Color(0xFFE02B6D).withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                S.of(context).servicesTitle,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        SizedBox(
          height: 98,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 12.0),
            itemCount: 5,
            itemBuilder: (context, index) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Column(
                  children: [
                    Container(
                      width: 62,
                      height: 62,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.grey.shade200,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 48,
                      height: 10,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(5),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
