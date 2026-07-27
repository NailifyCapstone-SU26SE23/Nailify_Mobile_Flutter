import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';

class QuizBanner extends StatefulWidget {
  const QuizBanner({super.key});

  @override
  State<QuizBanner> createState() => _QuizBannerState();
}

class _QuizBannerState extends State<QuizBanner> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  bool _hasCompletedQuiz = false;

  @override
  void initState() {
    super.initState();
    _hasCompletedQuiz = getIt<SharedPreferences>().getBool('has_completed_quiz') ?? false;
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _hasCompletedQuiz = getIt<SharedPreferences>().getBool('has_completed_quiz') ?? false;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.secondary],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.2),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.auto_awesome, color: AppColors.surface, size: 32),
          const SizedBox(height: 12),
          Text(
            _hasCompletedQuiz
                ? "✨ Bloom đã tìm thấy các mẫu móng Perfect Match hoàn hảo dành riêng cho bạn!"
                : "If you haven't found a nail design that suits you yet, Bloom can help.",
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.surface,
              fontSize: 14.5,
              fontWeight: FontWeight.bold,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          if (_hasCompletedQuiz) ...[
            FadeTransition(
              opacity: _animation,
              child: ElevatedButton(
                onPressed: () => context.push('/perfect-match'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.surface,
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
                child: const Text(
                  'XEM KẾT QUẢ PERFECT MATCH',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(height: 10),
            ElevatedButton(
              onPressed: () => context.push('/quiz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.15),
                foregroundColor: Colors.white,
                elevation: 0,
                side: const BorderSide(color: Colors.white, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Làm lại trắc nghiệm cá tính',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ] else ...[
            ElevatedButton(
              onPressed: () => context.push('/quiz'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.surface,
                foregroundColor: AppColors.primary,
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: const Text(
                'Take personality test',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
          const SizedBox(height: 8),
          ElevatedButton(
            onPressed: () => context.push('/custom-nail'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white.withOpacity(0.15),
              foregroundColor: Colors.white,
              elevation: 0,
              side: const BorderSide(color: Colors.white, width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Customize your Nail',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
