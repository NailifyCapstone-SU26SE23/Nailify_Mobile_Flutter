import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/booking_mock_data.dart';

class BookingStylistSelection extends StatelessWidget {
  final String? selectedStylistId;
  final Function(Map<String, dynamic>) onStylistSelected;

  const BookingStylistSelection({
    super.key,
    required this.selectedStylistId,
    required this.onStylistSelected,
  });

  // Mở popup toàn màn hình (80%)
  void _showStylistList(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(width: 40),
                    const Text('Select Staff Member', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  itemCount: BookingMockData.stylists.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 70),
                  itemBuilder: (context, index) {
                    final stylist = BookingMockData.stylists[index];
                    final isSelected = selectedStylistId == stylist['id'];
                    final isAnyone = stylist['id'] == 'anyone';

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                      leading: isAnyone
                          ? CircleAvatar(
                        backgroundColor: Colors.grey.shade100,
                        radius: 24,
                        child: const Icon(Icons.people_alt_outlined, color: Colors.black54),
                      )
                          : CircleAvatar(
                        backgroundColor: AppColors.primary,
                        radius: 24,
                        child: Text(stylist['name'][0], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                      title: Text(
                        stylist['name'],
                        style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 16, color: AppColors.textPrimary),
                      ),
                      subtitle: isAnyone
                          ? const Text('Không ưu tiên thợ', style: TextStyle(fontSize: 13))
                          : Row(
                          children: [
                            const Icon(Icons.star, color: Colors.amber, size: 12),
                            const SizedBox(width: 4),
                            Text('${stylist['rating']} - ${stylist['role']}', style: const TextStyle(fontSize: 12)),
                          ]
                      ),
                      trailing: isSelected ? const Icon(Icons.check, color: AppColors.primary) : null,
                      onTap: () {
                        onStylistSelected(stylist);
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
    // Trích xuất data thợ đang chọn, mặc định Anyone
    final selectedStylist = BookingMockData.stylists.firstWhere(
          (s) => s['id'] == selectedStylistId,
      orElse: () => BookingMockData.stylists[0],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn thợ làm móng',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.borderLight)
          ),
          child: Row(
            children: [
              const Text('Staff:', style: TextStyle(color: AppColors.textSecondary, fontSize: 14)),
              const SizedBox(width: 12),

              if (selectedStylist['id'] != 'anyone')
                CircleAvatar(
                  radius: 14,
                  backgroundColor: AppColors.primary,
                  child: Text(selectedStylist['name'][0], style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              if (selectedStylist['id'] != 'anyone') const SizedBox(width: 12),

              Expanded(
                child: Text(
                  selectedStylist['name'],
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary),
                ),
              ),

              ElevatedButton(
                onPressed: () => _showStylistList(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.textPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  minimumSize: Size.zero,
                ),
                child: const Text('Change', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}