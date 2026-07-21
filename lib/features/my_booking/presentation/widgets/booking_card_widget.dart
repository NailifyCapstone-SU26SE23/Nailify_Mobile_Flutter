import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../utils/booking_status_utils.dart';

class BookingCardWidget extends StatelessWidget {
  final Map<String, dynamic> booking;
  final Map<String, dynamic> rating;
  final VoidCallback onTap;
  final VoidCallback onRatePressed;

  const BookingCardWidget({
    super.key,
    required this.booking,
    required this.rating,
    required this.onTap,
    required this.onRatePressed,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = booking['bookingDate']?.toString() ?? '';
    final bookingDate = DateTime.tryParse(dateStr) ?? DateTime.now();

    final status = bookingStatusView(booking['status']?.toString());
    final rawStatus = booking['status']?.toString();
    final items = booking['bookingItems'] as List<dynamic>? ?? [];
    
    var nailName = 'Dịch vụ làm móng';
    if (items.isNotEmpty && items.first is Map) {
      final firstItem = items.first as Map;
      final variantName = firstItem['nailVariantName']?.toString().trim() ?? '';
      final customNailName = firstItem['customerNailName']?.toString().trim() ?? '';
      final serviceName = firstItem['serviceName']?.toString().trim() ?? '';

      if (variantName.isNotEmpty) {
        nailName = variantName;
      } else if (customNailName.isNotEmpty) {
        nailName = customNailName;
      } else if (serviceName.isNotEmpty) {
        nailName = serviceName;
      }
    }

    String timeStr = booking['startTime']?.toString() ?? '';
    if (timeStr.length >= 5) {
      timeStr = timeStr.substring(0, 5);
    }

    final artistName = booking['artistName']?.toString() ?? 'Bất kỳ';
    
    // Rating flags
    final bool isCompleted = rawStatus == 'Completed';
    final bool isRated = rating.isNotEmpty;
    final int overallScore = rating['overallScore'] ?? 0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFFF3EFEA), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status and Date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: status.backgroundColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    status.label,
                    style: TextStyle(
                      color: status.textColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Text(
                  '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Colors.grey.shade500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Divider(height: 1, color: Color(0xFFF3EFEA)),
            ),
            
            // Design name
            Text(
              nailName,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 10),
            
            // Meta: Time and Artist
            Row(
              children: [
                Icon(Icons.access_time_rounded, size: 15, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  timeStr,
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 20),
                Icon(Icons.face_2_rounded, size: 15, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    artistName,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13, fontWeight: FontWeight.w500),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            // Conditional Rating Button
            if (isCompleted) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 44,
                child: isRated
                    ? OutlinedButton.icon(
                        onPressed: onRatePressed,
                        icon: const Icon(Icons.star_rounded, size: 18, color: AppColors.primary),
                        label: Text(
                          'Đã đánh giá ⭐$overallScore',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary, width: 1.2),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          backgroundColor: const Color(0xFFFFF0F5),
                        ),
                      )
                    : ElevatedButton.icon(
                        onPressed: onRatePressed,
                        icon: const Icon(Icons.star_border_rounded, size: 18, color: Colors.white),
                        label: const Text(
                          'Đánh giá dịch vụ',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
