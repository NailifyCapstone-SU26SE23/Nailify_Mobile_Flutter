import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/customer_nail_model.dart';

class StudioNailCard extends StatelessWidget {
  final CustomerNailModel nail;
  final VoidCallback onTap;

  const StudioNailCard({super.key, required this.nail, required this.onTap});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending': return Colors.orange;
      case 'PendingReview': return Colors.orange;
      case 'Review':
      case 'Assigned':
      case 'Reviewed':
      case 'Quoted':
        return Colors.amber.shade600;
      case 'Approved': return Colors.green;
      case 'Rejected': return Colors.red;
      default: return Colors.grey.shade600;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'Pending': return 'Chờ duyệt';
      case 'PendingReview': return 'Chờ duyệt';
      case 'Review': return 'Đang thẩm định';
      case 'Assigned': return 'Đã gán thợ';
      case 'Reviewed': return 'Thợ đã đánh giá';
      case 'Quoted': return 'Đã báo giá';
      case 'Approved': return 'Sẵn sàng đặt lịch';
      case 'Rejected': return 'Bị từ chối';
      default: return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: nail.imageUrl != null && nail.imageUrl!.isNotEmpty
                  ? Image.network(
                  nail.imageUrl!,
                  width: 100,
                  height: 100,
                  fit: BoxFit.cover,
                  errorBuilder: (_,__,___) => _fallbackImage()
              )
                  : _fallbackImage(),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(nail.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    // Hiển thị tên salon nếu có
                    if (nail.salonName != null && nail.salonName!.isNotEmpty)
                      Text(nail.salonName!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(color: _getStatusColor(nail.status).withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        _getStatusText(nail.status),
                        style: TextStyle(color: _getStatusColor(nail.status), fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fallbackImage() => Container(width: 100, height: 100, color: Colors.pink.shade50, child: const Icon(Icons.image, color: Colors.grey));
}