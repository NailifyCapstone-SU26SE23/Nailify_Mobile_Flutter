import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

import 'rating_star_badge.dart';

class ArtistSelectionList extends StatelessWidget {
  final List<dynamic> artists;
  final bool isLoading;
  final String? selectedStylistId;
  final bool noArtistSelected;
  final Function(Map<String, dynamic>?) onStylistSelected;
  final Function(bool isNoArtist) onModeChanged;

  const ArtistSelectionList({
    super.key,
    required this.artists,
    required this.isLoading,
    required this.selectedStylistId,
    required this.noArtistSelected,
    required this.onStylistSelected,
    required this.onModeChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── SECTION HEADER ─────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.people_alt_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Chọn thợ làm đẹp',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
                color: AppColors.primaryDark,
              ),
            ),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.amber.shade50, Colors.amber.shade100],
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.amber.shade200, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.star_rounded, size: 14, color: Colors.amber),
                  const SizedBox(width: 4),
                  Text(
                    'Rating cao nhất',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Colors.amber.shade900,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),

        // ── OPTION 1: TỰ ĐỘNG PHÂN CÔNG ───────────────────────────
        GestureDetector(
          onTap: () {
            onModeChanged(true);
            onStylistSelected(null);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.fastOutSlowIn,
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: noArtistSelected
                  ? const Color(0xFFFFF2F6)
                  : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: noArtistSelected
                    ? AppColors.primary
                    : const Color(0xFFF2ECE6),
                width: noArtistSelected ? 2 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: noArtistSelected
                      ? AppColors.primary.withValues(alpha: 0.15)
                      : Colors.black.withValues(alpha: 0.02),
                  blurRadius: noArtistSelected ? 14 : 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: noArtistSelected
                          ? [AppColors.primary, const Color(0xFFFF80AB)]
                          : [Colors.purple.shade50, Colors.pink.shade50],
                    ),
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    color: noArtistSelected ? Colors.white : AppColors.primary,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Tự động phân công',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15.5,
                          color: noArtistSelected
                              ? AppColors.primaryDark
                              : AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Hệ thống tự sắp xếp thợ phù hợp nhất',
                        style: TextStyle(
                          fontSize: 12.5,
                          color: Colors.grey.shade600,
                        ),
                      ),
                    ],
                  ),
                ),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: noArtistSelected
                        ? AppColors.primary
                        : Colors.transparent,
                    border: Border.all(
                      color: noArtistSelected
                          ? AppColors.primary
                          : Colors.grey.shade300,
                      width: 1.8,
                    ),
                  ),
                  child: noArtistSelected
                      ? const Icon(
                          Icons.check_rounded,
                          size: 16,
                          color: Colors.white,
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),

        // ── OPTION 2..N: DANH SÁCH THỢ SẮP XẾP THEO RATING ───────────
        if (artists.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 40),
            child: Center(
              child: Text(
                'Không tìm thấy danh sách thợ',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),
          )
        else
          ...artists.map((artist) {
            final String artistId =
                artist['nailArtistId']?.toString() ??
                artist['id']?.toString() ??
                '';
            final bool isSelected =
                !noArtistSelected && selectedStylistId == artistId;
            final String name = artist['fullName']?.toString() ?? 'Thợ nail';
            final num ratingNum = (artist['rating'] as num?) ?? 0;

            return GestureDetector(
              onTap: () {
                onModeChanged(false);
                onStylistSelected(
                  Map<String, dynamic>.from(artist as Map),
                );
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: Curves.fastOutSlowIn,
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFFFFF2F6) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFFF2ECE6),
                    width: isSelected ? 2 : 1,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: isSelected
                          ? AppColors.primary.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.02),
                      blurRadius: isSelected ? 14 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Avatar Ring
                    Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                      child: CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.grey.shade100,
                        backgroundImage: artist['avatarUrl'] != null
                            ? NetworkImage(artist['avatarUrl'])
                            : null,
                        child: artist['avatarUrl'] == null
                            ? const Icon(
                                Icons.person_rounded,
                                color: Colors.grey,
                                size: 26,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15.5,
                              color: isSelected
                                  ? AppColors.primaryDark
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 5),
                          RatingStarBadge(
                            rating: ratingNum.toDouble(),
                            showStarRow: true,
                            showLabel: true,
                          ),
                        ],
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isSelected
                            ? AppColors.primary
                            : Colors.transparent,
                        border: Border.all(
                          color: isSelected
                              ? AppColors.primary
                              : Colors.grey.shade300,
                          width: 1.8,
                        ),
                      ),
                      child: isSelected
                          ? const Icon(
                              Icons.check_rounded,
                              size: 16,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            );
          }),
      ],
    );
  }
}
