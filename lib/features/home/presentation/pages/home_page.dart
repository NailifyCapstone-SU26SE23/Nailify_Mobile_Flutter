import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../widgets/home_banner.dart';
import '../widgets/home_services.dart';
import '../widgets/home_gallery.dart';
import '../widgets/home_our_promise.dart';
import '../widgets/home_review.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 402),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(height: 8),

              HomeBanner(),

              SizedBox(height: 40),

              HomeServices(),

              SizedBox(height: 40),

              HomeGallery(),

              SizedBox(height: 40),

              OurPromisePage(),

              SizedBox(height: 40),

              CustomerReviews(),

              SizedBox(height: 40),

              _buildCallToAction(),

              // Các danh mục sẽ được ném vào đây (￣o￣) . z Z
            ],
          ),
        ),
      ),
    );
  }
}

//  BOOK NOW!!!!!
Widget _buildCallToAction() {
  return ClipRect(
    child: Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: AppColors.background, // Màu nền be nhạt
      ),
      child: Stack(
        children: [
          Positioned(
            top: -60,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.12),
                shape: BoxShape.circle,
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(vertical: 56.0, horizontal: 24.0),
            child: Column(
              mainAxisSize: MainAxisSize.max,
              children: [
                const Text(
                  "Let's Book Now!",
                  textAlign: TextAlign.justify,
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                    // fontFamily: 'Khum biet font gi',
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Book your appointment with Nailify — join\nus on a journey of exquisite nail artistry.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: Thêm logic điều hướng sang trang Đặt lịch
                  },
                  icon: const Icon(
                    Icons.calendar_today_outlined,
                    size: 20,
                    color: AppColors.surface,
                  ),
                  label: const Text(
                    'BOOK AN APPOINTMENT',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.surface,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.textPrimary,
                    foregroundColor: AppColors.surface,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(30),
                    ),
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