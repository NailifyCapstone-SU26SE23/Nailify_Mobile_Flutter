import 'package:flutter/material.dart';

class RatingStarBadge extends StatelessWidget {
  final double rating;
  final bool showStarRow;
  final bool showLabel;
  final double starSize;
  final bool isCompact;

  const RatingStarBadge({
    super.key,
    required this.rating,
    this.showStarRow = true,
    this.showLabel = false,
    this.starSize = 13,
    this.isCompact = false,
  });

  String _getRatingLabel(double score) {
    if (score >= 4.9 || score == 0) return 'Xuất sắc';
    if (score >= 4.5) return 'Rất tốt';
    if (score >= 4.0) return 'Tốt';
    return 'Đánh giá cao';
  }

  Widget _buildStarRow(double score) {
    final double safeScore = score > 0 ? score : 5.0;
    final int fullStars = safeScore.floor().clamp(0, 5);
    final bool hasHalf = (safeScore - fullStars) >= 0.3;

    final List<Widget> stars = [];
    for (int i = 0; i < 5; i++) {
      if (i < fullStars) {
        stars.add(
          Icon(
            Icons.star_rounded,
            size: starSize,
            color: const Color(0xFFFFB800),
          ),
        );
      } else if (i == fullStars && hasHalf) {
        stars.add(
          Icon(
            Icons.star_half_rounded,
            size: starSize,
            color: const Color(0xFFFFB800),
          ),
        );
      } else {
        stars.add(
          Icon(
            Icons.star_rounded,
            size: starSize,
            color: const Color(0xFFE0E0E0),
          ),
        );
      }
    }
    return Row(mainAxisSize: MainAxisSize.min, children: stars);
  }

  @override
  Widget build(BuildContext context) {
    final double safeRating = rating > 0 ? rating : 5.0;

    if (isCompact) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFFFFF9E6), Color(0xFFFFF0C2)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFFFE082), width: 0.8),
          boxShadow: [
            BoxShadow(
              color: Colors.amber.withValues(alpha: 0.15),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB800)),
            const SizedBox(width: 3),
            Text(
              safeRating.toStringAsFixed(1),
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF8C5300),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF9E6), Color(0xFFFFF0C2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFE082), width: 0.9),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showStarRow) ...[
            _buildStarRow(safeRating),
            const SizedBox(width: 5),
          ] else ...[
            const Icon(Icons.star_rounded, size: 14, color: Color(0xFFFFB800)),
            const SizedBox(width: 3),
          ],
          Text(
            safeRating.toStringAsFixed(1),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: Color(0xFF8C5300),
            ),
          ),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              '• ${_getRatingLabel(safeRating)}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Color(0xFFA06000),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
