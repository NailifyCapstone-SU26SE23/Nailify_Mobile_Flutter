import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n.dart';

/// Kết quả chọn thợ: null = không chọn thợ (để hệ thống tự phân công).
typedef StylistSelectedCallback = void Function(Map<String, dynamic>? artist);

class BookingStylistSelection extends StatefulWidget {
  final List<dynamic> artists;
  final bool isLoading;
  final String? selectedStylistId;
  final bool isDateSelected;

  /// true = "Không chọn thợ" đang được kích hoạt
  final bool noArtistSelected;

  /// Callback trả về Map khi chọn thợ
  final StylistSelectedCallback onStylistSelected;

  /// Callback khi user chuyển qua lại giữa 2 tab
  final Function(bool isNoArtist) onModeChanged;

  const BookingStylistSelection({
    super.key,
    required this.artists,
    required this.isLoading,
    required this.selectedStylistId,
    required this.isDateSelected,
    required this.onStylistSelected,
    required this.onModeChanged,
    this.noArtistSelected = false,
  });

  @override
  State<BookingStylistSelection> createState() =>
      _BookingStylistSelectionState();
}

class _BookingStylistSelectionState extends State<BookingStylistSelection>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.noArtistSelected ? 1 : 0,
    );
  }

  @override
  void didUpdateWidget(covariant BookingStylistSelection oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newIndex = widget.noArtistSelected ? 1 : 0;
    if (_tabController.index != newIndex) {
      _tabController.animateTo(newIndex);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  String _getArtistName(dynamic artist, BuildContext context) {
    if (artist == null) return S.of(context).bookingArtistDefault;
    if (artist['fullName'] != null &&
        artist['fullName'].toString().isNotEmpty) {
      return artist['fullName'];
    }
    final firstName = artist['firstName']?.toString() ?? '';
    final lastName = artist['lastName']?.toString() ?? '';
    final combined = '$firstName $lastName'.trim();
    return combined.isNotEmpty ? combined : S.of(context).bookingArtistDefault;
  }

  void _showArtistPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      // Không set `shape` ở đây để tránh tạo DecoratedBox che ink splash
      // của ListTile bên dưới. Thay vào đó, wrap Material trong child.
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Material(
          color: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  S.of(context).bookingSelectArtistTitle,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                if (widget.isLoading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: CircularProgressIndicator(),
                  )
                else if (widget.artists.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    child: Text(S.of(context).bookingNoArtistAvailable),
                  )
                else
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        children: widget.artists.map((artist) {
                          final bool isSelected =
                              artist['nailArtistId'] ==
                                  widget.selectedStylistId;
                          final String displayName = _getArtistName(
                            artist,
                            context,
                          );
                          return ListTile(
                            leading: CircleAvatar(
                              backgroundColor: Colors.grey.shade200,
                              backgroundImage: artist['avatarUrl'] != null
                                  ? NetworkImage(artist['avatarUrl'])
                                  : null,
                              child: artist['avatarUrl'] == null
                                  ? const Icon(
                                      Icons.person,
                                      color: Colors.grey,
                                    )
                                  : null,
                            ),
                            title: Text(
                              displayName,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(
                                    Icons.check_circle,
                                    color: AppColors.primary,
                                  )
                                : null,
                            onTap: () {
                              // Ghi displayName vào map trước khi trả về
                              final safeArtist = Map<String, dynamic>.from(
                                artist as Map,
                              );
                              safeArtist['fullName'] = displayName;
                              widget.onStylistSelected(safeArtist);
                              Navigator.pop(context);
                            },
                          );
                        }).toList(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // ── Chưa chọn ngày → hiện placeholder ─────────────────────────────────
    if (!widget.isDateSelected) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            S.of(context).bookingSummaryArtist,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  color: Colors.grey.shade400,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Text(
                  S.of(context).bookingArtistNoDate,
                  style: TextStyle(
                    color: Colors.grey.shade500,
                    fontSize: 14,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
    }

    // ── Đã chọn ngày → hiện tab Chọn thợ / Không chọn thợ ─────────────────
    final matches = widget.artists.where(
      (a) => a['nailArtistId'] == widget.selectedStylistId,
    );
    final currentArtist = matches.isNotEmpty ? matches.first : null;

    // Dùng AnimatedBuilder để listen tab changes mà không cần TabBarView
    return AnimatedBuilder(
      animation: _tabController,
      builder: (context, _) {
        final selectedIndex = _tabController.index;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              S.of(context).bookingSummaryArtist,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 10),

            // Tab selector: Chọn thợ | Không chọn thợ
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(10),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(8),
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade600,
                labelStyle: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                dividerColor: Colors.transparent,
                onTap: (index) {
                  if (index == 1) {
                    widget.onModeChanged(true);
                  } else {
                    if (widget.noArtistSelected) {
                      widget.onModeChanged(false);
                    }
                  }
                },
                tabs: [
                  Tab(text: S.of(context).bookingArtistTab),
                  Tab(text: S.of(context).bookingNoArtistTab),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Nội dung theo tab — dùng IndexedStack thay TabBarView để tránh lỗi unbounded height
            IndexedStack(
              index: selectedIndex,
              children: [
                // Tab 0: Chọn thợ
                _buildSelectArtistTab(currentArtist),

                // Tab 1: Không chọn thợ
                _buildNoArtistTab(),
              ],
            ),
          ],
        );
      },
    );
  }

  Widget _buildSelectArtistTab(dynamic currentArtist) {
    // FIX: Khi đang loading → disable tap và hiện indicator trong ô
    if (widget.isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 12),
            Text(
              S.of(context).bookingLoadingArtists,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      );
    }

    return InkWell(
      onTap: () => _showArtistPicker(context),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderLight),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.face_retouching_natural,
                  color: AppColors.primary,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Text(
                  currentArtist != null
                      ? _getArtistName(currentArtist, context)
                      : S.of(context).bookingClickToSelectArtist,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: currentArtist != null
                        ? FontWeight.bold
                        : FontWeight.normal,
                    color: currentArtist != null
                        ? AppColors.textPrimary
                        : Colors.grey,
                  ),
                ),
              ],
            ),
            const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
          ],
        ),
      ),
    );
  }

  Widget _buildNoArtistTab() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primary.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.shuffle,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context).bookingAutoAssignTitle,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  S.of(context).bookingAutoAssignDesc,
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
          ),
          const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
        ],
      ),
    );
  }
}
