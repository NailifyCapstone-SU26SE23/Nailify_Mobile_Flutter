import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../generated/l10n.dart';
import '../../data/models/nail_variant_rating_model.dart';
import '../../data/repositories/nail_variant_repository.dart';

class NailVariantRatingsSection extends StatefulWidget {
  final int nailVariantId;

  const NailVariantRatingsSection({
    super.key,
    required this.nailVariantId,
  });

  @override
  State<NailVariantRatingsSection> createState() =>
      _NailVariantRatingsSectionState();
}

class _NailVariantRatingsSectionState
    extends State<NailVariantRatingsSection> {
  static const int _pageSize = 5;

  late Future<NailVariantRatingPage> _ratingsFuture;
  int _page = 1;
  int? _stars;

  @override
  void initState() {
    super.initState();
    _ratingsFuture = _loadRatings();
  }

  @override
  void didUpdateWidget(covariant NailVariantRatingsSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.nailVariantId != widget.nailVariantId) {
      _page = 1;
      _stars = null;
      _ratingsFuture = _loadRatings();
    }
  }

  Future<NailVariantRatingPage> _loadRatings() {
    return getIt<NailVariantRepository>().getRatingsByNailVariant(
      nailVariantId: widget.nailVariantId,
      page: _page,
      pageSize: _pageSize,
      stars: _stars,
    );
  }

  void _reload({int? page, int? stars}) {
    setState(() {
      if (page != null) _page = page;
      if (stars != _stars) _page = 1;
      _stars = stars;
      _ratingsFuture = _loadRatings();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  S.of(context).ratingsTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontFamily: 'Georgia',
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              _StarFilterDropdown(
                value: _stars,
                onChanged: (value) => _reload(stars: value),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FutureBuilder<NailVariantRatingPage>(
            future: _ratingsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }

              final page = snapshot.data ?? NailVariantRatingPage.empty();
              if (page.items.isEmpty) {
                return _EmptyRatingsMessage(stars: _stars);
              }

              return Column(
                children: [
                  ...page.items.map((rating) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RatingCard(rating: rating),
                    );
                  }),
                  _RatingsPagination(
                    currentPage: page.currentPage,
                    totalPages: page.totalPages,
                    hasPrevious: page.hasPrevious,
                    hasNext: page.hasNext,
                    onPrevious: () => _reload(page: _page - 1, stars: _stars),
                    onNext: () => _reload(page: _page + 1, stars: _stars),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StarFilterDropdown extends StatelessWidget {
  final int? value;
  final ValueChanged<int?> onChanged;

  const _StarFilterDropdown({
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.borderLight),
        borderRadius: BorderRadius.circular(12),
        color: Colors.white,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<int?>(
            value: value,
            hint: const Text('All stars'),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            items: [
              const DropdownMenuItem<int?>(
                value: null,
                child: Text('All stars'),
              ),
              ...List.generate(5, (index) {
                final stars = index + 1;
                return DropdownMenuItem<int?>(
                  value: stars,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$stars'),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.star_rounded,
                        color: Color(0xFFFFB300),
                        size: 18,
                      ),
                    ],
                  ),
                );
              }),
            ],
            onChanged: onChanged,
          ),
        ),
      ),
    );
  }
}

class _EmptyRatingsMessage extends StatelessWidget {
  final int? stars;

  const _EmptyRatingsMessage({required this.stars});

  @override
  Widget build(BuildContext context) {
    final text = stars == null
        ? S.of(context).nailNotRatedMessage
        : 'No $stars-star ratings yet.';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8FA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  final NailVariantRatingModel rating;

  const _RatingCard({required this.rating});

  @override
  Widget build(BuildContext context) {
    final createdAt = _formatDate(rating.createdAt);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Stars(score: rating.overallScore),
              if (createdAt.isNotEmpty) ...[
                const Spacer(),
                Text(
                  createdAt,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
          if (rating.comment.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              rating.comment,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 14,
                height: 1.35,
              ),
            ),
          ],
          if (rating.imageUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Image.network(
                  rating.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: const Color(0xFFF5F5F7),
                      alignment: Alignment.center,
                      child: const Icon(
                        Icons.broken_image_outlined,
                        color: AppColors.textSecondary,
                      ),
                    );
                  },
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _ScorePill(label: 'Service', score: rating.serviceQuality),
              _ScorePill(label: 'Punctuality', score: rating.punctuality),
              _ScorePill(label: 'Cleanliness', score: rating.cleanliness),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '';
    final local = date.toLocal();
    return '${local.day.toString().padLeft(2, '0')}/'
        '${local.month.toString().padLeft(2, '0')}/'
        '${local.year}';
  }
}

class _Stars extends StatelessWidget {
  final int score;

  const _Stars({required this.score});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        final filled = index < score;
        return Icon(
          filled ? Icons.star_rounded : Icons.star_border_rounded,
          color: const Color(0xFFFFB300),
          size: 18,
        );
      }),
    );
  }
}

class _ScorePill extends StatelessWidget {
  final String label;
  final int score;

  const _ScorePill({
    required this.label,
    required this.score,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xFFFF4081).withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          '$label $score/5',
          style: const TextStyle(
            color: AppColors.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}

class _RatingsPagination extends StatelessWidget {
  final int currentPage;
  final int totalPages;
  final bool hasPrevious;
  final bool hasNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  const _RatingsPagination({
    required this.currentPage,
    required this.totalPages,
    required this.hasPrevious,
    required this.hasNext,
    required this.onPrevious,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            tooltip: 'Previous page',
            onPressed: hasPrevious ? onPrevious : null,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Text(
            '$currentPage / $totalPages',
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          IconButton(
            tooltip: 'Next page',
            onPressed: hasNext ? onNext : null,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
