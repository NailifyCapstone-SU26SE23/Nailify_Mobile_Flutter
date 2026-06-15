// lib/features/nail_booking/presentation/widgets/booking_stylist_selection.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class BookingStylistSelection extends StatelessWidget {
  final List<dynamic> artists;
  final bool isLoading;
  final String? selectedStylistId;
  final Function(dynamic) onStylistSelected;

  const BookingStylistSelection({
    super.key,
    required this.artists,
    required this.isLoading,
    required this.selectedStylistId,
    required this.onStylistSelected,
  });

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
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 16),
              if (isLoading)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: CircularProgressIndicator(),
                )
              else if (artists.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Text(
                    'Không có kỹ thuật viên khả dụng hoặc chưa chọn ngày.',
                    style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                  ),
                )
              else
                Flexible(
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: artists.length,
                    itemBuilder: (context, index) {
                      final artist = artists[index];
                      final isSelected = selectedStylistId == artist['nailArtistId'];

                      return ListTile(
                        leading: CircleAvatar(
                          radius: 18,
                          backgroundImage: artist['avatarUrl'] != null && artist['avatarUrl'] != ""
                              ? NetworkImage(artist['avatarUrl'])
                              : null,
                          child: artist['avatarUrl'] == null || artist['avatarUrl'] == ""
                              ? const Icon(Icons.person)
                              : null,
                        ),
                        title: Text(artist['fullName'] ?? 'Kỹ thuật viên', style: const TextStyle(fontWeight: FontWeight.w600)),
                        trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                        onTap: () {
                          onStylistSelected(artist);
                          Navigator.pop(context);
                        },
                      );
                    },
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
    // Tìm kiếm thợ hiện tại dựa trên ID đã chọn
    final currentArtist = artists.firstWhere(
          (element) => element['nailArtistId'] == selectedStylistId,
      orElse: () => null,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thợ làm móng',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        InkWell(
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
                    const Icon(Icons.face_retouching_natural, color: AppColors.primary, size: 22),
                    const SizedBox(width: 12),
                    Text(
                      currentArtist != null ? currentArtist['fullName'] : 'Bấm để chọn thợ thực hiện',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: currentArtist != null ? FontWeight.bold : FontWeight.normal,
                        color: currentArtist != null ? AppColors.textPrimary : Colors.grey,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.keyboard_arrow_down, color: Colors.grey),
              ],
            ),
          ),
        ),
      ],
    );
  }
}