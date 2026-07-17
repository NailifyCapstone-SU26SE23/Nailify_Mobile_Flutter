import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/quiz_mock_data.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  int _currentIndex = 0;
  int? _selectedOptionIndex;
  final List<int> _answers = [];

  QuizQuestion get _currentQuestion => QuizMockData.questions[_currentIndex];
  int get _totalQuestions => QuizMockData.questions.length;
  double get _progress => (_currentIndex + 1) / _totalQuestions;
  bool get _isLastQuestion => _currentIndex == _totalQuestions - 1;

  void _onOptionTap(int index) {
    HapticFeedback.selectionClick();
    setState(() => _selectedOptionIndex = index);
  }

  void _onNextPressed() {
    if (_selectedOptionIndex == null) return;

    _answers.add(_selectedOptionIndex!);

    if (_isLastQuestion) {
      context.go('/quiz/analyze', extra: List<int>.from(_answers));
      return;
    }

    setState(() {
      _currentIndex++;
      _selectedOptionIndex = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.quizBgGradient, // 🔴 đổi từ surfaceLight
      ),
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 402),
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            child: _buildQuizCard(),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        color: Colors.white.withOpacity(0.15), // 🔴 bỏ gradient chìm, dùng glass trắng mờ
        border: Border.all(
          color: Colors.white.withOpacity(0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.2),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      child: Column(
        children: [
          _buildHeader(),
          const SizedBox(height: 20),
          _buildProgressSection(),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 320),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide = Tween<Offset>(
                begin: const Offset(0.06, 0),
                end: Offset.zero,
              ).animate(CurvedAnimation(
                parent: animation,
                curve: Curves.easeOutCubic,
              ));
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: Column(
              key: ValueKey(_currentIndex),
              children: [
                _buildQuestionBox(),
                const SizedBox(height: 16),
                ..._buildOptions(),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildNextButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        const Icon(
          Icons.auto_awesome,
          size: 26,
          color: Colors.white, // 🔴 bỏ ShaderMask, trắng nổi trên nền đậm
        ),
        const SizedBox(height: 10),
        const Text(
          'Personality Test',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white, // 🔴 trắng thẳng, không cần gradient mask
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Discover the nail style that matches you',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: Colors.white.withOpacity(0.85), // 🔴 trắng mờ thay vì textSecondary
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildProgressSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Question ${_currentIndex + 1}',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: Colors.white, // 🔴 trắng
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.25), // 🔴 trắng mờ
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: Colors.white.withOpacity(0.5),
                  width: 1,
                ),
              ),
              child: Text(
                '${_currentIndex + 1} / $_totalQuestions',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white, // 🔴 trắng
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        TweenAnimationBuilder<double>(
          tween: Tween(end: _progress),
          duration: const Duration(milliseconds: 450),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return Container(
              height: 8,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withOpacity(0.25), // 🔴 trắng mờ
              ),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: value.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      color: Colors.white, // 🔴 trắng đặc — nổi bật trên nền hồng
                      boxShadow: [
                        BoxShadow(
                          color: Colors.white.withOpacity(0.5),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildQuestionBox() {
    return _GradientBorderBox(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 22),
      child: Text(
        _currentQuestion.question,
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
          height: 1.45,
        ),
      ),
    );
  }

  List<Widget> _buildOptions() {
    const labels = ['A', 'B', 'C', 'D', 'E', 'F'];

    return List.generate(_currentQuestion.options.length, (index) {
      final isSelected = _selectedOptionIndex == index;

      return Padding(
        padding: EdgeInsets.only(
          bottom: index == _currentQuestion.options.length - 1 ? 0 : 10,
        ),
        child: _OptionTile(
          label: labels[index],
          text: _currentQuestion.options[index],
          isSelected: isSelected,
          onTap: () => _onOptionTap(index),
        ),
      );
    });
  }

  Widget _buildNextButton() {
    final isEnabled = _selectedOptionIndex != null;

    return AnimatedOpacity(
      opacity: isEnabled ? 1 : 0.5,
      duration: const Duration(milliseconds: 200),
      child: AnimatedScale(
        scale: isEnabled ? 1 : 0.98,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            color: isEnabled ? Colors.white : Colors.white.withOpacity(0.4), // 🔴 trắng nổi
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: AppColors.primaryDark.withOpacity(0.3),
                      blurRadius: 14,
                      offset: const Offset(0, 5),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isEnabled ? _onNextPressed : null,
              borderRadius: BorderRadius.circular(30),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isLastQuestion ? 'Finish' : 'Next Question',
                      style: TextStyle(
                        color: isEnabled
                            ? AppColors.primaryDark // 🔴 hồng đậm trên nền trắng
                            : AppColors.primaryDark.withOpacity(0.5),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Icon(
                      _isLastQuestion
                          ? Icons.check_rounded
                          : Icons.arrow_forward_rounded,
                      size: 20,
                      color: isEnabled
                          ? AppColors.primaryDark
                          : AppColors.primaryDark.withOpacity(0.5),
                    ),
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

// ─── Option Tile ────────────────────────────────────────────────────────────

class _OptionTile extends StatelessWidget {
  final String label;
  final String text;
  final bool isSelected;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.text,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isSelected ? 1.01 : 1,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: Colors.white,
              border: Border.all(
                color: isSelected
                    ? AppColors.primaryDark // 🔴 border hồng đậm khi chọn
                    : Colors.white.withOpacity(0.6),
                width: isSelected ? 1.8 : 1.2,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: AppColors.primaryDark.withOpacity(0.18),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: isSelected ? AppColors.quizGradient : null, // 🔴 quizGradient
                    color: isSelected ? null : AppColors.primaryLight,     // 🔴 primaryLight
                  ),
                  alignment: Alignment.center,
                  child: isSelected
                      ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
                      : Text(
                          label,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark, // 🔴 primaryDark
                          ),
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: AppColors.textPrimary,
                      height: 1.35,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Gradient Border Box ─────────────────────────────────────────────────────

class _GradientBorderBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const _GradientBorderBox({
    required this.child,
    this.padding = EdgeInsets.zero,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: AppColors.quizGradient, // 🔴 quizGradient
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.15),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white,
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}