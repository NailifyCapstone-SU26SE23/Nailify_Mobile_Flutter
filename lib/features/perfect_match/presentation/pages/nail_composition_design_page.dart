import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../quiz/data/datasources/quiz_repository.dart';
import '../../../quiz/data/models/quiz_result_model.dart';

class NailCompositionDesignPage extends StatefulWidget {
  final List<MatchedCharacteristic> matchedCharacteristics;

  const NailCompositionDesignPage({
    super.key,
    required this.matchedCharacteristics,
  });

  @override
  State<NailCompositionDesignPage> createState() =>
      _NailCompositionDesignPageState();
}

class _NailCompositionDesignPageState extends State<NailCompositionDesignPage>
    with SingleTickerProviderStateMixin {
  final QuizRepository _quizRepo = QuizRepository(getIt<ApiClient>());

  bool _isGenerating = false;
  String? _error;

  // Pulsating animation for the scanner
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  int _loadingStepIndex = 0;
  Timer? _loadingTimer;
  final List<String> _loadingSteps = [
    'Đang phân tích đặc điểm sinh học...',
    'Đang đo tông da và sắc độ...',
    'Đang tính toán dáng móng tối ưu...',
    'Đang phối màu sắc độc quyền...',
    'Đang kết hợp phụ kiện và họa tiết vẽ...',
    'Đang thiết lập thiết kế hoàn chỉnh...',
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _loadingTimer?.cancel();
    super.dispose();
  }

  void _startGeneration() {
    setState(() {
      _isGenerating = true;
      _error = null;
      _loadingStepIndex = 0;
    });

    // Rotate through loading step messages
    _loadingTimer?.cancel();
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 800), (timer) {
      if (mounted) {
        setState(() {
          if (_loadingStepIndex < _loadingSteps.length - 1) {
            _loadingStepIndex++;
          }
        });
      }
    });

    _fetchComposition();
  }

  Future<void> _fetchComposition() async {
    try {
      final res = await _quizRepo.getCustomerNailComposition();
      // Slight delay to showcase the scanning loader
      await Future.delayed(const Duration(milliseconds: 1800));

      if (mounted) {
        setState(() {
          _isGenerating = false;
        });
        // Pass the raw composition map as recommendedData.
        // Do NOT wrap in a CustomerNailModel with id=0 — that triggers GET /CustomerNails/0 → 404.
        final extra = <String, dynamic>{
          ...res,
          'fromPerfectMatch': true,
        };
        context.push('/try-on', extra: extra);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isGenerating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFBF7),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.primaryDark,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          S.of(context).designPageTitle,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
          ),
        ),
        centerTitle: true,
      ),
      body: _isGenerating
          ? _buildGeneratingState()
          : _error != null
          ? _buildErrorState()
          : _buildIntroState(),
    );
  }

  Widget _buildIntroState() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          children: [
            const Spacer(),
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.auto_awesome_rounded,
                color: AppColors.primary,
                size: 64,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              S.of(context).automaticFitDesign,
              style: const TextStyle(
                fontSize: 22,
                fontFamily: 'Georgia',
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
                letterSpacing: 0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              S.of(context).automaticFitDesignDesc,
              style: TextStyle(
                fontSize: 14.5,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            _buildFeatureRow(
              Icons.fingerprint_rounded,
              S.of(context).designFeatureShape,
            ),
            _buildFeatureRow(
              Icons.color_lens_outlined,
              S.of(context).designFeatureColor,
            ),
            _buildFeatureRow(
              Icons.brush_outlined,
              S.of(context).designFeatureAccessories,
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: _startGeneration,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: AppColors.primary.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(28),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      S.of(context).generateDesignButton,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Icon(Icons.arrow_forward_ios_rounded, size: 14),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildGeneratingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Container(
                width: 130,
                height: 130,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary.withValues(alpha: 0.06),
                  border: Border.all(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary.withValues(alpha: 0.12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome_rounded,
                      color: AppColors.primary,
                      size: 44,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              S.of(context).generatingPersonalizedDesign,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w900,
                color: AppColors.primaryDark,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 24,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: Text(
                  _getTranslatedLoadingStep(
                    context,
                    _loadingSteps[_loadingStepIndex],
                  ),
                  key: ValueKey<int>(_loadingStepIndex),
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade600,
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: 180,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: const LinearProgressIndicator(
                  color: AppColors.primary,
                  backgroundColor: Color(0xFFF3EFEA),
                  minHeight: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.red.shade400,
                size: 40,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              S.of(context).failedGenerateDesign,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              S.of(context).failedGenerateDesignDesc,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600, height: 1.4),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _startGeneration,
                icon: const Icon(Icons.refresh_rounded),
                label: Text(
                  S.of(context).retry,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(26),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AppColors.primary.withValues(alpha: 0.8), size: 20),
          const SizedBox(width: 12),
          Text(
            text,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  String _getTranslatedLoadingStep(BuildContext context, String val) {
    if (Localizations.localeOf(context).languageCode == 'en') {
      if (val == 'Đang phân tích đặc điểm sinh học...') {
        return 'Analyzing biological characteristics...';
      }
      if (val == 'Đang đo tông da và sắc độ...') {
        return 'Measuring skin tone and undertone...';
      }
      if (val == 'Đang tính toán dáng móng tối ưu...') {
        return 'Calculating optimal nail shape...';
      }
      if (val == 'Đang phối màu sắc độc quyền...') {
        return 'Matching exclusive colors...';
      }
      if (val == 'Đang kết hợp phụ kiện và họa tiết vẽ...') {
        return 'Combining accessories and patterns...';
      }
      if (val == 'Đang thiết lập thiết kế hoàn chỉnh...') {
        return 'Setting up complete design...';
      }
    }
    return val;
  }
}
