import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

typedef StylistSelectedCallback = void Function(Map<String, dynamic>? artist);

class BookingStylistSelection extends StatefulWidget {
  final List<dynamic> artists;
  final bool isLoading;
  final String? selectedStylistId;
  final bool noArtistSelected;
  final StylistSelectedCallback onStylistSelected;
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
  State<BookingStylistSelection> createState() => _BookingStylistSelectionState();
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
    if (artist['fullName'] != null && artist['fullName'].toString().isNotEmpty) {
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
      backgroundColor: const Color(0xFFFDFBF7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Chọn thợ làm móng',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  fontFamily: 'Georgia',
                  color: AppColors.primaryDark,
                ),
              ),
              const SizedBox(height: 16),
              if (widget.isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: CircularProgressIndicator(color: AppColors.primary),
                )
              else if (widget.artists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 40),
                  child: Text('Không có thợ nào khả dụng cho ngày này.', style: TextStyle(color: Colors.grey)),
                )
              else
                Flexible(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: widget.artists.map((artist) {
                        final bool isSelected = artist['nailArtistId'] == widget.selectedStylistId;
                        final String displayName = _getArtistName(artist);
                        return Container(
                          margin: const EdgeInsets.only(bottom: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : const Color(0xFFF3EFEA),
                              width: isSelected ? 1.5 : 1,
                            ),
                          ),
                          child: ListTile(
                            leading: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isSelected ? AppColors.primary : Colors.grey.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 20,
                                backgroundColor: Colors.grey.shade100,
                                backgroundImage: artist['avatarUrl'] != null
                                    ? NetworkImage(artist['avatarUrl'])
                                    : null,
                                child: artist['avatarUrl'] == null
                                    ? const Icon(Icons.person_outline_rounded, color: Colors.grey)
                                    : null,
                              ),
                            ),
                            title: Text(
                              displayName,
                              style: TextStyle(
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: isSelected ? AppColors.primary : AppColors.textPrimary,
                              ),
                            ),
                            trailing: isSelected
                                ? const Icon(Icons.check_circle_rounded, color: AppColors.primary)
                                : null,
                            onTap: () {
                              artist['fullName'] = displayName;
                              final safeArtist = Map<String, dynamic>.from(artist as Map);
                              widget.onStylistSelected(safeArtist);
                              Navigator.pop(context);
                            },
                          ),
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
    final matches = widget.artists.where((a) => a['nailArtistId'] == widget.selectedStylistId);
    final currentArtist = matches.isNotEmpty ? matches.first : null;

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
                fontFamily: 'Georgia',
                color: AppColors.primaryDark,
              ),
            ),
            const SizedBox(height: 12),

            // Tab selector
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: const Color(0xFFF3EFEA),
                borderRadius: BorderRadius.circular(16),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.15),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                indicatorSize: TabBarIndicatorSize.tab,
                labelColor: Colors.white,
                unselectedLabelColor: Colors.grey.shade700,
                labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
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
            const SizedBox(height: 14),

            IndexedStack(
              index: selectedIndex,
              children: [
                // Tab 0: Choose Artist
                InkWell(
                  onTap: () => _showArtistPicker(context),
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFF3EFEA), width: 1.2),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.face_retouching_natural_rounded, color: AppColors.primary, size: 22),
                            const SizedBox(width: 12),
                            Text(
                              currentArtist != null
                                  ? _getArtistName(currentArtist)
                                  : 'Bấm để chọn thợ thực hiện',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: currentArtist != null ? FontWeight.bold : FontWeight.w600,
                                color: currentArtist != null ? AppColors.textPrimary : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                        const Icon(Icons.expand_more_rounded, color: Colors.grey),
                      ],
                    ),
                  ),
                ),

                // Tab 1: System Auto Assign
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFFFFF0F5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFFFD1E1), width: 1.2),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: const BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.shuffle_rounded, color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 14),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Hệ thống tự phân công thợ',
                              style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.primaryDark, fontSize: 14),
                            ),
                            SizedBox(height: 3),
                            Text(
                              'Hiển thị tất cả giờ mở cửa của salon. Thợ rảnh sẽ được chọn ngẫu nhiên.',
                              style: TextStyle(fontSize: 11, color: Colors.black54, height: 1.3),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.check_circle_rounded, color: AppColors.primary, size: 22),
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
