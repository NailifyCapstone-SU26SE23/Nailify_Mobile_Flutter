import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n.dart';
import 'rating_star_badge.dart';

class ArtistSelectionList extends StatefulWidget {
  final List<dynamic> artists;
  final bool isLoading;
  final String? selectedStylistId;
  final bool noArtistSelected;
  final Function(Map<String, dynamic>?) onStylistSelected;
  final Function(bool isNoArtist) onModeChanged;

  /// ID của thợ cần được ghim lên đầu danh sách (ví dụ: thợ đã làm trước
  /// đây trong luồng bảo hành). Khi `null`, danh sách giữ nguyên thứ tự
  /// từ API (rating giảm dần).
  final String? pinnedArtistId;

  /// Nhãn hiển thị trên badge của thợ được pin (mặc định: "Thợ đã làm trước đây").
  final String? pinnedLabel;

  /// Khi `true`: ẩn option "Tự động phân công" ở đầu danh sách. Dùng cho
  /// các luồng BẮT BUỘC phải chọn thợ (vd: home booking — cần thợ để list mẫu nail).
  final bool hideAutoAssign;

  const ArtistSelectionList({
    super.key,
    required this.artists,
    required this.isLoading,
    required this.selectedStylistId,
    required this.noArtistSelected,
    required this.onStylistSelected,
    required this.onModeChanged,
    this.pinnedArtistId,
    this.pinnedLabel,
    this.hideAutoAssign = false,
  });

  @override
  State<ArtistSelectionList> createState() => _ArtistSelectionListState();
}

class _ArtistSelectionListState extends State<ArtistSelectionList> {
  String _selectedSort = 'rating'; // 'rating', 'experience', 'name'

  /// Tách thợ được pin ra khỏi list (giữ nguyên thứ tự rating ở phần còn lại).
  (Map<String, dynamic>?, List<dynamic>) _splitPinnedArtist() {
    if (widget.pinnedArtistId == null || widget.pinnedArtistId!.isEmpty) {
      return (null, widget.artists);
    }
    Map<String, dynamic>? pinned;
    final remaining = <dynamic>[];
    for (final a in widget.artists) {
      if (a is! Map) {
        remaining.add(a);
        continue;
      }
      final id = a['nailArtistId']?.toString() ?? a['id']?.toString() ?? '';
      if (id == widget.pinnedArtistId && pinned == null) {
        pinned = Map<String, dynamic>.from(a);
      } else {
        remaining.add(a);
      }
    }
    return (pinned, remaining);
  }

  List<dynamic> _sortArtists(List<dynamic> list) {
    final sorted = List<dynamic>.from(list);
    if (_selectedSort == 'rating') {
      sorted.sort((a, b) {
        final rA = (a is Map ? (a['rating'] as num?) : null) ?? 5.0;
        final rB = (b is Map ? (b['rating'] as num?) : null) ?? 5.0;
        return rB.compareTo(rA);
      });
    } else if (_selectedSort == 'name') {
      sorted.sort((a, b) {
        final nameA = (a is Map ? (a['fullName'] ?? a['name'] ?? '') : '')
            .toString();
        final nameB = (b is Map ? (b['fullName'] ?? b['name'] ?? '') : '')
            .toString();
        return nameA.compareTo(nameB);
      });
    }
    return sorted;
  }

  String _getSortLabel(BuildContext context, String sort) {
    switch (sort) {
      case 'rating':
        return S.of(context).bookingArtistHighestRating;
      case 'experience':
        return S.of(context).bookingSortHighExpertise;
      case 'name':
        return S.of(context).bookingSortNameAZ;
      default:
        return S.of(context).bookingArtistHighestRating;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60),
        child: Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final (pinned, rawRemaining) = _splitPinnedArtist();
    final remaining = _sortArtists(rawRemaining);
    final label = widget.pinnedLabel ?? S.of(context).warrantyPinnedArtist;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── SECTION HEADER & FILTER POPUP ───────────────────────────
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
            Text(
              S.of(context).bookingSelectArtistTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
                color: AppColors.primaryDark,
              ),
            ),
            const Spacer(),

