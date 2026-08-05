import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../data/datasources/quiz_repository.dart';
import '../../data/models/quiz_question_model.dart';

class QuizPage extends StatefulWidget {
  const QuizPage({super.key});

  @override
  State<QuizPage> createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  // ─── State ────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  final bool _isSubmitting = false;
  String? _errorMessage;
  List<QuizQuestionModel> _questions = [];
  int _currentIndex = 0;

  // ValueNotifiers — rebuild ONLY the option list, not the whole page
  late final ValueNotifier<String?> _selectedSingleId = ValueNotifier(null);
  late final ValueNotifier<Set<String>> _selectedMultipleIds = ValueNotifier(
    {},
  );

  final List<List<String>> _history = [];

  // ─── Computed ─────────────────────────────────────────────────────────────
  QuizQuestionModel get _current => _questions[_currentIndex];
  int get _total => _questions.length;
  double get _progress => _total == 0 ? 0 : (_currentIndex + 1) / _total;
  bool get _isLast => _currentIndex == _total - 1;

  bool get _hasSelection {
    if (_current.isMultiple) return _selectedMultipleIds.value.isNotEmpty;
    return _selectedSingleId.value != null;
  }

  // ─── Lifecycle ────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _loadQuestions();
  }

  @override
  void dispose() {
    _selectedSingleId.dispose();
    _selectedMultipleIds.dispose();
    super.dispose();
  }

  Future<void> _loadQuestions() async {
    try {
      final repo = QuizRepository(getIt<ApiClient>());
      final questions = await repo.getQuizQuestions();
      if (mounted) {
        setState(() {
          _questions = questions;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // ─── Navigation ───────────────────────────────────────────────────────────
  void _handleBackAction() {
    if (_currentIndex > 0) {
      final prevIds = _history.removeLast();
      final prevQuestion = _questions[_currentIndex - 1];
      if (prevQuestion.isMultiple) {
        _selectedMultipleIds.value = Set.from(prevIds);
        _selectedSingleId.value = null;
      } else {
        _selectedSingleId.value = prevIds.isNotEmpty ? prevIds.first : null;
        _selectedMultipleIds.value = {};
      }
      setState(() => _currentIndex--);
    } else {
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/nails');
      }
    }
  }

  void _onNextPressed() {
    if (!_hasSelection || _isSubmitting) return;
    final selectedIds = _current.isMultiple
        ? _selectedMultipleIds.value.toList()
        : [_selectedSingleId.value!];
    _history.add(selectedIds);

    if (_isLast) {
      final allIds = _history.expand((ids) => ids).toList();
      context.go('/quiz/analyze', extra: allIds);
      return;
    }

    _selectedSingleId.value = null;
    _selectedMultipleIds.value = {};
    setState(() => _currentIndex++);
  }

  // ─── Option Interaction ───────────────────────────────────────────────────
  void _onOptionTap(String optionId) {
    HapticFeedback.selectionClick();
    if (_current.isMultiple) {
      final current = Set<String>.from(_selectedMultipleIds.value);
      if (current.contains(optionId)) {
        current.remove(optionId);
      } else {
        current.add(optionId);
      }
      _selectedMultipleIds.value = current;
    } else {
      _selectedSingleId.value = optionId;
    }
  }

  // ─── Build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    if (_isLoading) return _buildLoadingScreen();
    if (_errorMessage != null) return _buildErrorScreen();

    return PopScope(
      canPop: _currentIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBackAction();
      },
      child: Scaffold(
        backgroundColor: Colors.white,
        body: Stack(
          children: [
            const _QuizBackground(),
            SafeArea(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Center(
                  child: Container(
                    constraints: const BoxConstraints(maxWidth: 402),
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        InkWell(
                          onTap: _handleBackAction,
                          borderRadius: BorderRadius.circular(30),
                          child: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: Colors.white,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              size: 16,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildQuizCard(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
              strokeWidth: 3,
            ),
            const SizedBox(height: 24),
            Text(
              'Đang chuẩn bị...',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
                color: AppColors.textPrimary.withOpacity(0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen() {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.primarySurface,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: 48,
                  color: AppColors.primary.withOpacity(0.8),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'Opps! Có lỗi xảy ra',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _errorMessage ?? '',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _isLoading = true;
                    _errorMessage = null;
                  });
                  _loadQuestions();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  shadowColor: AppColors.primary.withOpacity(0.4),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 40,
                    vertical: 16,
                  ),
                ),
                child: const Text(
                  'Thử lại ngay',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuizCard() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(36),
        color: Colors.white,
        border: Border.all(color: const Color(0xFFFFE0EC), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.08),
            blurRadius: 40,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 28),
      child: Column(
        children: [
          const _QuizCardHeader(),
          const SizedBox(height: 24),
          _buildProgressSection(),
          const SizedBox(height: 28),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, animation) {
              final slide =
                  Tween<Offset>(
                    begin: const Offset(0.04, 0),
                    end: Offset.zero,
                  ).animate(
                    CurvedAnimation(
                      parent: animation,
                      curve: Curves.easeOutCubic,
                    ),
                  );
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(position: slide, child: child),
              );
            },
            child: Column(
              key: ValueKey(_currentIndex),
              children: [
                _buildQuestionBox(),
                const SizedBox(height: 24),
                _buildOptions(),
              ],
            ),
          ),
          const SizedBox(height: 32),
          // Only rebuild button when selection changes
          ValueListenableBuilder<String?>(
            valueListenable: _selectedSingleId,
            builder: (context, _, _) => ValueListenableBuilder<Set<String>>(
              valueListenable: _selectedMultipleIds,
              builder: (context, _, _) => _buildNextButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Question ${_currentIndex + 1}/$_total',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primarySurface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Text(
                '${(100 * _progress).toInt()}%',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primaryDark,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          height: 10,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: Colors.black.withOpacity(0.04),
          ),
          child: TweenAnimationBuilder<double>(
            tween: Tween(end: _progress),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (context, value, _) => Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: value.clamp(0.0, 1.0),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: AppColors.quizGradient,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.4),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildQuestionBox() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF2B2B2B), Color(0xFF1A1A1A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
      child: Column(
        children: [
          Text(
            _current.questionText,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              height: 1.5,
              letterSpacing: 0.3,
            ),
          ),
          if (_current.isMultiple) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.check_box_rounded,
                    size: 14,
                    color: Color(0xFFFFB3C6),
                  ),
                  SizedBox(width: 6),
                  Text(
                    S.of(context).quizSelectMultiple,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFFFB3C6),
                      letterSpacing: 0.2,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Scopes rebuilds to ONLY the option list via ValueListenableBuilder
  Widget _buildOptions() {
    const labels = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
    final options = _current.options;
    final isMultiple = _current.isMultiple;

    if (isMultiple) {
      return ValueListenableBuilder<Set<String>>(
        valueListenable: _selectedMultipleIds,
        builder: (context, selectedIds, _) => Column(
          children: List.generate(options.length, (i) {
            final option = options[i];
            return Padding(
              padding: EdgeInsets.only(
                bottom: i == options.length - 1 ? 0 : 12,
              ),
              child: _OptionTile(
                label: i < labels.length ? labels[i] : '${i + 1}',
                text: option.label,
                isSelected: selectedIds.contains(option.quizOptionId),
                isMultiple: true,
                onTap: () => _onOptionTap(option.quizOptionId),
              ),
            );
          }),
        ),
      );
    } else {
      return ValueListenableBuilder<String?>(
        valueListenable: _selectedSingleId,
        builder: (context, selectedId, _) => Column(
          children: List.generate(options.length, (i) {
            final option = options[i];
            return Padding(
              padding: EdgeInsets.only(
                bottom: i == options.length - 1 ? 0 : 12,
              ),
              child: _OptionTile(
                label: i < labels.length ? labels[i] : '${i + 1}',
                text: option.label,
                isSelected: selectedId == option.quizOptionId,
                isMultiple: false,
                onTap: () => _onOptionTap(option.quizOptionId),
              ),
            );
          }),
        ),
      );
    }
  }

  Widget _buildNextButton() {
    final isEnabled = _hasSelection;
    return AnimatedOpacity(
      opacity: isEnabled ? 1 : 0.6,
      duration: const Duration(milliseconds: 200),
      child: AnimatedScale(
        scale: isEnabled ? 1.0 : 0.98,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutBack,
        child: Container(
          width: double.infinity,
          height: 60,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            gradient: isEnabled ? AppColors.quizGradient : null,
            color: isEnabled ? null : const Color(0xFFE0E0E0),
            boxShadow: isEnabled
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: isEnabled ? _onNextPressed : null,
              borderRadius: BorderRadius.circular(30),
              highlightColor: Colors.white24,
              splashColor: Colors.white24,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isLast ? S.of(context).done : S.of(context).next,
                    style: TextStyle(
                      color: isEnabled ? Colors.white : Colors.grey[500],
                      fontWeight: FontWeight.w800,
                      fontSize: 17,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Icon(
                    _isLast
                        ? Icons.check_circle_rounded
                        : Icons.arrow_forward_rounded,
                    size: 22,
                    color: isEnabled ? Colors.white : Colors.grey[500],
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

// ─── Static Background ───────────────────────────────────────────────────────
class _QuizBackground extends StatelessWidget {
  const _QuizBackground();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFFFFFAFC),
                  Color(0xFFFFF0F5),
                  Color(0xFFFFE0EC),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned(
          top: -80,
          left: -50,
          child: Container(
            width: 250,
            height: 250,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.primary.withOpacity(0.07),
            ),
          ),
        ),
        Positioned(
          bottom: -100,
          right: -80,
          child: Container(
            width: 300,
            height: 300,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withOpacity(0.05),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Static Card Header ──────────────────────────────────────────────────────
class _QuizCardHeader extends StatelessWidget {
  const _QuizCardHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.1),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: ShaderMask(
            shaderCallback: (bounds) =>
                AppColors.quizGradient.createShader(bounds),
            child: const Icon(
              Icons.auto_awesome_rounded,
              size: 28,
              color: Colors.white,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Personal Style',
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w900,
            color: AppColors.primaryDark,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          S.of(context).quizDiscoverDesign,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: AppColors.textSecondary,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ─── Option Tile ─────────────────────────────────────────────────────────────
class _OptionTile extends StatefulWidget {
  final String label;
  final String text;
  final bool isSelected;
  final bool isMultiple;
  final VoidCallback onTap;

  const _OptionTile({
    required this.label,
    required this.text,
    required this.isSelected,
    required this.isMultiple,
    required this.onTap,
  });

  @override
  State<_OptionTile> createState() => _OptionTileState();
}

class _OptionTileState extends State<_OptionTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _scaleController;

  @override
  void initState() {
    super.initState();
    _scaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      lowerBound: 0.97,
      upperBound: 1.0,
      value: 1.0,
    );
  }

  @override
  void dispose() {
    _scaleController.dispose();
    super.dispose();
  }

  void _handleTapDown(TapDownDetails _) => _scaleController.reverse();
  void _handleTapUp(TapUpDetails _) {
    _scaleController.forward();
    widget.onTap();
  }

  void _handleTapCancel() => _scaleController.forward();

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleController,
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: widget.isSelected ? AppColors.primarySurface : Colors.white,
            border: Border.all(
              color: widget.isSelected
                  ? AppColors.primary
                  : Colors.grey.withOpacity(0.15),
              width: widget.isSelected ? 2 : 1.5,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.15),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: widget.isMultiple
                      ? BoxShape.rectangle
                      : BoxShape.circle,
                  borderRadius: widget.isMultiple
                      ? BorderRadius.circular(10)
                      : null,
                  gradient: widget.isSelected ? AppColors.quizGradient : null,
                  color: widget.isSelected ? null : const Color(0xFFF5F5F5),
                ),
                alignment: Alignment.center,
                child: widget.isSelected
                    ? const Icon(
                        Icons.check_rounded,
                        size: 18,
                        color: Colors.white,
                      )
                    : Text(
                        widget.label,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textSecondary,
                        ),
                      ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  widget.text,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: widget.isSelected
                        ? FontWeight.bold
                        : FontWeight.w600,
                    color: widget.isSelected
                        ? AppColors.primaryDark
                        : AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
              AnimatedOpacity(
                opacity: widget.isSelected ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.6),
                        blurRadius: 6,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
