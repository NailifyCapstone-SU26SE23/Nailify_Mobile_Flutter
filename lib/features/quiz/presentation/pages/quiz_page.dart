import 'package:flutter/material.dart';
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

  double get _progress =>
      (_currentIndex + 1) / QuizMockData.questions.length;

  bool get _isLastQuestion =>
      _currentIndex == QuizMockData.questions.length - 1;

  void _onOptionTap(int index) {
    setState(() => _selectedOptionIndex = index);
  }

  // ĐÃ SỬA LỖI: Cập nhật hàm xử lý nút Back
  void _handleBackAction() {
    if (_currentIndex > 0) {
      // Nếu đang ở câu hỏi 2 trở đi -> Lùi lại 1 câu hỏi
      setState(() {
        _currentIndex--;
        // Khôi phục lại đáp án đã chọn trước đó để hiển thị trên UI
        if (_answers.isNotEmpty) {
          _selectedOptionIndex = _answers.removeLast();
        } else {
          _selectedOptionIndex = null;
        }
      });
    } else {
      // Nếu đang ở câu hỏi đầu tiên -> Thoát khỏi trang Quiz an toàn
      if (context.canPop()) {
        context.pop(); // Trả về trang trước đó trong lịch sử GoRouter
      } else {
        context.go('/catalog'); // Fallback: Nếu không có lịch sử, ép quay về Catalog (hoặc '/')
      }
    }
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
    // Đánh chặn nút Back vật lý của điện thoại để đồng bộ với nút Back trên UI
    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackAction();
      },
      child: Scaffold(
        backgroundColor: Colors.white, // Khai báo màu nền tránh đen màn hình
        body: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 402),
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nút Back
                    IconButton(
                      icon: const Icon(Icons.arrow_back_ios, size: 20, color: AppColors.textPrimary),
                      onPressed: _handleBackAction,
                      alignment: Alignment.centerLeft,
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 16),

                    // Nội dung chính
                    _buildQuizCard(),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuizCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.25),
            AppColors.secondary.withOpacity(0.35),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      padding: const EdgeInsets.all(3),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(25),
          gradient: LinearGradient(
            colors: [
              AppColors.primary.withOpacity(0.06),
              AppColors.secondary.withOpacity(0.12),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildTitle(),
            const SizedBox(height: 16),
            _buildProgressBar(),
            const SizedBox(height: 24),
            _buildQuestionBox(),
            const SizedBox(height: 16),
            ..._buildOptions(),
            const SizedBox(height: 24),
            _buildNextButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTitle() {
    return ShaderMask(
      shaderCallback: (bounds) =>
          AppColors.bannerGradient.createShader(bounds),
      child: const Text(
        'Personality Test',
        style: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
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
          widthFactor: _progress,
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

  Widget _buildQuestionBox() {
    return _GradientBorderBox(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      child: Text(
        'Quiz ${_currentQuestion.id}: ${_currentQuestion.question}',
        textAlign: TextAlign.center,
        style: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: AppColors.textPrimary,
          height: 1.4,
        ),
      ),
    );
  }

  List<Widget> _buildOptions() {
    const labels = ['A', 'B', 'C', 'D', 'E', 'F'];

    return List.generate(_currentQuestion.options.length, (index) {
      final isSelected = _selectedOptionIndex == index;

      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GestureDetector(
          onTap: () => _onOptionTap(index),
          child: _GradientBorderBox(
            fillColor: isSelected
                ? AppColors.primary.withOpacity(0.2)
                : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${labels[index]}. ${_currentQuestion.options[index]}',
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textPrimary,
                  height: 1.35,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  Widget _buildNextButton() {
    final isEnabled = _selectedOptionIndex != null;

    return Opacity(
      opacity: isEnabled ? 1 : 0.5,
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(30),
          gradient: AppColors.bannerGradient,
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: isEnabled ? _onNextPressed : null,
            borderRadius: BorderRadius.circular(30),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                _isLastQuestion ? 'Finish →' : 'Next Question →',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GradientBorderBox extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? fillColor;

  const _GradientBorderBox({
    required this.child,
    this.padding = EdgeInsets.zero,
    this.fillColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: AppColors.bannerGradient,
      ),
      padding: const EdgeInsets.all(2),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: fillColor ?? Colors.white,
        ),
        padding: padding,
        child: child,
      ),
    );
  }
}
