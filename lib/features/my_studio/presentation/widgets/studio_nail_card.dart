import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/customer_nail_model.dart';

class StudioNailCard extends StatelessWidget {
  final CustomerNailModel nail;
  final VoidCallback onTap;
  final Widget? action;

  const StudioNailCard({
    super.key,
    required this.nail,
    required this.onTap,
    this.action,
  });

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Pending':
      case 'PendingReview':
        return Colors.orange;
      case 'Review':
      case 'Assigned':
      case 'Reviewed':
      case 'Quoted':
        return Colors.amber.shade600;
      case 'Approved':
        return Colors.green;
      case 'Rejected':
        return Colors.red;
      default:
        return Colors.grey.shade600;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'Pending':
      case 'PendingReview':
        return 'Chờ duyệt';
      case 'Review':
        return 'Đang thẩm định';
      case 'Assigned':
        return 'Đã gán thợ';
      case 'Reviewed':
        return 'Thợ đã đánh giá';
      case 'Quoted':
        return 'Đã báo giá';
      case 'Approved':
        return 'Sẵn sàng đặt lịch';
      case 'Rejected':
        return 'Bị từ chối';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200, width: 1.5),
      ),
      color: Colors.white,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: nail.imageUrl != null && nail.imageUrl!.isNotEmpty
                        ? Image.network(
                            nail.imageUrl!,
                            width: 64,
                            height: 64,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _fallbackImage(),
                          )
                        : _fallbackImage(),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 2),
                        Text(
                          nail.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (nail.salonName != null && nail.salonName!.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            nail.salonName!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: _getStatusColor(nail.status).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _getStatusText(nail.status),
                            style: TextStyle(
                              color: _getStatusColor(nail.status),
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (action != null) ...[
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: action),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallbackImage() {
    return Container(
      width: 64,
      height: 64,
      color: AppColors.primary.withValues(alpha: 0.1),
      child: const Icon(Icons.spa_outlined, color: AppColors.primary, size: 28),
    );
  }
}
