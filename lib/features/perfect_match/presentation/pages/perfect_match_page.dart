import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import '../../../../generated/l10n.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';
import '../../../quiz/data/datasources/quiz_repository.dart';
import '../../../quiz/data/models/quiz_result_model.dart';

// ─────────────────────────────────────────────────────────────
// Root Page
// ─────────────────────────────────────────────────────────────

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

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: _PM.bg,
        body: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (_error != null) {
      return _ErrorView(error: _error!, onRetry: _loadRecommendations);
    }

    if (_results.isEmpty) {
      return _EmptyView();
    }

    // Aggregate preferences (isMatchingPreference == true) from all results, dedup
    final seen = <String>{};
    final allPrefs = <MatchedCharacteristic>[];
    for (final r in _results) {
      for (final c in r.matchedCharacteristics) {
        if (c.isMatchingPreference) {
          final key = '${c.category}__${c.value}';
          if (seen.add(key)) allPrefs.add(c);
        }
      }
    }

    final top = _results.first;
    final others = _results.length > 1
        ? _results.sublist(1)
        : <QuizResultModel>[];

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/nails');
      },
      child: Scaffold(
        backgroundColor: _PM.bg,
        appBar: _buildAppBar(context),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero headline ──
                    _HeroHeadline(),
                    const SizedBox(height: 24),

                    // ── Khối 1: Style Profile ──
                    StyleProfileCard(preferences: allPrefs),
                    const SizedBox(height: 20),

                    // ── Nút tự thiết kế ──
                    _DesignOwnButton(
                      onTap: () => context.push(
                        '/perfect-match/composition',
                        extra: allPrefs,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // ── Khối 2: Top Match Card ──
                    Text('Mẫu móng chuẩn gu nhất', style: _PM.sectionTitle),
                    const SizedBox(height: 4),
                    Text(
                      'Điểm tương thích cao nhất với phong cách của bạn',
                      style: _PM.sectionSubtitle,
                    ),
                    const SizedBox(height: 14),
                    TopMatchCard(
                      result: top,
                      onBookPressed: () {
                        HapticFeedback.mediumImpact();
                        context.push('/nail-variants/${top.nailVariantId}');
                      },
                      onDesignOwn: () => context.push(
                        '/perfect-match/composition',
                        extra: allPrefs,
                      ),
                      onRetakeQuiz: () => context.push('/quiz'),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),

            // ── Khối 3: Suggestions Grid ──
            if (others.isNotEmpty) ...[
              SliverToBoxAdapter(
                child: Container(
                  color: const Color(0xFFFFF6F9),
                  padding: const EdgeInsets.fromLTRB(20, 28, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Có thể bạn cũng thích', style: _PM.sectionTitle),
                      const SizedBox(height: 4),
                      Text(
                        'Các thiết kế khác phù hợp với phong cách của bạn',
                        style: _PM.sectionSubtitle,
                      ),
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverGrid(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) => SuggestionCard(
                      result: others[i],
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showDetailSheet(context, others[i]);
                      },
                    ),
                    childCount: others.length,
                  ),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 14,
                    childAspectRatio: 0.68,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  AppBar _buildAppBar(BuildContext context) {
    return AppBar(
      backgroundColor: _PM.bg,
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: const Icon(
          Icons.arrow_back_ios_new_rounded,
          color: AppColors.primaryDark,
          size: 20,
        ),
        onPressed: () => context.go('/nails'),
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
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
      centerTitle: true,
    );
  }

  void _showDetailSheet(BuildContext context, QuizResultModel result) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DetailBottomSheet(result: result),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Design constants
// ─────────────────────────────────────────────────────────────

class _PM {
  static const Color bg = Color(0xFFFDFBF7);
  static const Color cardBg = Colors.white;
  static const Color pinkLight = Color(0xFFFFF0F5);
  static const Color pinkBorder = Color(0xFFFFD1E1);
  static const Color accent = Color(0xFFFF4081);

  static final TextStyle sectionTitle = const TextStyle(
    fontSize: 20,
    fontFamily: 'Georgia',
    fontWeight: FontWeight.bold,
    color: AppColors.primaryDark,
  );

  static final TextStyle sectionSubtitle = TextStyle(
    fontSize: 12,
    color: Colors.grey.shade600,
    fontWeight: FontWeight.w500,
  );
}

// ─────────────────────────────────────────────────────────────
// Hero Headline
// ─────────────────────────────────────────────────────────────

class _HeroHeadline extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isEn = Localizations.localeOf(context).languageCode == 'en';
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.primary,
              size: 14,
            ),
            const SizedBox(width: 8),
            Text(
              S.of(context).forYouTitle,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(width: 8),
            const Icon(
              Icons.auto_awesome_outlined,
              color: AppColors.primary,
              size: 14,
            ),
          ],
        ),
        const SizedBox(height: 10),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: const TextStyle(
              fontSize: 28,
              color: Colors.black87,
              fontFamily: 'Georgia',
              height: 1.25,
            ),
            children: isEn
                ? [
                    const TextSpan(text: 'Your '),
                    const TextSpan(
                      text: 'perfect',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const TextSpan(text: ' nail designs'),
                  ]
                : [
                    const TextSpan(text: 'Mẫu móng '),
                    const TextSpan(
                      text: 'hoàn hảo nhất',
                      style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const TextSpan(text: ' của bạn'),
                  ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Khối 1 — Style Profile Card
// ─────────────────────────────────────────────────────────────

class StyleProfileCard extends StatelessWidget {
  final List<MatchedCharacteristic> preferences;

  const StyleProfileCard({super.key, required this.preferences});

  // Group preferences by logical category bucket
  Map<String, List<MatchedCharacteristic>> _group() {
    final groups = <String, List<MatchedCharacteristic>>{
      'Style': [],
      'Shape & Complexity': [],
      'Color': [],
      'Occasion & Theme': [],
      'Other': [],
    };
    for (final c in preferences) {
      final cat = c.category.toLowerCase();
      if (cat == 'style') {
        groups['Style']!.add(c);
      } else if (cat == 'shape' ||
          cat == 'complexity' ||
          cat == 'length & shape') {
        groups['Shape & Complexity']!.add(c);
      } else if (cat == 'color') {
        groups['Color']!.add(c);
      } else if (cat == 'occasion' || cat == 'theme') {
        groups['Occasion & Theme']!.add(c);
      } else {
        groups['Other']!.add(c);
      }
    }
    // Remove empty groups
    groups.removeWhere((_, v) => v.isEmpty);
    return groups;
  }

  @override
  Widget build(BuildContext context) {
    if (preferences.isEmpty) return const SizedBox.shrink();

    final groups = _group();
    final mainStyle = preferences
        .firstWhere(
          (c) => c.category.toLowerCase() == 'style',
          orElse: () => preferences.first,
        )
        .label;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF6F9), Color(0xFFFFF0F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _PM.pinkBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withOpacity(0.05),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
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
              const Text(
                'Hồ sơ phong cách của bạn',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppColors.primaryDark,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Main style badge
          RichText(
            text: TextSpan(
              style: const TextStyle(fontSize: 15, color: Colors.black87),
              children: [
                const TextSpan(
                  text: 'Phong cách cá nhân của bạn: ',
                  style: TextStyle(fontWeight: FontWeight.w500),
                ),
                TextSpan(
                  text: mainStyle,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w900,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Group sections
          ...groups.entries.map((entry) {
            return _GroupSection(
              title: _groupLabel(entry.key),
              icon: _groupIcon(entry.key),
              characteristics: entry.value,
            );
          }),
        ],
      ),
    );
  }

  String _groupLabel(String key) {
    switch (key) {
      case 'Style':
        return 'Phong cách chủ đạo';
      case 'Shape & Complexity':
        return 'Dáng móng & Độ phức tạp';
      case 'Color':
        return 'Bảng màu yêu thích';
      case 'Occasion & Theme':
        return 'Dịp & Chủ đề phù hợp';
      default:
        return 'Đặc điểm khác';
    }
  }

  IconData _groupIcon(String key) {
    switch (key) {
      case 'Style':
        return Icons.style_rounded;
      case 'Shape & Complexity':
        return Icons.fingerprint_rounded;
      case 'Color':
        return Icons.palette_rounded;
      case 'Occasion & Theme':
        return Icons.event_rounded;
      default:
        return Icons.label_rounded;
    }
  }
}

class _GroupSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<MatchedCharacteristic> characteristics;

  const _GroupSection({
    required this.title,
    required this.icon,
    required this.characteristics,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 13, color: AppColors.primaryDark),
              const SizedBox(width: 6),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primaryDark,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: characteristics
                .map((c) => _PreferenceChip(characteristic: c))
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _PreferenceChip extends StatelessWidget {
  final MatchedCharacteristic characteristic;

  const _PreferenceChip({required this.characteristic});

  @override
  Widget build(BuildContext context) {
    final isColor =
        characteristic.category.toLowerCase() == 'color' &&
        characteristic.value.startsWith('#');
    Color? parsedColor;
    if (isColor) {
      try {
        final hex = characteristic.value.replaceAll('#', '').trim();
        parsedColor = Color(int.parse('FF$hex', radix: 16));
      } catch (_) {}
    }

    final displayLabel = isColor && parsedColor != null
        ? _colorName(parsedColor)
        : characteristic.label;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _PM.pinkBorder, width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
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
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: parsedColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.black12, width: 0.5),
              ),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            displayLabel,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  /// Euclidean RGB distance → closest Vietnamese color name
  String _colorName(Color c) {
    final anchors = <String, List<int>>{
      'Đỏ': [255, 0, 0],
      'Hồng': [255, 107, 156],
      'Hồng đậm': [255, 64, 129],
      'Xanh dương': [0, 0, 255],
      'Xanh lá': [0, 200, 0],
      'Vàng': [255, 220, 0],
      'Nude': [245, 203, 167],
      'Đen': [0, 0, 0],
      'Trắng': [255, 255, 255],
      'Xám': [128, 128, 128],
      'Tím': [150, 0, 180],
      'Cam': [255, 140, 0],
      'Nâu': [139, 69, 19],
      'Hồng nhạt': [255, 220, 236],
      'Xanh mint': [0, 200, 180],
    };
    final r = c.red, g = c.green, b = c.blue;
    String closest = 'Màu sắc';
    double minD = double.maxFinite;
    for (final e in anchors.entries) {
      final dr = r - e.value[0], dg = g - e.value[1], db = b - e.value[2];
      final d = (dr * dr + dg * dg + db * db).toDouble();
      if (d < minD) {
        minD = d;
        closest = e.key;
      }
    }
    return closest;
  }
}

// ─────────────────────────────────────────────────────────────
// Design Own Button
// ─────────────────────────────────────────────────────────────

class _DesignOwnButton extends StatelessWidget {
  final VoidCallback onTap;
  const _DesignOwnButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 52,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.palette_outlined, size: 18),
        label: Text(
          S.of(context).designYourOwnNail,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryDark,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(26),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Khối 2 — Top Match Card
// ─────────────────────────────────────────────────────────────

class TopMatchCard extends StatelessWidget {
  final QuizResultModel result;
  final VoidCallback onBookPressed;
  final VoidCallback onDesignOwn;
  final VoidCallback onRetakeQuiz;

  const TopMatchCard({
    super.key,
    required this.result,
    required this.onBookPressed,
    required this.onDesignOwn,
    required this.onRetakeQuiz,
  });

  @override
  Widget build(BuildContext context) {
    final matchPct = (result.score <= 1 ? result.score * 100 : result.score)
        .toInt();
    final priceStr = '${NumberFormat('#,###', 'vi_VN').format(result.price)}đ';
    final durationStr = result.duration > 0 ? '${result.duration} phút' : '';

    return Container(
      decoration: BoxDecoration(
        color: _PM.cardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: const Color(0xFFF3EFEA), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withOpacity(0.07),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Image with badge ──
          Stack(
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
                child: result.imageUrl.isNotEmpty
                    ? Image.network(
                        result.imageUrl,
                        height: 280,
                        width: double.infinity,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => _imgPlaceholder(280),
                      )
                    : _imgPlaceholder(280),
              ),
              // Match badge
              Positioned(
                top: 16,
                right: 16,
                child: _MatchBadge(percent: matchPct, large: true),
              ),
            ],
          ),

          // ── Info area ──
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name
                Text(
                  result.name,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 22,
                    fontFamily: 'Georgia',
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 12),

                // Price & Duration row
                Row(
                  children: [
                    _InfoPill(
                      icon: Icons.sell_outlined,
                      text: priceStr,
                      color: AppColors.primary,
                    ),
                    if (durationStr.isNotEmpty) ...[
                      const SizedBox(width: 10),
                      _InfoPill(
                        icon: Icons.access_time_rounded,
                        text: durationStr,
                        color: AppColors.primaryDark,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 20),

                // Reasons (why it fits)
                if (result.reasons.isNotEmpty) ...[
                  const Divider(color: Color(0xFFF3EFEA), height: 1),
                  const SizedBox(height: 16),
                  Text(
                    S.of(context).styleFitReasons,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.black87,
                      letterSpacing: 0.2,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...result.reasons.map(
                    (r) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
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
                              r,
                              style: const TextStyle(
                                fontSize: 13,
                                color: Colors.black54,
                                height: 1.45,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],

                const SizedBox(height: 20),

                // CTA — Book
                _GradientButton(
                  label: S.of(context).bookThisDesign,
                  onTap: onBookPressed,
                ),
                const SizedBox(height: 12),

                // Secondary — Retake
                OutlinedButton.icon(
                  onPressed: onRetakeQuiz,
                  icon: const Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  label: Text(
                    S.of(context).takeAnotherAnalysis,
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 48),
                    side: const BorderSide(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  const _InfoPill({
    required this.icon,
    required this.text,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Text(
            text,
            style: TextStyle(
              fontSize: 13,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Khối 3 — Suggestion Card (grid item)
// ─────────────────────────────────────────────────────────────

class SuggestionCard extends StatelessWidget {
  final QuizResultModel result;
  final VoidCallback onTap;

  const SuggestionCard({super.key, required this.result, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final matchPct = (result.score <= 1 ? result.score * 100 : result.score)
        .toInt();

    // Top-3 matching tags only (matching first)
    final tags = [
      ...result.matchedCharacteristics.where((c) => c.isMatchingPreference),
      ...result.matchedCharacteristics.where((c) => !c.isMatchingPreference),
    ].take(3).toList();

    final priceStr = result.price > 0
        ? '${NumberFormat('#,###', 'vi_VN').format(result.price)}đ'
        : '';

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: _PM.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF3EFEA), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Image
              Expanded(
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    result.imageUrl.isNotEmpty
                        ? Image.network(
                            result.imageUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) =>
                                _imgPlaceholder(double.infinity),
                          )
                        : _imgPlaceholder(double.infinity),
                    // Match badge
                    Positioned(
                      bottom: 8,
                      right: 8,
                      child: _MatchBadge(percent: matchPct, large: false),
                    ),
                  ],
                ),
              ),

              // Text area
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryDark,
                        fontFamily: 'Georgia',
                        height: 1.3,
                      ),
                    ),
                    if (priceStr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        priceStr,
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                    if (tags.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 4,
                        runSpacing: 4,
                        children: tags
                            .map(
                              (c) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: c.isMatchingPreference
                                      ? AppColors.primary.withOpacity(0.10)
                                      : const Color(0xFFF5F5F5),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  c.label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 9,
                                    color: c.isMatchingPreference
                                        ? AppColors.primary
                                        : Colors.black54,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Detail Bottom Sheet
// ─────────────────────────────────────────────────────────────

class _DetailBottomSheet extends StatelessWidget {
  final QuizResultModel result;
  const _DetailBottomSheet({required this.result});

  @override
  Widget build(BuildContext context) {
    final matchPct = (result.score <= 1 ? result.score * 100 : result.score)
        .toInt();
    final priceStr = result.price > 0
        ? '${NumberFormat('#,###', 'vi_VN').format(result.price)}đ'
        : '';

    return Container(
      decoration: const BoxDecoration(
        color: _PM.bg,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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

          // Title + badge
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
                    if (priceStr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        priceStr,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              _MatchBadge(percent: matchPct, large: true),
            ],
          ),
          const SizedBox(height: 18),

          // Image
          if (result.imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.network(
                result.imageUrl,
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _imgPlaceholder(200),
              ),
            ),
          const SizedBox(height: 18),

          // Reasons
          if (result.reasons.isNotEmpty) ...[
            Text(
              S.of(context).styleFitReasons,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 10),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.22,
              ),
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: result.reasons
                      .map(
                        (r) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
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
                                  r,
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
            const SizedBox(height: 20),
          ],

          // CTA
          _GradientButton(
            label: S.of(context).viewDetail,
            onTap: () {
              Navigator.pop(context);
              HapticFeedback.mediumImpact();
              context.push('/nail-variants/${result.nailVariantId}');
            },
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Shared small widgets
// ─────────────────────────────────────────────────────────────

class _MatchBadge extends StatelessWidget {
  final int percent;
  final bool large;
  const _MatchBadge({required this.percent, required this.large});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: large ? 14 : 8,
        vertical: large ? 7 : 4,
      ),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF4081), Color(0xFFFF80AB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(large ? 20 : 10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (large) ...[
            const Icon(Icons.stars_rounded, color: Colors.white, size: 13),
            const SizedBox(width: 4),
          ],
          Text(
            '$percent% Match',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: large ? 12 : 9,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _GradientButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _GradientButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
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
            color: AppColors.primary.withOpacity(0.35),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(26),
          onTap: onTap,
          child: Center(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 0.5,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Error & Empty states
// ─────────────────────────────────────────────────────────────

class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _PM.bg,
      appBar: AppBar(
        backgroundColor: _PM.bg,
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
          padding: const EdgeInsets.all(24),
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
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.black54),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: onRetry,
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
}

class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _PM.bg,
      appBar: AppBar(
        backgroundColor: _PM.bg,
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
          padding: const EdgeInsets.all(32),
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
                style: const TextStyle(
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
                style: const TextStyle(
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
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────
// Image placeholder
// ─────────────────────────────────────────────────────────────

Widget _imgPlaceholder(double height) {
  return Container(
    height: height == double.infinity ? null : height,
    color: AppColors.primarySurface,
    child: const Center(
      child: Icon(Icons.spa_rounded, size: 32, color: AppColors.primary),
    ),
  );
}