            // ── MODERN FILTER / SORT BUTTON ───────────────────────
            PopupMenuButton<String>(
              initialValue: _selectedSort,
              onSelected: (value) {
                setState(() {
                  _selectedSort = value;
                });
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 4,
              color: Colors.white,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [Colors.amber.shade50, Colors.amber.shade100],
                  ),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.amber.shade200, width: 0.9),
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
                    const Icon(
                      Icons.tune_rounded,
                      size: 13,
                      color: Colors.amber,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _getSortLabel(context, _selectedSort),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      Icons.arrow_drop_down_rounded,
                      size: 16,
                      color: Colors.amber.shade900,
                    ),
                  ],
                ),
              ),
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'rating',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.star_rounded,
                        size: 16,
                        color: Colors.amber,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        S.of(context).bookingArtistHighestRating,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _selectedSort == 'rating'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _selectedSort == 'rating'
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'experience',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.auto_awesome_rounded,
                        size: 16,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        S.of(context).bookingSortHighExpertise,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _selectedSort == 'experience'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _selectedSort == 'experience'
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'name',
                  child: Row(
                    children: [
                      const Icon(
                        Icons.sort_by_alpha_rounded,
                        size: 16,
                        color: Colors.blue,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        S.of(context).bookingSortNameAZ,
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: _selectedSort == 'name'
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: _selectedSort == 'name'
                              ? AppColors.primary
                              : AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 18),

        // ── OPTION 1: TỰ ĐỘNG PHÂN CÔNG (TOP CARD) ─────────────────
        if (!widget.hideAutoAssign)
          GestureDetector(
            onTap: () {
              widget.onModeChanged(true);
              widget.onStylistSelected(null);
            },
            child: _buildAutoAssignTile(),
          ),

        // ── OPTION 2: THỢ ĐƯỢC GHIM (nếu có) ──────────────────────
        if (pinned != null) ...[
          _buildArtistTile(pinned, index: 0, badgeLabel: label),
        ],

        // ── OPTION 3..N: CÁC THỢ CÒN LẠI ─────────────────────────
        if (remaining.isEmpty && pinned == null)
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
          ...remaining.asMap().entries.map(
            (entry) => _buildArtistTile(entry.value, index: entry.key),
          ),
      ],
    );
  }

  Widget _buildAutoAssignTile() {
    final bool isSelected = widget.noArtistSelected;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.fastOutSlowIn,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isSelected
              ? [const Color(0xFFFFF0F5), const Color(0xFFFFD6E5)]
              : [const Color(0xFFFFF9FB), const Color(0xFFFFF0F4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isSelected ? AppColors.primary : const Color(0xFFFFE4EC),
          width: isSelected ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.18)
                : Colors.pink.withValues(alpha: 0.04),
            blurRadius: isSelected ? 14 : 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Magic-wand icon container
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: isSelected
                    ? [AppColors.primary, const Color(0xFFFF4081)]
                    : [const Color(0xFFFFE4EC), const Color(0xFFFFF0F5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.3)
                      : Colors.transparent,
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: isSelected ? Colors.white : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context).bookingArtistAutoAssign,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: isSelected
                        ? AppColors.primaryDark
                        : AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  S.of(context).bookingArtistAutoAssignDesc,
                  style: TextStyle(fontSize: 12.5, color: Colors.grey.shade600),
                ),
              ],
            ),
          ),
          // Sleek minimalist radio button
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
              border: Border.all(
                color: isSelected ? AppColors.primary : Colors.grey.shade300,
                width: isSelected ? 6 : 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildArtistTile(
    dynamic artist, {
    required int index,
    String? badgeLabel,
  }) {
    if (artist is! Map) return const SizedBox.shrink();
    final String artistId =
        artist['nailArtistId']?.toString() ?? artist['id']?.toString() ?? '';
    final bool isSelected =
        !widget.noArtistSelected && widget.selectedStylistId == artistId;
    final String name =
        artist['fullName']?.toString() ??
        artist['name']?.toString() ??
        'Thợ nail';
    final num ratingNum = (artist['rating'] as num?) ?? 5.0;

    return GestureDetector(
      onTap: () {
        widget.onModeChanged(false);
        widget.onStylistSelected(Map<String, dynamic>.from(artist));
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
                : (badgeLabel != null
                      ? AppColors.primary.withValues(alpha: 0.5)
                      : const Color(0xFFF2ECE6)),
            width: isSelected ? 2 : (badgeLabel != null ? 1.5 : 1),
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
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Prominent Circular Profile Image (Radius 28 = 56px diameter)
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFFFCE4EC),
                  width: 2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.2)
                        : Colors.black.withValues(alpha: 0.05),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundColor: Colors.pink.shade50,
                backgroundImage:
                    artist['avatarUrl'] != null &&
                        '${artist['avatarUrl']}'.isNotEmpty
                    ? NetworkImage('${artist['avatarUrl']}')
                    : null,
                child:
                    artist['avatarUrl'] == null ||
                        '${artist['avatarUrl']}'.isEmpty
                    ? const Icon(
                        Icons.person_rounded,
                        color: AppColors.primary,
                        size: 32,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (badgeLabel != null) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      margin: const EdgeInsets.only(bottom: 6),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppColors.primary,
                            AppColors.primary.withValues(alpha: 0.7),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.history_rounded,
                            size: 12,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            badgeLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Artist Name (Bold)
                  Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected
                          ? AppColors.primaryDark
                          : AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 5),

                  // Rating Badge (Star row + 5.0 + Xuất sắc)
                  RatingStarBadge(
                    rating: ratingNum.toDouble(),
                    showStarRow: true,
                    showLabel: true,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Sleek minimalist radio button
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                border: Border.all(
                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                  width: isSelected ? 6 : 2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
