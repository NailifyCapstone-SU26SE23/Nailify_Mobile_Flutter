import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

class AnalyzePage extends StatefulWidget {
  final List<int> answers;

  const AnalyzePage({super.key, required this.answers});

  @override
  State<AnalyzePage> createState() => _AnalyzePageState();
}

class _AnalyzePageState extends State<AnalyzePage>
    with SingleTickerProviderStateMixin {
  double _progress = 0;
  int _activeDot = 0;
  Timer? _progressTimer;
  Timer? _dotTimer;
  late final AnimationController _sparkleController;

  @override
  void initState() {
    super.initState();
    _sparkleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _startAnalysis();
  }

  void _startAnalysis() {
    const totalSteps = 60;
    const stepDuration = Duration(milliseconds: 50);
    var step = 0;

    _progressTimer = Timer.periodic(stepDuration, (timer) {
      step++;
      if (!mounted) return;

      setState(() => _progress = step / totalSteps);

      if (step >= totalSteps) {
        timer.cancel();
        Future.delayed(const Duration(milliseconds: 400), () {
          if (mounted) {
            context.go('/perfect-match', extra: widget.answers);
          }
        });
      }
    });

    _dotTimer = Timer.periodic(const Duration(milliseconds: 400), (timer) {
      if (!mounted) return;
      setState(() => _activeDot = (_activeDot + 1) % 3);
    });
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _dotTimer?.cancel();
    _sparkleController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 402),
          padding: const EdgeInsets.fromLTRB(16, 32, 16, 40),
          child: Column(
            children: [
              FadeTransition(
                opacity: Tween<double>(begin: 0.6, end: 1).animate(
                  CurvedAnimation(
                    parent: _sparkleController,
                    curve: Curves.easeInOut,
                  ),
                ),
                child: ShaderMask(
                  shaderCallback: (bounds) =>
                      AppColors.bannerGradient.createShader(bounds),
                  child: const Icon(
                    Icons.auto_awesome,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ShaderMask(
                shaderCallback: (bounds) =>
                    AppColors.bannerGradient.createShader(bounds),
                child: const Text(
                  'Bloom',
                  style: TextStyle(
                    fontSize: 42,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: Colors.white,
                    height: 1.1,
                  ),
                ),
              ),
              const SizedBox(height: 32),
              _buildAnalysisCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnalysisCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 36),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.06),
            AppColors.secondary.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text('🌸', style: TextStyle(fontSize: 36)),
          const SizedBox(height: 20),
          const Text(
            'Bloom is analyzing the data...',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Processing ${widget.answers.length} responses to find your perfect nail style',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),
          _buildLoadingDots(),
          const SizedBox(height: 28),
          _buildProgressBar(),
        ],
      ),
    );
  }

  Widget _buildLoadingDots() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(3, (index) {
        final isActive = index == _activeDot;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: isActive ? 10 : 8,
          height: isActive ? 10 : 8,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isActive
                ? AppColors.primary
                : AppColors.primary.withOpacity(0.3),
          ),
        );
      }),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 8,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: AppColors.primary.withOpacity(0.15),
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: _progress.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: AppColors.bannerGradient,
            ),
          ),
        ),
      ),
    );
  }
}
