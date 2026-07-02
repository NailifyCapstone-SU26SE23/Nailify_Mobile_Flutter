import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Kết quả chọn thợ: null = không chọn thợ (để hệ thống tự phân công).
typedef StylistSelectedCallback = void Function(Map<String, dynamic>? artist);

class BookingStylistSelection extends StatefulWidget {
  final List<dynamic> artists;
  final bool isLoading;
  final String? selectedStylistId;

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

  String _getArtistName(dynamic artist) {
    if (artist == null) return 'Thợ';
    if (artist['fullName'] != null &&
        artist['fullName'].toString().isNotEmpty) {
      return artist['fullName'];
    }
    final firstName = artist['firstName']?.toString() ?? '';
    final lastName = artist['lastName']?.toString() ?? '';
    final combined = '$firstName $lastName'.trim();
    return combined.isNotEmpty ? combined : 'Thợ';
  }

  void _showArtistPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chọn thợ làm móng',
                style: TextStyle(
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
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text('Không có thợ nào khả dụng cho ngày này.'),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    child: Column(
                      children: widget.artists.map((artist) {
                        final bool isSelected =
                            artist['nailArtistId'] == widget.selectedStylistId;
                        final String displayName = _getArtistName(artist);
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: Colors.grey.shade200,
                            backgroundImage: artist['avatarUrl'] != null
                                ? NetworkImage(artist['avatarUrl'])
                                : null,
                            child: artist['avatarUrl'] == null
                                ? const Icon(Icons.person, color: Colors.grey)
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
                            artist['fullName'] = displayName;
                            final safeArtist = Map<String, dynamic>.from(
                              artist as Map,
                            );
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
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
            const Text(
              'Thợ thực hiện',
              style: TextStyle(
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
                tabs: const [
                  Tab(text: 'Chọn thợ'),
                  Tab(text: 'Không chọn thợ'),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Nội dung theo tab — dùng IndexedStack thay TabBarView để tránh lỗi unbounded height
            IndexedStack(
              index: selectedIndex,
              children: [
                // Tab 0: Chọn thợ
                InkWell(
                  onTap: () => _showArtistPicker(context),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
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
                                  ? _getArtistName(currentArtist)
                                  : 'Bấm để chọn thợ thực hiện',
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
                        const Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.grey,
                        ),
                      ],
                    ),
                  ),
                ),

                // Tab 1: Không chọn thợ
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.3),
                    ),
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
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Để hệ thống tự phân công',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                                fontSize: 14,
                              ),
                            ),
                            SizedBox(height: 2),
                            Text(
                              'Giờ hiển thị theo lịch salon, thợ sẽ được phân công tự động',
                              style: TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(
                        Icons.check_circle,
                        color: AppColors.primary,
                        size: 20,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
