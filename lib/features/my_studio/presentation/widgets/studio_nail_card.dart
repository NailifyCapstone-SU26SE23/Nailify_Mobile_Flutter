import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/studio_mock_data.dart';

class StudioNailCard extends StatelessWidget {
  final StudioNailModel nail;
  final VoidCallback onTap;

  const StudioNailCard({super.key, required this.nail, required this.onTap});

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Draft': return Colors.grey.shade600;
      case 'Pending': return Colors.orange;
      case 'Approved': return Colors.green;
      case 'Rejected': return Colors.red;
      default: return Colors.black;
    }
  }

  String _getStatusText(String status) {
    switch (status) {
      case 'Draft': return 'Bản nháp';
      case 'Pending': return 'Chờ duyệt';
      case 'Approved': return 'Đã duyệt';
      case 'Rejected': return 'Từ chối';
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
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.horizontal(left: Radius.circular(16)),
              child: Image.asset(
                nail.imageUrl,
                width: 100,
                height: 100,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(width: 100, height: 100, color: Colors.pink.shade50, child: const Icon(Icons.image, color: Colors.grey)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(nail.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text('${nail.shape} • ${nail.lengthText}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _getStatusColor(nail.status).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
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
}