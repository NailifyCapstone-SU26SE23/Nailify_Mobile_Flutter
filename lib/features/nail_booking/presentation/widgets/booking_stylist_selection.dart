// lib/features/booking/presentation/widgets/booking_stylist_selection.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/booking_mock_data.dart';

class BookingStylistSelection extends StatelessWidget {
  final String? selectedStylistId;
  final Function(Map<String, String>) onStylistSelected;

  const BookingStylistSelection({
    super.key,
    required this.selectedStylistId,
    required this.onStylistSelected,
  });

  @override
  Widget build(BuildContext context) {
    final stylists = BookingMockData.stylists;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn thợ làm móng',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        const SizedBox(height: 12),

        // Lưới danh sách Thợ (2 cột) tối giản, tinh tế
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.4,
          ),
          itemCount: stylists.length,
          itemBuilder: (context, index) {
            final stylist = stylists[index];
            final bool isSelected = selectedStylistId == stylist['id'];

            return GestureDetector(
              onTap: () => onStylistSelected(stylist),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isSelected ? AppColors.primary.withOpacity(0.04) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppColors.primary : AppColors.borderLight,
                    width: isSelected ? 2 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Avatar giả lập chữ cái đầu
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: isSelected ? AppColors.primary : Colors.grey.shade200,
                      child: Text(
                        stylist['name']![0],
                        style: TextStyle(
                            color: isSelected ? Colors.white : AppColors.textPrimary,
                            fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    // Thông tin thợ
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        // maincenter: MainAxisAlignment.center,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            stylist['name']!,
                            style: TextStyle(
                                fontSize: 14,
                                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                                color: AppColors.textPrimary
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            stylist['role']!,
                            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.star, color: Colors.amber, size: 12),
                              const SizedBox(width: 2),
                              Text(
                                  stylist['rating']!,
                                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold)
                              ),
                              const SizedBox(width: 4),
                              Text(
                                  '(${stylist['experience']})',
                                  style: const TextStyle(fontSize: 10, color: Colors.grey)
                              ),
                            ],
                          )
                        ],
                      ),
                    )
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}