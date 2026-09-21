import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n.dart';

class BranchSelectionList extends StatefulWidget {
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

  static bool isSalonOpen(dynamic salon) {
    if (salon == null || salon is! Map) return false;

    final status =
        (salon['status'] ?? salon['salonStatus'] ?? salon['state'])
            ?.toString()
            .trim()
            .toLowerCase() ??
        '';
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

    final operatingHours = salon['operatingHours'];
    if (operatingHours is List && operatingHours.isNotEmpty) {
      final now = DateTime.now();
      final currentDayOfWeek = now.weekday % 7;

      final todayHours = operatingHours.whereType<Map>().where((h) {
        final day = h['dayOfWeek'];
        if (day == null) return false;
        final d = day is num ? day.toInt() : int.tryParse(day.toString());
        return d == currentDayOfWeek;
      }).toList();

      if (todayHours.isNotEmpty) {
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
  State<BranchSelectionList> createState() => _BranchSelectionListState();
}

class OperatingHourGroup {
  final String dayLabel;
  final String timeRange;
  final bool isClosed;
  final bool containsToday;

  OperatingHourGroup({
    required this.dayLabel,
    required this.timeRange,
    required this.isClosed,
    required this.containsToday,
  });
}

class _BranchSelectionListState extends State<BranchSelectionList> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDistrict = '';
  bool _isExpanded = false;

  List<OperatingHourGroup> _groupOperatingHours(
    BuildContext context,
    List<dynamic> rawHours,
  ) {
    final bool isEn = Localizations.localeOf(context).languageCode == 'en';
    String formatTime(dynamic time) {
      if (time == null) return '';
      final str = time.toString().trim();
      final parts = str.split(':');
      if (parts.length >= 2) {
        return '${parts[0].padLeft(2, '0')}:${parts[1].padLeft(2, '0')}';
      }
      return str;
    }

    int getSortDay(dynamic dayOfWeek, dynamic dayName) {
      int numDay = -1;
      if (dayOfWeek is num) {
        numDay = dayOfWeek.toInt();
      } else if (dayOfWeek != null) {
        numDay = int.tryParse(dayOfWeek.toString()) ?? -1;
      }
      if (numDay == 0) return 7; // Sunday is 7th
      if (numDay > 0 && numDay <= 7) return numDay;

      final nameLower = (dayName ?? '').toString().toLowerCase();
      if (nameLower.contains('mon')) return 1;
      if (nameLower.contains('tue')) return 2;
      if (nameLower.contains('wed')) return 3;
      if (nameLower.contains('thu')) return 4;
      if (nameLower.contains('fri')) return 5;
      if (nameLower.contains('sat')) return 6;
      if (nameLower.contains('sun')) return 7;
      return 8;
    }

    String getDayName(int sortDay) {
      if (isEn) {
        switch (sortDay) {
          case 1:
            return 'Mon';
          case 2:
            return 'Tue';
          case 3:
            return 'Wed';
          case 4:
            return 'Thu';
          case 5:
            return 'Fri';
          case 6:
            return 'Sat';
          case 7:
            return 'Sun';
          default:
            return 'Day $sortDay';
        }
      }
      switch (sortDay) {
        case 1:
          return 'Thứ 2';
        case 2:
          return 'Thứ 3';
        case 3:
          return 'Thứ 4';
        case 4:
          return 'Thứ 5';
        case 5:
          return 'Thứ 6';
        case 6:
          return 'Thứ 7';
        case 7:
          return 'Chủ Nhật';
        default:
          return 'T$sortDay';
      }
    }

    final Map<int, Map<String, dynamic>> dayMap = {};
    if (rawHours.isNotEmpty) {
      for (final item in rawHours) {
        if (item is! Map) continue;
        final int sortDay = getSortDay(item['dayOfWeek'], item['dayName']);
        if (sortDay >= 1 && sortDay <= 7) {
          final bool isClosed = item['isClosed'] == true;
          final String openT = formatTime(item['openTime']);
          final String closeT = formatTime(item['closeTime']);
          final String timeStr = isClosed
              ? (isEn ? 'Closed' : 'Nghỉ')
              : (openT.isNotEmpty && closeT.isNotEmpty
                    ? '$openT - $closeT'
                    : '08:00 - 23:00');

          dayMap[sortDay] = {
            'sortDay': sortDay,
            'isClosed': isClosed,
            'timeRange': timeStr,
          };
        }
      }
    }

    final List<Map<String, dynamic>> full7Days = [];
    for (int d = 1; d <= 7; d++) {
      if (dayMap.containsKey(d)) {
        full7Days.add(dayMap[d]!);
      } else {
        full7Days.add({
          'sortDay': d,
          'isClosed': false,
          'timeRange': '08:00 - 23:00',
        });
      }
    }

    final int todayWeekday = DateTime.now().weekday; // 1 = Mon ... 7 = Sun
    final List<OperatingHourGroup> groups = [];

    int startIdx = 0;
    while (startIdx < full7Days.length) {
      int endIdx = startIdx;
      final String currentTime = full7Days[startIdx]['timeRange'];
      final bool currentClosed = full7Days[startIdx]['isClosed'];

      while (endIdx + 1 < full7Days.length &&
          full7Days[endIdx + 1]['timeRange'] == currentTime &&
          full7Days[endIdx + 1]['isClosed'] == currentClosed) {
        endIdx++;
      }

      final int startDay = full7Days[startIdx]['sortDay'];
      final int endDay = full7Days[endIdx]['sortDay'];

      String dayLabel;
      if (startDay == 1 && endDay == 7) {
        dayLabel = isEn ? 'Daily (Mon - Sun)' : 'Hàng ngày (T2 - CN)';
      } else if (startDay == endDay) {
        dayLabel = getDayName(startDay);
      } else {
        dayLabel = '${getDayName(startDay)} - ${getDayName(endDay)}';
      }

      bool containsToday = false;
      for (int d = startIdx; d <= endIdx; d++) {
        if (full7Days[d]['sortDay'] == todayWeekday) {
          containsToday = true;
          break;
        }
      }

      groups.add(
        OperatingHourGroup(
          dayLabel: dayLabel,
          timeRange: currentTime,
          isClosed: currentClosed,
          containsToday: containsToday,
        ),
      );

      startIdx = endIdx + 1;
    }

    return groups;
  }

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatShortAddress(String fullAddress) {
    if (fullAddress.isEmpty) return 'Chưa cập nhật địa chỉ';
    final parts = fullAddress.split(',');
    if (parts.length >= 2) {
      final short = '${parts[0].trim()}, ${parts[1].trim()}';
      if (short.length <= 32) return short;
    }
    if (fullAddress.length > 32) {
      return '${fullAddress.substring(0, 30)}...';
    }
    return fullAddress;
  }

  List<String> _extractDistricts(BuildContext context, List<dynamic> salons) {
    final String allLabel = S.of(context).allDistrictsFilter;
    final Set<String> districts = {allLabel};
    final regExp = RegExp(
      r'(Quận\s*\d+|TP\.\s*Thủ Đức|Thủ Đức|Bình Thạnh|Tân Bình|Gò Vấp|Phú Nhuận|Tân Phú|Bình Tân|Hóc Môn|Củ Chi|Nhà Bè|Quận\s*[A-ZÀ-Ỹa-zà-ỹ0-9]+)',
      caseSensitive: false,
    );
    for (final s in salons) {
      if (s is! Map) continue;
      final addr = (s['address'] ?? s['salonAddress'] ?? '').toString();
      final match = regExp.firstMatch(addr);
      if (match != null) {
        districts.add(match.group(0)!.trim());
      }
    }
    return districts.toList();
  }

  void _showSalonDetailsModal(
    BuildContext context,
    Map<String, dynamic> salon,
  ) {
    final bool isEn = Localizations.localeOf(context).languageCode == 'en';
    final String name = salon['name'] ?? salon['salonName'] ?? 'Salon';
    final String fullAddress =
        salon['address'] ??
        (isEn ? 'Address updating' : 'Chưa cập nhật địa chỉ');
    final String phone =
        salon['phoneNumber'] ??
        salon['phone'] ??
        (isEn ? 'No phone number' : 'Chưa có SĐT');
    final num ratingNum = (salon['rating'] as num?) ?? 0.0;
    final String? rawImageUrl =
        salon['imageUrl'] ??
        salon['image'] ??
        salon['avatarUrl'] ??
        salon['logoUrl'];

    final List<dynamic> rawHours = salon['operatingHours'] is List
        ? (salon['operatingHours'] as List)
        : [];

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Flexible(
                fit: FlexFit.loose,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 60,
                            height: 60,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: AppColors.primary.withValues(alpha: 0.3),
                              ),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(15),
                              child:
                                  rawImageUrl != null && rawImageUrl.isNotEmpty
                                  ? Image.network(
                                      rawImageUrl,
                                      fit: BoxFit.cover,
                                      errorBuilder:
                                          (context, error, stackTrace) =>
                                              const Icon(
                                                Icons.storefront_rounded,
                                                color: AppColors.primary,
                                                size: 30,
                                              ),
                                    )
                                  : const Icon(
                                      Icons.storefront_rounded,
                                      color: AppColors.primary,
                                      size: 30,
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  name,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.star_rounded,
                                      size: 16,
                                      color: Color(0xFFFFB800),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      ratingNum > 0
                                          ? ratingNum.toStringAsFixed(1)
                                          : S.of(context).highlyRated,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Builder(
                                      builder: (context) {
                                        final bool isOpen =
                                            BranchSelectionList.isSalonOpen(
                                              salon,
                                            );
                                        return Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 2,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isOpen
                                                ? const Color(0xFFE8F5E9)
                                                : const Color(0xFFFFEBEE),
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            isOpen
                                                ? S.of(context).salonOpenStatus
                                                : S
                                                      .of(context)
                                                      .salonClosedStatus,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: isOpen
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFFC62828),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 12),

                      // ── ADDRESS ──────────────────────────────────────────
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.location_on_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  S.of(context).detailedAddress,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  fullAddress,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textPrimary,
                                    height: 1.3,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // ── PHONE ──────────────────────────────────────────
                      Row(
                        children: [
                          const Icon(
                            Icons.phone_rounded,
                            color: AppColors.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                S.of(context).phoneTitle,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                phone,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // ── GIỜ MỞ CỬA SECTION (SMART GROUPING & CLEAN CARD AESTHETIC) ─────────
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFF1F5F9),
                            width: 1,
                          ),
                        ),
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFFFDF2F8),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.access_time_filled_rounded,
                                    size: 16,
                                    color: Color(0xFFE11D48),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  S.of(context).operatingHours,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF0F172A),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Column(
                              children: _groupOperatingHours(context, rawHours)
                                  .map((g) {
                                    return Container(
                                      margin: const EdgeInsets.symmetric(
                                        vertical: 3,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 8,
                                      ),
                                      decoration: BoxDecoration(
                                        color: g.containsToday
                                            ? const Color(0xFFFFF1F5)
                                            : Colors.transparent,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            g.dayLabel,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: g.containsToday
                                                  ? FontWeight.bold
                                                  : FontWeight.w500,
                                              color: g.containsToday
                                                  ? const Color(0xFFE11D48)
                                                  : const Color(0xFF334155),
                                            ),
                                          ),
                                          if (g.containsToday) ...[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE11D48),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                S.of(context).todayBadge,
                                                style: const TextStyle(
                                                  fontSize: 9.5,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          Text(
                                            g.timeRange,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: g.isClosed
                                                  ? const Color(0xFFEF4444)
                                                  : (g.containsToday
                                                        ? const Color(
                                                            0xFFE11D48,
                                                          )
                                                        : const Color(
                                                            0xFF0F172A,
                                                          )),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  })
                                  .toList(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    widget.onBranchSelected(salon);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(23),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    S.of(context).selectThisBranch,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
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

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 50),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    final allOpenSalons = widget.salons
        .where(BranchSelectionList.isSalonOpen)
        .toList();
    final districts = _extractDistricts(context, allOpenSalons);
    final String allLabel = S.of(context).allDistrictsFilter;
    if (_selectedDistrict.isEmpty) {
      _selectedDistrict = allLabel;
    }

    final openSalons = allOpenSalons.where((salon) {
      // 1. Search Query filter
      if (_searchQuery.isNotEmpty) {
        final name = (salon['name'] ?? salon['salonName'] ?? '')
            .toString()
            .toLowerCase();
        final address = (salon['address'] ?? '').toString().toLowerCase();
        if (!name.contains(_searchQuery) && !address.contains(_searchQuery)) {
          return false;
        }
      }

      // 2. District filter
      if (_selectedDistrict != allLabel &&
          _selectedDistrict != 'Tất cả' &&
          _selectedDistrict != 'All') {
        final address = (salon['address'] ?? salon['salonAddress'] ?? '')
            .toString()
            .toLowerCase();
        if (!address.contains(_selectedDistrict.toLowerCase())) {
          return false;
        }
      }

      return true;
    }).toList();

    // Limit initial display to 5 salons if not expanded and no search query active
    final bool hasSearchOrFilter =
        _searchQuery.isNotEmpty ||
        (_selectedDistrict != allLabel &&
            _selectedDistrict != 'Tất cả' &&
            _selectedDistrict != 'All');
    final int displayCount = (_isExpanded || hasSearchOrFilter)
        ? openSalons.length
        : (openSalons.length > 5 ? 5 : openSalons.length);
    final displayedSalons = openSalons.take(displayCount).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── SEARCH BAR ────────────────────────────
        Container(
          height: 46,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.9),
            borderRadius: BorderRadius.circular(23),
            border: Border.all(color: const Color(0xFFF3E5F5), width: 1),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.05),
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: TextField(
            controller: _searchController,
            style: const TextStyle(fontSize: 14),
            decoration: InputDecoration(
              hintText: S.of(context).searchSalonHint,
              hintStyle: TextStyle(fontSize: 13.5, color: Colors.grey.shade400),
              prefixIcon: const Icon(
                Icons.search_rounded,
                size: 20,
                color: AppColors.primary,
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () => _searchController.clear(),
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(vertical: 13),
            ),
          ),
        ),
        const SizedBox(height: 14),

        // ── DISTRICT FILTER CHIPS (For Large Salon Counts) ─────────
        if (districts.length > 2) ...[
          SizedBox(
            height: 34,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: districts.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final d = districts[index];
                final bool isSelected = _selectedDistrict == d;
                return ChoiceChip(
                  label: Text(
                    d,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isSelected
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: isSelected ? Colors.white : AppColors.primaryDark,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: AppColors.primary,
                  backgroundColor: Colors.white,
                  side: BorderSide(
                    color: isSelected
                        ? AppColors.primary
                        : const Color(0xFFE5D5D9),
                    width: 0.8,
                  ),
                  showCheckmark: false,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() {
                        _selectedDistrict = d;
                      });
                    }
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── SECTION HEADER ─────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.primaryLight.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.storefront_rounded,
                size: 20,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              S.of(context).bookingSelectSalonTitle,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                fontFamily: 'Georgia',
                color: AppColors.primaryDark,
                letterSpacing: -0.2,
              ),
            ),
            const Spacer(),

            // Informative Count Badge instead of static "Đang mở cửa" text
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F5),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFFF8BBD0), width: 0.8),
              ),
              child: Text(
                S.of(context).branchesCount('${openSalons.length}'),
                style: const TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── EMPTY STATE ─────────────────────────────────────────────
        if (openSalons.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Column(
                children: [
                  Icon(
                    Icons.storefront_outlined,
                    size: 48,
                    color: Colors.grey.shade300,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _searchQuery.isNotEmpty ||
                            (_selectedDistrict != allLabel &&
                                _selectedDistrict != 'Tất cả' &&
                                _selectedDistrict != 'All')
                        ? S.of(context).noMatchingSalon
                        : S.of(context).bookingNoBranch,
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),

        // ── SALON CARD LIST (GLASSMORPHISM STYLE) ───────────────────
        ...displayedSalons.map((salon) {
          final Map<String, dynamic> salonMap = Map<String, dynamic>.from(
            salon as Map,
          );
          final bool isSelected =
              widget.selectedBranchId == salonMap['salonId'];
          final String name =
              salonMap['name'] ?? salonMap['salonName'] ?? 'Salon';
          final String fullAddress = salonMap['address'] ?? '';
          final String shortAddress = _formatShortAddress(fullAddress);
          final String? rawImageUrl =
              salonMap['imageUrl'] ??
              salonMap['image'] ??
              salonMap['avatarUrl'] ??
              salonMap['logoUrl'] ??
              salonMap['salonImage'] ??
              salonMap['thumbnailUrl'];
          final String? imageUrl =
              rawImageUrl != null && rawImageUrl.toString().trim().isNotEmpty
              ? rawImageUrl.toString().trim()
              : null;
          final num ratingNum = (salonMap['rating'] as num?) ?? 4.0;
          final num? distanceKm =
              (salonMap['distanceKm'] as num?) ??
              (salonMap['distance'] as num?);

          return GestureDetector(
            onTap: () => widget.onBranchSelected(salonMap),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.fastOutSlowIn,
              margin: const EdgeInsets.only(bottom: 14),
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: isSelected
                    ? const Color(0xFFFFF5F8).withValues(alpha: 0.95)
                    : Colors.white.withValues(alpha: 0.88),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFFFCE4EC),
                  width: isSelected ? 1.5 : 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isSelected
                        ? AppColors.primary.withValues(alpha: 0.16)
                        : Colors.black.withValues(alpha: 0.03),
                    blurRadius: isSelected ? 16 : 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Salon Circular Avatar Image
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? AppColors.primary.withValues(alpha: 0.6)
                            : const Color(0xFFF3EFEA),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          blurRadius: 6,
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: imageUrl != null
                          ? Image.network(
                              imageUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: const Color(0xFFFFF0F5),
                                    child: Icon(
                                      Icons.storefront_rounded,
                                      size: 26,
                                      color: isSelected
                                          ? AppColors.primary
                                          : Colors.grey.shade600,
                                    ),
                                  ),
                            )
                          : Container(
                              color: const Color(0xFFFFF0F5),
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

                  // Salon Main Info
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
                            letterSpacing: -0.1,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),

                        // Short Address + Details Link
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.location_on_rounded,
                              size: 13,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                shortAddress,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 4),
                            GestureDetector(
                              onTap: () =>
                                  _showSalonDetailsModal(context, salonMap),
                              child: Text(
                                S.of(context).viewDetailsLink,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.primary,
                                  decoration: TextDecoration.underline,
                                  decorationColor: AppColors.primary,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),

                        // Status Badge + Simplified Bright Star Rating
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFE8F5E9),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                BranchSelectionList.isSalonOpen(salonMap)
                                    ? S.of(context).salonOpenStatus
                                    : S.of(context).salonClosedStatus,
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                  color:
                                      BranchSelectionList.isSalonOpen(salonMap)
                                      ? const Color(0xFF2E7D32)
                                      : Colors.red.shade700,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),

                            // Star Rating Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF8E1),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: const Color(0xFFFFE082),
                                  width: 0.6,
                                ),
                              ),
                              child: Text(
                                '${ratingNum.toStringAsFixed(1)} ⭐',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFFB78103),
                                ),
                              ),
                            ),

                            if (distanceKm != null) ...[
                              const SizedBox(width: 6),
                              Text(
                                '${distanceKm.toStringAsFixed(1)} km',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: Colors.grey.shade500,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Integrated Checkmark Overlay when Selected
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 220),
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: isSelected
                          ? const LinearGradient(
                              colors: [AppColors.primary, Color(0xFFFF4081)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            )
                          : null,
                      color: isSelected ? null : Colors.transparent,
                      border: Border.all(
                        color: isSelected
                            ? Colors.transparent
                            : const Color(0xFFE0D0D5),
                        width: 1.5,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: AppColors.primary.withValues(alpha: 0.4),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: isSelected
                        ? const Icon(
                            Icons.check_rounded,
                            size: 17,
                            color: Colors.white,
                          )
                        : null,
                  ),
                ],
              ),
            ),
          );
        }),

        // ── SHOW MORE / EXPAND BUTTON (If > 5 Salons) ──────────────
        if (!hasSearchOrFilter && openSalons.length > 5)
          Center(
            child: Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 14),
              child: TextButton.icon(
                onPressed: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                icon: Icon(
                  _isExpanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  color: AppColors.primary,
                ),
                label: Text(
                  _isExpanded
                      ? S.of(context).collapseList
                      : S
                            .of(context)
                            .viewMoreBranches('${openSalons.length - 5}'),
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),

        const SizedBox(height: 90),
      ],
    );
  }
}
