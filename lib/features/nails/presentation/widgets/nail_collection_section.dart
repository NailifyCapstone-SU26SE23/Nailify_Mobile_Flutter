import 'package:flutter/material.dart';

import '../../data/models/nail_design_model.dart';
import 'nail_design_card.dart';

/// A single horizontally-scrolling "collection" row, e.g.
/// "Dành riêng cho bạn", "Xu hướng tuần này", "Móng Pháp cổ điển"...
///
/// Used to build a Netflix-style catalog on [NailListScreen] instead of
/// one uniform grid.
class NailCollectionSection extends StatelessWidget {
  final String title;
  final List<NailDesignModel> designs;

  /// Optional per-design match percentage, keyed by [NailDesignModel.nailDesignId].
  /// Only relevant for the "Dành riêng cho bạn" row.
  final Map<int, int> matchPercentages;

  final ValueChanged<NailDesignModel> onDesignTap;
  final VoidCallback? onSeeAll;

  /// Icon shown to the left of the title — use a sparkle for the
  /// personalized row, leave null for plain category rows.
  final IconData? titleIcon;

  const NailCollectionSection({
    super.key,
    required this.title,
    required this.designs,
    required this.onDesignTap,
    this.matchPercentages = const {},
    this.onSeeAll,
    this.titleIcon,
  });

  static const double _cardWidth = 160;
  static const double _cardHeight = 272;

  @override
  Widget build(BuildContext context) {
    if (designs.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Row(
              children: [
                if (titleIcon != null) ...[
                  Icon(titleIcon, size: 20, color: const Color(0xFFFF4081)),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Georgia',
                      letterSpacing: -0.4,
                      color: Color(0xFF1E1E24),
                    ),
                  ),
                ),
                if (onSeeAll != null)
                  GestureDetector(
                    onTap: onSeeAll,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF4081).withOpacity(0.06),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: const [
                          Text(
                            'Xem tất cả',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFFFF4081),
                            ),
                          ),
                          SizedBox(width: 2),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 14,
                            color: Color(0xFFFF4081),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(
            height: _cardHeight,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(), // Cuộn mượt bouncy kiểu iOS
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: designs.length,
              separatorBuilder: (_, __) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final design = designs[index];
                return SizedBox(
                  width: _cardWidth,
                  child: NailDesignCard(
                    design: design,
                    matchPercentage: matchPercentages[design.nailDesignId],
                    onTap: () => onDesignTap(design),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}