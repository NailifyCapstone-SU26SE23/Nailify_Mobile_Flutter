import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../quiz/data/datasources/quiz_repository.dart';

class AnalyzePage extends StatefulWidget {
  final List<String> selectedOptionIds;

  const AnalyzePage({super.key, required this.selectedOptionIds});

  @override
  State<AnalyzePage> createState() => _AnalyzePageState();
}

class _AnalyzePageState extends State<AnalyzePage>
    with TickerProviderStateMixin {
  double _progress = 0;
  Timer? _progressTimer;
  
  late final AnimationController _pulseController;
  late final AnimationController _textController;
  
  final List<String> _analysisMessages = [
    'Đang phân tích phong cách...',
    'Đang tìm kiếm màu sắc phù hợp...',
    'Đang khớp với bộ sưu tập móng...',
    'Gần xong rồi...',
  ];
  int _messageIndex = 0;
  Timer? _messageTimer;

  @override
  void initState() {
    super.initState();
    
    // Pulsing lotus animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    
    // Text fade animation
    _textController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    )..forward();

    _startAnalysis();
  }

  void _startAnalysis() {
    const totalSteps = 100;
    const stepDuration = Duration(milliseconds: 40);
    var step = 0;

    _progressTimer = Timer.periodic(stepDuration, (timer) {
      step++;
      if (!mounted) return;
      setState(() => _progress = step / totalSteps);
      if (step >= totalSteps) timer.cancel();
    });

    _messageTimer = Timer.periodic(const Duration(milliseconds: 1500), (timer) {
      if (!mounted) return;
      _textController.reverse().then((_) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _analysisMessages.length;
        });
        _textController.forward();
      });
    });

    _submitAndNavigate();
  }

  Future<void> _submitAndNavigate() async {
    try {
      final repo = QuizRepository(getIt<ApiClient>());
      final results = await repo.submitQuiz(widget.selectedOptionIds);

      // Speed up artificial progress if API returns quickly
      if (_progress < 1.0) {
        final remaining = ((1.0 - _progress) * 100 * 15).toInt(); // Faster animation (15ms instead of 40ms)
        await Future.delayed(Duration(milliseconds: remaining.clamp(100, 1500)));
      } else {
        await Future.delayed(const Duration(milliseconds: 200));
      }

      if (mounted) {
        context.go('/perfect-match', extra: results);
      }
    } catch (e) {
      _progressTimer?.cancel();
      _messageTimer?.cancel();
      if (mounted) {
        _showErrorAndGoBack(e.toString());
      }
    }
  }

  void _showErrorAndGoBack(String message) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(children: [
          Icon(Icons.error_outline_rounded, color: AppColors.error),
          SizedBox(width: 10),
          Text('Có lỗi xảy ra'),
        ]),
        content: Text(
          message,
          style: const TextStyle(
              fontSize: 14, color: AppColors.textSecondary, height: 1.5),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (context.canPop()) context.pop();
            },
            child: const Text('Quay lại',
                style: TextStyle(
                    color: AppColors.primaryDark, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _messageTimer?.cancel();
    _pulseController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Elegant animated background
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Color(0xFFFFF0F5),
                    Color(0xFFFFE0EC),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ),
          
          // Removed heavy BackdropFilter for performance
          
          Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 402),
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLotusAnimation(),
                  const SizedBox(height: 48),
                  
                  // Text and progress
                  FadeTransition(
                    opacity: _textController,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0, 0.2),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: _textController,
                        curve: Curves.easeOut,
                      )),
                      child: Text(
                        _analysisMessages[_messageIndex],
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  _buildProgressBar(),
                  const SizedBox(height: 16),
                  
                  Text(
                    '${(_progress * 100).toInt()}%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primaryDark.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLotusAnimation() {
    return ScaleTransition(
      scale: Tween<double>(begin: 0.9, end: 1.05).animate(
        CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
      ),
      child: Container(
        width: 160,
        height: 160,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withOpacity(0.8),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 40,
              spreadRadius: 10,
            ),
            BoxShadow(
              color: AppColors.secondary.withOpacity(0.2),
              blurRadius: 60,
              spreadRadius: -10,
            ),
          ],
        ),
        child: ShaderMask(
          shaderCallback: (bounds) => AppColors.quizGradient.createShader(bounds),
          child: const Icon(
            Icons.spa_rounded,
            size: 80,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildProgressBar() {
    return Container(
      height: 12,
      width: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withOpacity(0.6),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: _progress.clamp(0.0, 1.0),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: AppColors.quizGradient,
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.5),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
