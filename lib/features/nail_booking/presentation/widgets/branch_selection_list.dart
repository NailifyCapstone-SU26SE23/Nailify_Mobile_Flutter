import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n.dart';

class BranchSelectionList extends StatelessWidget {
  final List<dynamic> salons;
  final bool isLoading;
  final String? selectedBranchId;
  final Function(dynamic) onBranchSelected;

  const BranchSelectionList({
    super.key,
    required this.salons,
    required this.isLoading,
    required this.selectedBranchId,
    required this.onBranchSelected,
  });

  static bool _isSalonOpen(dynamic salon) {
    if (salon == null || salon is! Map) return false;

    // 1. Status string check
    final status = (salon['status'] ?? salon['salonStatus'] ?? salon['state'])
        ?.toString()
        .trim()
        .toLowerCase() ?? '';
    if (status == 'closed' ||
        status == 'close' ||
        status == 'inactive' ||
        status == 'disabled' ||
        status == 'off' ||
        status == 'maintenance' ||
        status == 'đóng cửa' ||
        status == 'dong cua' ||
        status == 'ngừng hoạt động') {
      return false;
    }

    // 2. Explicit boolean flags
    final isClosedVal = salon['isClosed'];
    if (isClosedVal == true || isClosedVal == 1 || isClosedVal == 'true') {
      return false;
    }
    final isOpenVal = salon['isOpen'];
    if (isOpenVal == false || isOpenVal == 0 || isOpenVal == 'false') {
      return false;
    }
    final isOperatingVal = salon['isOperating'];
    if (isOperatingVal == false ||
        isOperatingVal == 0 ||
        isOperatingVal == 'false') {
      return false;
    }
    final isActiveVal = salon['isActive'];
    if (isActiveVal == false || isActiveVal == 0 || isActiveVal == 'false') {
      return false;
    }

    // 3. Operating hours check for current day
    final operatingHours = salon['operatingHours'];
    if (operatingHours is List && operatingHours.isNotEmpty) {
      final now = DateTime.now();
      // In Dart: Mon=1..Sun=7. In backend dayOfWeek: 0=Sun, 1=Mon, ..., 6=Sat.
      final currentDayOfWeek = now.weekday % 7;

      final todayHours = operatingHours
          .whereType<Map>()
          .where((h) {
            final day = h['dayOfWeek'];
            if (day == null) return false;
            final d = day is num ? day.toInt() : int.tryParse(day.toString());
            return d == currentDayOfWeek;
          })
          .toList();

      if (todayHours.isNotEmpty) {
        // Check if all segments for today are explicitly marked isClosed
        final allClosedToday = todayHours.every((h) {
          final isClosed = h['isClosed'];
          final isOpen = h['isOpen'];
          return isClosed == true ||
              isClosed == 1 ||
              isClosed == 'true' ||
              isOpen == false ||
              isOpen == 0 ||
              isOpen == 'false';
        });
        if (allClosedToday) {
          return false;
        }
      }
    }

    return true;
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }
    final openSalons = salons.where(_isSalonOpen).toList();

    if (openSalons.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Text(
            S.of(context).bookingNoBranch,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 15,
              fontWeight: FontWeight.w500,
            ),
          ),
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
                Icons.storefront_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Chọn tiệm dịch vụ',
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
                color: const Color(0xFFE8F5E9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFA5D6A7), width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      color: Color(0xFF2E7D32),
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  const Text(
                    'Đang mở cửa',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF2E7D32),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── DANH SÁCH SALON MỞ CỬA ──────────────────────────────────
        ...openSalons.map((salon) {
          final bool isSelected = selectedBranchId == salon['salonId'];
          final String name = salon['name'] ?? salon['salonName'] ?? 'Salon';
          final String address = salon['address'] ?? '';
          final String? rawImageUrl = salon['imageUrl'] ??
              salon['image'] ??
              salon['avatarUrl'] ??
              salon['logoUrl'] ??
              salon['salonImage'] ??
              salon['thumbnailUrl'] ??
              salon['photoUrl'] ??
              salon['pictureUrl'];
          final String? imageUrl =
              rawImageUrl != null && rawImageUrl.toString().trim().isNotEmpty
                  ? rawImageUrl.toString().trim()
                  : null;
          final num ratingNum = (salon['rating'] as num?) ?? 0.0;

          return GestureDetector(
            onTap: () => onBranchSelected(salon),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.fastOutSlowIn,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFFFF5F8) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFFF2ECE6),
                  width: isSelected ? 1.5 : 1,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.14)
                        : Colors.black.withValues(alpha: 0.02),
                    blurRadius: isSelected ? 14 : 6,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Salon Thumbnail Image / Gradient Icon Avatar
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.4)
                            : const Color(0xFFF3EFEA),
                        width: 1,
                      ),
                      gradient: imageUrl == null
                          ? LinearGradient(
                              colors: isSelected
                                  ? [
                                      AppColors.primary.withValues(alpha: 0.15),
                                      const Color(0xFFFFE4EC),
                                    ]
                                  : [
                                      const Color(0xFFFCFAF7),
                                      const Color(0xFFF5EFE6),
                                    ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(13),
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) => Icon(
                                Icons.storefront_rounded,
                                size: 26,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey.shade600,
                              ),
                            )
                          : Center(
                              child: Icon(
                                Icons.storefront_rounded,
                                size: 26,
                                color: isSelected
                                    ? AppColors.primary
                                    : Colors.grey.shade600,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(width: 14),

                  // Salon Details
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
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 13.5,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                address,
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: Colors.grey.shade600,
                                  height: 1.25,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        // Micro Chips Row: Open Status + Rating
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Text(
                                'Mở cửa',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32),
                                ),
                              ),
                            ),
                            if (ratingNum > 0) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 7,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFFF9E6),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: const Color(0xFFFFE082),
                                    width: 0.6,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 11,
                                      color: Color(0xFFFFB800),
                                    ),
                                    const SizedBox(width: 2),
                                    Text(
                                      ratingNum.toStringAsFixed(1),
                                      style: const TextStyle(
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF8C5300),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Selection Indicator
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

        // Spacing at bottom to prevent floating action bar from covering content
        const SizedBox(height: 100),
      ],
    );
  }
}
