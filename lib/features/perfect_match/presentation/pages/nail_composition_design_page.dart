import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
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
  State<NailCompositionDesignPage> createState() => _NailCompositionDesignPageState();
}

class _NailCompositionDesignPageState extends State<NailCompositionDesignPage> with SingleTickerProviderStateMixin {
  final QuizRepository _quizRepo = QuizRepository(getIt<ApiClient>());

  bool _isGenerating = false;
  Map<String, dynamic>? _compositionResult;
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
    'Đang thiết lập thiết kế hoàn chỉnh...'
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
          _compositionResult = res;
          _isGenerating = false;
        });
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
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primaryDark, size: 20),
          onPressed: () => context.pop(),
        ),
        title: const Text(
          'Thiết Kế Móng Cá Nhân',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
          ),
        ),
        centerTitle: true,
      ),
      body: _isGenerating
          ? _buildGeneratingState()
          : _compositionResult != null
              ? _buildResultsState()
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
            const Text(
              'THIẾT KẾ TỰ ĐỘNG PHÙ HỢP',
              style: TextStyle(
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
              'Bloom sẽ tự động phân tích tông da, dáng tay, nghề nghiệp và sở thích từ bài trắc nghiệm cá tính trước đó của bạn để tạo ra cấu hình móng hoàn chỉnh 5 tầng.',
              style: TextStyle(
                fontSize: 14.5,
                color: Colors.grey.shade600,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),
            _buildFeatureRow(Icons.fingerprint_rounded, 'Đề xuất dáng móng phù hợp cấu trúc tay'),
            _buildFeatureRow(Icons.color_lens_outlined, 'Phối màu sắc tôn da theo sắc độ Warm/Cool'),
            _buildFeatureRow(Icons.brush_outlined, 'Tự động chọn họa tiết & phụ kiện tinh tế'),
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
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'GENERATE THIẾT KẾ',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, letterSpacing: 0.5),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward_ios_rounded, size: 14),
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
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15), width: 1.5),
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
            const Text(
              'ĐANG TẠO THIẾT KẾ THÍCH HỢP',
              style: TextStyle(
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
                  _loadingSteps[_loadingStepIndex],
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
              child: Icon(Icons.error_outline_rounded, color: Colors.red.shade400, size: 40),
            ),
            const SizedBox(height: 24),
            const Text(
              'Không thể tạo cấu hình móng',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primaryDark),
            ),
            const SizedBox(height: 8),
            Text(
              'Đã xảy ra lỗi khi lấy gợi ý cấu hình móng từ sở thích của bạn.',
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
                label: const Text('Thử lại', style: TextStyle(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsState() {
    final res = _compositionResult!;

    // Tầng 1: Dáng móng
    final nailShapeMap = res['nailShape'] as Map<String, dynamic>? ?? {};
    final shapeName = nailShapeMap['name']?.toString() ?? 'Dáng tròn (Round)';
    final shapeImageUrl = nailShapeMap['imageUrl']?.toString() ?? '';

    // Tầng 2: Màu sắc
    final colorsList = (res['colors'] as List<dynamic>?)?.map((c) => c.toString()).toList() ?? [];

    // Tầng 3: Bề mặt
    final nailSurfaceMap = res['nailSurface'] as Map<String, dynamic>? ?? {};
    final surfaceName = nailSurfaceMap['name']?.toString() ?? 'Glossy';

    // Tầng 4: Họa tiết & Phụ kiện
    final componentsList = (res['components'] as List<dynamic>?) ?? [];

    // Tầng 5: Lý do
    final reason = res['reason'] ?? res['description'] ?? 'Dựa trên đặc điểm móng và nghề nghiệp của bạn, Bloom khuyên dùng cấu hình móng này để đạt vẻ ngoài tự nhiên và bảo vệ móng hiệu quả.';

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.auto_awesome_rounded, color: AppColors.primary, size: 32),
                ),
                const SizedBox(height: 12),
                const Text(
                  'CẤU HÌNH MÓNG HOÀN HẢO',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Georgia',
                    color: AppColors.primaryDark,
                    letterSpacing: 0.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Cấu hình gợi ý phù hợp nhất với hồ sơ cá nhân của bạn',
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),

          // TẦNG 1: Dáng Móng Đề Xuất
          _buildLayerCard(
            layerNumber: 'TẦNG 1',
            title: 'Dáng Móng Đề Xuất (Nail Shape)',
            icon: Icons.design_services_outlined,
            color: const Color(0xFFE8F5E9),
            iconColor: Colors.green.shade700,
            child: Row(
              children: [
                Text(
                  shapeName,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const Spacer(),
                if (shapeImageUrl.isNotEmpty)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      shapeImageUrl,
                      width: 44,
                      height: 44,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => const SizedBox(),
                    ),
                  ),
              ],
            ),
          ),

          // TẦNG 2: Màu sắc chủ đạo
          _buildLayerCard(
            layerNumber: 'TẦNG 2',
            title: 'Màu Sắc Chủ Đạo (Base Colors)',
            icon: Icons.palette_outlined,
            color: const Color(0xFFE3F2FD),
            iconColor: Colors.blue.shade700,
            child: colorsList.isEmpty
                ? const Text('Màu sắc hài hòa')
                : Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: colorsList.map((hex) {
                      Color colorVal;
                      try {
                        colorVal = Color(int.parse(hex.replaceAll('#', '0xFF')));
                      } catch (_) {
                        colorVal = Colors.grey;
                      }
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: colorVal,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey.shade300, width: 1.2),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            hex,
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                          ),
                        ],
                      );
                    }).toList(),
                  ),
          ),

          // TẦNG 3: Bề Mặt Móng
          _buildLayerCard(
            layerNumber: 'TẦNG 3',
            title: 'Bề Mặt Móng (Nail Surface)',
            icon: Icons.brush_outlined,
            color: const Color(0xFFFFF3E0),
            iconColor: Colors.orange.shade700,
            child: Text(
              surfaceName,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
          ),

          // TẦNG 4: Họa tiết & Phụ kiện
          _buildLayerCard(
            layerNumber: 'TẦNG 4',
            title: 'Họa Tiết & Phụ Kiện (Components)',
            icon: Icons.diamond_outlined,
            color: const Color(0xFFF3E5F5),
            iconColor: Colors.purple.shade700,
            child: componentsList.isEmpty
                ? const Text(
                    'Không đính phụ kiện (Trơn tối giản)',
                    style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                  )
                : Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: componentsList.map((comp) {
                      final name = comp['name']?.toString() ?? '';
                      final url = comp['imageUrl']?.toString() ?? '';
                      final type = comp['componentType']?.toString() ?? '';
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFAF9F6),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFEDEBE7)),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (url.isNotEmpty) ...[
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: Image.network(url, width: 22, height: 22, fit: BoxFit.cover),
                              ),
                              const SizedBox(width: 8),
                            ],
                            Text(
                              '$name ($type)',
                              style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          ),

          // TẦNG 5: Lý Do Đề Xuất
          _buildLayerCard(
            layerNumber: 'TẦNG 5',
            title: 'Lý Do Đề Xuất (Vibe & Concept)',
            icon: Icons.lightbulb_outline_rounded,
            color: const Color(0xFFFFFDE7),
            iconColor: Colors.amber.shade900,
            child: Text(
              reason.toString(),
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, height: 1.45),
            ),
          ),

          const SizedBox(height: 32),

          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: _startGeneration,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('GEN LẠI', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.textPrimary,
                      side: BorderSide(color: Colors.grey.shade300, width: 1.2),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push('/try-on', extra: res);
                    },
                    icon: const Icon(Icons.brush_rounded, size: 18),
                    label: const Text('VẼ MÓNG', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(27)),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildLayerCard({
    required String layerNumber,
    required String title,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3EFEA), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.015),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      layerNumber,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: iconColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Icon(Icons.arrow_right_alt_rounded, size: 16, color: Colors.grey),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  title,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade500, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                child,
              ],
            ),
          ),
        ],
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
}
