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

  // UTILS
  // lấy tên thợ thông minh kệ mịa API trả về firstName hay fullName hay cái éo gì
  String _getArtistName(dynamic artist) {
    if (artist == null) return 'Thợ';

    // 1. Nếu API trả fullName
    if (artist['fullName'] != null && artist['fullName'].toString().isNotEmpty) {
      return artist['fullName'];
    }

    // 2. Nếu API trả firstName và lastName -> tự nối lại
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
                  child: Text('Không có thợ nào khả dụng cho ngày này.'),
                )
              else
                ...artists.map((artist) {
                  final bool isSelected = artist['nailArtistId'] == selectedStylistId;
                  final String displayName = _getArtistName(artist);

                  return ListTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.grey.shade200,
                      backgroundImage: artist['avatarUrl'] != null ? NetworkImage(artist['avatarUrl']) : null,
                      child: artist['avatarUrl'] == null ? const Icon(Icons.person, color: Colors.grey) : null,
                    ),
                    title: Text(displayName, style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                    trailing: isSelected ? const Icon(Icons.check_circle, color: AppColors.primary) : null,
                    onTap: () {
                      // Đánh dấu: Lưu lại tên vào mảng nội bộ
                      artist['fullName'] = displayName;

                      // FIX: Ép kiểu an toàn (Safe Cast) thành Map<String, dynamic> trước khi gửi ra ngoài
                      final safeArtist = Map<String, dynamic>.from(artist as Map);

                      onStylistSelected(safeArtist);
                      Navigator.pop(context);
                    },
                  );
                }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final matches = artists.where((a) => a['nailArtistId'] == selectedStylistId);
    final currentArtist = matches.isNotEmpty ? matches.first : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Thợ thực hiện',
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
                      currentArtist != null ? _getArtistName(currentArtist) : 'Bấm để chọn thợ thực hiện',
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