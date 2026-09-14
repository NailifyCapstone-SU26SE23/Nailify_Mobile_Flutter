import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../data/models/home_data_models.dart';
import '../../data/repositories/home_repository.dart';
import '../cubit/home_cubit.dart';
import '../cubit/home_state.dart';
import '../widgets/widgets.dart';

/// Màn hình Trang Chủ (Home Page) Nailify được refactor tinh gọn & đấu nối API thực tế:
/// - Quản lý trạng thái bằng HomeCubit (gọi /Categories, /NailDesigns, /BookingRatings, /Salons)
/// - Cung cấp fallback dữ liệu mềm mại khi không có mạng
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<HomeCubit>(
      create: (context) => HomeCubit(getIt<HomeRepository>())..loadHomeData(),
      child: Container(
        color: const Color(0xFFFFF5F7), // Nền hồng phấn chuẩn thương hiệu
        child: RefreshIndicator(
          onRefresh: () async {
            // Context within BlocProvider
          },
          color: const Color(0xFFE02B6D),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.only(bottom: 32),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 402), // Responsive phone width
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 12),

                    // 1. Hero Banner (Ngang, height max 135px, nút Đặt Lịch pill)
                    const HomeBanner(),

                    const SizedBox(height: 18),

                    // 2. Khu vực AI Trọng tâm (2 Thẻ Glassmorphism bo góc 20px)
                    const HomeAiSection(),

                    const SizedBox(height: 22),

                    // 3. Featured Services (Dạng hàng Icon tròn vuốt ngang - Dynamic từ API)
                    BlocBuilder<HomeCubit, HomeState>(
                      builder: (context, state) {
                        return HomeServices(
                          categories: state.services,
                          isLoading: state.status == HomeStatus.loading,
                        );
                      },
                    ),

                    const SizedBox(height: 22),

                    // 4. Nail Gallery (Danh sách Card vuốt ngang 4:5 - Dynamic từ API)
                    BlocBuilder<HomeCubit, HomeState>(
                      builder: (context, state) {
                        return HomeGallery(
                          items: state.gallery,
                          isLoading: state.status == HomeStatus.loading,
                        );
                      },
                    ),

                    const SizedBox(height: 22),

                    // 5. Thanh Banner mỏng Hệ thống Salon - Dynamic từ API
                    BlocBuilder<HomeCubit, HomeState>(
                      builder: (context, state) {
                        return HomeOurSalonsBanner(salon: state.nearestSalon);
                      },
                    ),

                    const SizedBox(height: 22),

                    // 6. Customer Reviews (Thẻ mini vuốt ngang social review style - Dynamic từ API)
                    BlocBuilder<HomeCubit, HomeState>(
                      builder: (context, state) {
                        return CustomerReviews(reviews: state.reviews);
                      },
                    ),

                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thanh Banner ngang mỏng Hệ thống Salons (Thin horizontal bar with chevron >)
class HomeOurSalonsBanner extends StatelessWidget {
  final HomeSalonItem? salon;

  const HomeOurSalonsBanner({super.key, this.salon});

  @override
  Widget build(BuildContext context) {
    const title = 'Hệ Thống Salon Nailify';
    const subtitle = 'Tìm salon gần bạn nhất - Khám phá toàn bộ hệ thống';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: const Color(0xFFFFE3ED),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              spreadRadius: 1,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            onTap: () => context.push('/salons'),
            borderRadius: BorderRadius.circular(16),
            splashColor: const Color(0xFFFF4B72).withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFF4B72).withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.location_on_rounded,
                      color: Color(0xFFFF4B72),
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.grey,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const Icon(
                    Icons.chevron_right_rounded,
                    color: Color(0xFFE02B6D),
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}


