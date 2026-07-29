import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../../generated/l10n.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../quiz/data/datasources/quiz_repository.dart';
import '../../../quiz/data/models/quiz_result_model.dart';

class PerfectMatchPage extends StatefulWidget {
  final List<QuizResultModel> results;

  const PerfectMatchPage({super.key, this.results = const []});

  @override
  State<PerfectMatchPage> createState() => _PerfectMatchPageState();
}

class _PerfectMatchPageState extends State<PerfectMatchPage> {
  late List<QuizResultModel> _results;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _results = widget.results;
    if (_results.isEmpty) {
      _loadRecommendations();
    } else {
      // If we received results, cache the flag immediately
      getIt<SharedPreferences>().setBool('has_completed_quiz', true);
    }
  }

  Future<void> _loadRecommendations() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final repo = QuizRepository(getIt<ApiClient>());
      final data = await repo.getPersonalizedRecommendations();
      if (mounted) {
        setState(() {
          _results = data;
          _isLoading = false;
        });
        if (data.isNotEmpty) {
          getIt<SharedPreferences>().setBool('has_completed_quiz', true);
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  // Scientific RGB Euclidean distance mapping to find closest Vietnamese color name
  String _getColorName(String hex) {
    final cleanHex = hex.toUpperCase().replaceAll('#', '').trim();
    if (cleanHex.length != 6) return 'Màu sắc';

    try {
      final r = int.parse(cleanHex.substring(0, 2), radix: 16);
      final g = int.parse(cleanHex.substring(2, 4), radix: 16);
      final b = int.parse(cleanHex.substring(4, 6), radix: 16);

      final Map<String, List<int>> anchorColors = {
        'Đỏ': [255, 0, 0],
        'Hồng': [255, 107, 156],
        'Hồng đậm': [255, 64, 129],
        'Xanh dương': [0, 0, 255],
        'Xanh lá': [0, 255, 0],
        'Vàng': [255, 255, 0],
        'Nude': [245, 203, 167],
        'Đen': [0, 0, 0],
        'Trắng': [255, 255, 255],
        'Xám': [128, 128, 128],
        'Tím': [128, 0, 128],
        'Cam': [255, 165, 0],
        'Nâu': [165, 42, 42],
        'Hồng nhạt': [255, 224, 236],
      };

      String closestColorName = 'Màu sắc';
      double minDistance = double.maxFinite;

      anchorColors.forEach((name, rgb) {
        final dr = r - rgb[0];
        final dg = g - rgb[1];
        final db = b - rgb[2];
        final distance = (dr * dr + dg * dg + db * db).toDouble();
        if (distance < minDistance) {
          minDistance = distance;
          closestColorName = name;
        }
      });

      return closestColorName;
    } catch (_) {
      return 'Màu sắc';
    }
  }

  // Helper to replace hex codes inside string, and dynamically correct matching colors based on user selection
  String _translateDynamicText(String val) {
    if (Localizations.localeOf(context).languageCode == 'en') {
      var result = val;

      // Match pattern "Tông màu [Color] khớp với màu bạn thích."
      if (result.startsWith('Tông màu ') && result.endsWith(' khớp với màu bạn thích.')) {
        var colorName = result.substring('Tông màu '.length, result.length - ' khớp với màu bạn thích.'.length);
        colorName = colorName.replaceAll('Hồng đậm', 'Deep Pink');
        colorName = colorName.replaceAll('Nude', 'Nude');
        colorName = colorName.replaceAll('Đỏ', 'Red');
        colorName = colorName.replaceAll('Xanh dương', 'Blue');
        colorName = colorName.replaceAll('Hồng', 'Pink');
        colorName = colorName.replaceAll('Xanh lá', 'Green');
        colorName = colorName.replaceAll('Vàng', 'Yellow');
        colorName = colorName.replaceAll('Đen', 'Black');
        colorName = colorName.replaceAll('Trắng', 'White');
        colorName = colorName.replaceAll('Xám', 'Grey');
        colorName = colorName.replaceAll('Tím', 'Purple');
        colorName = colorName.replaceAll('Cam', 'Orange');
        colorName = colorName.replaceAll('Nâu', 'Brown');
        colorName = colorName.replaceAll('Hồng nhạt', 'Light Pink');
        return 'Color tone $colorName matches your preferred color.';
      }

      // Match pattern "Mang phong cách [Style] yêu thích của bạn."
      if (result.startsWith('Mang phong cách ') && result.endsWith(' yêu thích của bạn.')) {
        final styleName = result.substring('Mang phong cách '.length, result.length - ' yêu thích của bạn.'.length);
        return 'Matches your favorite $styleName style.';
      }
      
      // Match pattern "Mẫu móng dáng [Shape] theo sở thích."
      if (result.startsWith('Mẫu móng dáng ') && result.endsWith(' theo sở thích.')) {
        final shapeName = result.substring('Mẫu móng dáng '.length, result.length - ' theo sở thích.'.length);
        return 'Matches your preferred $shapeName nail shape.';
      }
      
      result = result.replaceAll('Màu Đỏ', 'Red');
      result = result.replaceAll('Màu Nude', 'Nude');
      result = result.replaceAll('Màu Hồng đậm', 'Deep Pink');
      result = result.replaceAll('Màu Xanh dương', 'Blue');
      result = result.replaceAll('Màu Hồng', 'Pink');
      result = result.replaceAll('Màu Xanh lá', 'Green');
      result = result.replaceAll('Màu Vàng', 'Yellow');
      result = result.replaceAll('Màu Đen', 'Black');
      result = result.replaceAll('Màu Trắng', 'White');
      result = result.replaceAll('Màu Xám', 'Grey');
      result = result.replaceAll('Màu Tím', 'Purple');
      result = result.replaceAll('Màu Cam', 'Orange');
      result = result.replaceAll('Màu Nâu', 'Brown');
      result = result.replaceAll('Màu Hồng nhạt', 'Light Pink');
      result = result.replaceAll('Màu sắc', 'Color');
      result = result.replaceAll('Màu ', 'Color ');
      result = result.replaceAll('Dáng móng:', 'Nail Shape:');
      result = result.replaceAll('Độ phức tạp:', 'Complexity:');
      result = result.replaceAll('simple', 'Simple');
      result = result.replaceAll('Winter', 'Winter');
      return result;
    }
    return val;
  }

  // Helper to replace hex codes inside string, and dynamically correct matching colors based on user selection
  String _cleanColorText(
    String text,
    List<MatchedCharacteristic> characteristics,
  ) {
    final chosenColorChar = characteristics.firstWhere(
      (c) => c.category.toLowerCase() == 'color' && c.isMatchingPreference,
      orElse: () => const MatchedCharacteristic(
        category: '',
        value: '',
        label: '',
        isMatchingPreference: false,
      ),
    );

    // If backend returns a general color match reason, align it to show the color the user actually selected
    if (text.contains('khớp với màu bạn thích') &&
        chosenColorChar.label.isNotEmpty) {
      final regExp = RegExp(r'#([0-9A-Fa-f]{6})');
      final cleanedLabel = chosenColorChar.label.replaceAllMapped(regExp, (
        match,
      ) {
        final hex = match.group(0) ?? '';
        return _getColorName(hex);
      });
      return S.of(context).colorMatchReason(cleanedLabel);
    }

    final regExp = RegExp(r'#([0-9A-Fa-f]{6})');
    final cleaned = text.replaceAllMapped(regExp, (match) {
      final hex = match.group(0) ?? '';
      return _getColorName(hex);
    });
    return _translateDynamicText(cleaned);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFFDFBF7),
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        backgroundColor: const Color(0xFFFDFBF7),
        appBar: AppBar(
          backgroundColor: const Color(0xFFFDFBF7),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.primaryDark,
            ),
            onPressed: () => context.go('/nails'),
          ),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
                const SizedBox(height: 16),
                const Text(
                  'Có lỗi xảy ra',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.black54),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _loadRecommendations,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  child: const Text(
                    'Thử lại',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_results.isEmpty) {
      return _buildEmptyState(context);
    }

    final top = _results.first;
    final others = _results.length > 1
        ? _results.sublist(1)
        : <QuizResultModel>[];

    // Find style or occasion to customize the welcome card
    final styleChar = top.matchedCharacteristics.firstWhere(
      (c) => c.category.toLowerCase() == 'style',
      orElse: () => top.matchedCharacteristics.firstWhere(
        (c) => c.category.toLowerCase() == 'theme',
        orElse: () => const MatchedCharacteristic(
          category: 'Style',
          value: '',
          label: 'Chic & Elegant',
          isMatchingPreference: true,
        ),
      ),
    );

    // Calculate match percentage
    final matchPercentage = (top.score <= 1 ? top.score * 100 : top.score)
        .toInt();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        // Pressing system back button always redirects to nail design page
        context.go('/nails');
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFFDFBF7), // Warm cream background
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
            onPressed: () {
              // Pressing AppBar back button redirects to nail design page
              context.go('/nails');
            },
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.spa_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 6),
              Text(
                S.of(context).perfectMatchTitle,
                style: const TextStyle(
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          centerTitle: true,
        ),
        body: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Sparkle Spark Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.auto_awesome_outlined,
                          color: AppColors.primary,
                          size: 16,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          S.of(context).forYouTitle,
                          style: TextStyle(
                            color: AppColors.primary,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 2.0,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(
                          Icons.auto_awesome_outlined,
                          color: AppColors.primary,
                          size: 16,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    // Main Header Title (Serif styled font layout as requested)
                    RichText(
                      textAlign: TextAlign.center,
                      text: TextSpan(
                        style: TextStyle(
                          fontSize: 30,
                          color: Colors.black87,
                          fontFamily: 'Georgia',
                          height: 1.25,
                        ),
                        children: Localizations.localeOf(context).languageCode == 'en'
                            ? [
                                const TextSpan(text: 'Your '),
                                const TextSpan(
                                  text: 'perfect',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const TextSpan(text: ' nail designs are here'),
                              ]
                            : [
                                const TextSpan(text: 'Mẫu móng '),
                                const TextSpan(
                                  text: 'hoàn hảo nhất',
                                  style: TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w600,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                                const TextSpan(text: ' của bạn ở đây'),
                              ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Personality Insights card
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFFFFF6F9), Color(0xFFFFF0F5)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: const Color(0xFFFFD1E1),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.04),
                            blurRadius: 15,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.favorite_rounded,
                                  color: AppColors.primary,
                                  size: 16,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                S.of(context).styleRecommendation,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primaryDark,
                                  letterSpacing: 0.5,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          RichText(
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              children: [
                                 TextSpan(
                                  text: S.of(context).yourPersonalStyle,
                                  style: const TextStyle(fontWeight: FontWeight.w500),
                                ),
                                TextSpan(
                                  text: styleChar.label,
                                  style: const TextStyle(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.2,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (top.reasons.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Text(
                              _cleanColorText(
                                top.reasons.first,
                                top.matchedCharacteristics,
                              ),
                              style: TextStyle(
                                fontSize: 13,
                                height: 1.5,
                                color: Colors.black.withOpacity(0.7),
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Dynamic Tags Section
                    if (top.matchedCharacteristics.isNotEmpty) ...[
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: top.matchedCharacteristics
                              .map((c) => _buildDynamicTag(c))
                              .toList(),
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // DESIGN YOUR OWN NAIL button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          context.push(
                            '/perfect-match/composition',
                            extra: top.matchedCharacteristics,
                          );
                        },
                        icon: const Icon(Icons.palette_outlined, size: 20),
                        label: Text(
                          S.of(context).designYourOwnNail,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.1,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryDark,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(26),
                          ),
                          shadowColor: AppColors.primary.withOpacity(0.4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Main Match Card
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: const Color(0xFFF3EFEA),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primaryDark.withOpacity(0.06),
                            blurRadius: 30,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Image Stack
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(30),
                                  topRight: Radius.circular(30),
                                ),
                                child: top.imageUrl.isNotEmpty
                                    ? Image.network(
                                        top.imageUrl,
                                        height: 280,
                                        width: double.infinity,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            _imagePlaceholder(280),
                                      )
                                    : _imagePlaceholder(280),
                              ),
                              // Score Badge
                              Positioned(
                                top: 16,
                                right: 16,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(0xFFFF4081),
                                        Color(0xFFFF80AB),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(20),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.15),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.stars_rounded,
                                        color: Colors.white,
                                        size: 14,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        '$matchPercentage% Match',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w900,
                                          fontSize: 12,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // Card Info Area
                          Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Center(
                                  child: Text(
                                    top.name,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontFamily: 'Georgia',
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primaryDark,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Center(
                                  child: Text(
                                    S.of(context).premiumNailDesign,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey.shade500,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.0,
                                    ),
                                  ),
                                ),

                                if (top.reasons.length > 1) ...[
                                  const SizedBox(height: 20),
                                  const Divider(color: Color(0xFFF3EFEA)),
                                  const SizedBox(height: 12),
                                  Text(
                                    S.of(context).styleFitReasons,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w800,
                                      color: Colors.black87,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  ...top.reasons
                                      .skip(1)
                                      .map(
                                        (reason) => Padding(
                                          padding: const EdgeInsets.only(
                                            bottom: 8,
                                          ),
                                          child: Row(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              const Icon(
                                                Icons
                                                    .check_circle_outline_rounded,
                                                color: AppColors.primary,
                                                size: 16,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  _cleanColorText(
                                                    reason,
                                                    top.matchedCharacteristics,
                                                  ),
                                                  style: const TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.black54,
                                                    height: 1.4,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                ],

                                const SizedBox(height: 28),

                                // Book this look button
                                Container(
                                  width: double.infinity,
                                  height: 54,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(27),
                                    gradient: const LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        Color(0xFFFF80AB),
                                      ],
                                      begin: Alignment.centerLeft,
                                      end: Alignment.centerRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: AppColors.primary.withOpacity(
                                          0.3,
                                        ),
                                        blurRadius: 15,
                                        offset: const Offset(0, 6),
                                      ),
                                    ],
                                  ),
                                  child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      borderRadius: BorderRadius.circular(27),
                                      onTap: () {
                                        HapticFeedback.mediumImpact();
                                        context.push(
                                          '/nail-variants/${top.nailVariantId}',
                                        );
                                      },
                                      child: Center(
                                        child: Text(
                                          S.of(context).bookThisDesign,
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 16,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Retake Quiz Outlined Button
                                OutlinedButton.icon(
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    context.push('/quiz');
                                  },
                                  icon: const Icon(
                                    Icons.refresh_rounded,
                                    size: 18,
                                    color: AppColors.primary,
                                  ),
                                  label: Text(
                                    S.of(context).takeAnotherAnalysis,
                                    style: const TextStyle(
                                      color: AppColors.primary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  style: OutlinedButton.styleFrom(
                                    minimumSize: const Size(
                                      double.infinity,
                                      50,
                                    ),
                                    side: const BorderSide(
                                      color: AppColors.primary,
                                      width: 1.5,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(25),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // You may also love Section in 2-Column Grid
              if (others.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  color: const Color(0xFFFFF6F9), // Subtle pink banner
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 32,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          S.of(context).youMayAlsoLike,
                          style: TextStyle(
                            fontSize: 20,
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text(
                          S.of(context).otherStyleFits,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // 2-Column Grid Layout
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 16,
                              childAspectRatio: 0.72,
                            ),
                        itemCount: others.length,
                        itemBuilder: (context, index) {
                          return _buildOtherCard(context, others[index]);
                        },
                      ),
                    ],
                  ),
                ),
              ],

              // Try Another Design Button at the very bottom (beautiful soft pink/rose gradient)
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
                child: Container(
                  width: double.infinity,
                  height: 54,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(27),
                    gradient: const LinearGradient(
                      colors: [Color(0xFFFF6B9C), Color(0xFFFF8EBC)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(27),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        // Navigate to /nails and pass results to show them on top
                        context.go('/nails', extra: _results);
                      },
                      child: Center(
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.palette_outlined,
                              color: Colors.white,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              S.of(context).tryAnotherDesign,
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Beautiful tag helper supporting color values and text replacement
  Widget _buildDynamicTag(MatchedCharacteristic char) {
    final isColor =
        char.category.toLowerCase() == 'color' && char.value.startsWith('#');
    Color? parsedColor;
    if (isColor) {
      try {
        final hexColor = char.value.replaceAll('#', '').trim();
        parsedColor = Color(int.parse('FF$hexColor', radix: 16));
      } catch (_) {}
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFD1E1), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.01),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (parsedColor != null) ...[
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: parsedColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12, width: 0.5),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            _cleanColorText(char.label, [char]),
            style: const TextStyle(
              fontSize: 12,
              color: Colors.black87,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  // Hiển thị Bottom Sheet chi tiết sự tương thích dành cho sản phẩm đề xuất thêm
  void _showMatchDetailBottomSheet(
    BuildContext context,
    QuizResultModel result,
  ) {
    final matchPercentage =
        (result.score <= 1 ? result.score * 100 : result.score).toInt();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFFFDFBF7), // Warm cream background
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(32),
              topRight: Radius.circular(32),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Thanh kéo drag handle
              Center(
                child: Container(
                  width: 48,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Tiêu đề & Match %
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          result.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontFamily: 'Georgia',
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          S.of(context).premiumNailDesign,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Score Badge
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFFF4081), Color(0xFFFF80AB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withOpacity(0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Text(
                      '$matchPercentage% Match',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Ảnh sản phẩm
              if (result.imageUrl.isNotEmpty) ...[
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.network(
                    result.imageUrl,
                    height: 200,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _imagePlaceholder(200),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Lý do phù hợp (Why it fits)
              if (result.reasons.isNotEmpty) ...[
                Text(
                  S.of(context).styleFitReasons,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxHeight: MediaQuery.of(context).size.height * 0.25,
                  ),
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: result.reasons
                          .map(
                            (reason) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    color: AppColors.primary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _cleanColorText(
                                        reason,
                                        result.matchedCharacteristics,
                                      ),
                                      style: const TextStyle(
                                        fontSize: 13,
                                        color: Colors.black87,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          .toList(),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Nút xem chi tiết
              Container(
                width: double.infinity,
                height: 52,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(26),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFFFF80AB)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(26),
                    onTap: () {
                      Navigator.pop(context); // Đóng Bottom Sheet
                      HapticFeedback.mediumImpact();
                      context.push('/nail-variants/${result.nailVariantId}');
                    },
                    child: Center(
                      child: Text(
                        S.of(context).viewDetail,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOtherCard(BuildContext context, QuizResultModel result) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF3EFEA), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              // Hiển thị bottom sheet chi tiết khi nhấn vào card đề xuất
              _showMatchDetailBottomSheet(context, result);
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: result.imageUrl.isNotEmpty
                            ? Image.network(
                                result.imageUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) =>
                                    _imagePlaceholder(double.infinity),
                              )
                            : _imagePlaceholder(double.infinity),
                      ),
                      // Small score badge on secondary recommendations
                      Positioned(
                        bottom: 8,
                        right: 8,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.85),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: const Color(0xFFFFD1E1),
                              width: 0.5,
                            ),
                          ),
                          child: Text(
                            '${(result.score <= 1 ? result.score * 100 : result.score).toInt()}% match',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryDark,
                          fontFamily: 'Georgia',
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (result.matchedCharacteristics.isNotEmpty)
                        Text(
                          result.matchedCharacteristics
                              .map(
                                (c) => _cleanColorText(
                                  c.label,
                                  result.matchedCharacteristics,
                                ),
                              )
                              .join(' • '),
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      appBar: AppBar(
        backgroundColor: const Color(0xFFFDFBF7),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.primaryDark,
          ),
          onPressed: () => context.go('/nails'),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: const BoxDecoration(
                  color: Color(0xFFFFF0F5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sentiment_dissatisfied_rounded,
                  color: AppColors.primary,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                S.of(context).noMatchingFound,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                  fontFamily: 'Georgia',
                ),
              ),
              const SizedBox(height: 8),
              Text(
                S.of(context).noMatchingDesc,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () => context.push('/quiz'),
                icon: const Icon(Icons.refresh_rounded),
                label: Text(S.of(context).retry),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(30),
                  ),
                  elevation: 5,
                  shadowColor: AppColors.primary.withOpacity(0.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _imagePlaceholder(double height) {
    return Container(
      height: height == double.infinity ? null : height,
      color: AppColors.primarySurface,
      child: const Center(
        child: Icon(Icons.spa_rounded, size: 32, color: AppColors.primary),
      ),
    );
  }
}
