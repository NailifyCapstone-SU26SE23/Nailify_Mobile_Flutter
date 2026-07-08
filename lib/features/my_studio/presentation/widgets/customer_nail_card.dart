import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../nails/data/models/customer_nail_models.dart';

class CustomerNailCard extends StatelessWidget {
  final CustomerNailModel nail;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onToggleFavorite;
  final VoidCallback onTogglePublic;
  final VoidCallback onSetupTryOn;

  const CustomerNailCard({
    super.key,
    required this.nail,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleFavorite,
    required this.onTogglePublic,
    required this.onSetupTryOn,
  });

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
        onTap: () {}, // Ripple effect
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: nail.imageUrl.isEmpty
                      ? Container(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          child: const Icon(Icons.spa_outlined,
                              size: 28, color: AppColors.primary),
                        )
                      : Image.network(
                          nail.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Container(
                            color: Colors.grey.shade100,
                            child: const Icon(Icons.broken_image),
                          ),
                        ),
                ),
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
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: nail.isPublic ? AppColors.primary.withValues(alpha: 0.1) : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        nail.isPublic ? 'Công khai' : 'Riêng tư',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: nail.isPublic ? AppColors.primary : Colors.grey.shade600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 48,
                height: 48,
                child: PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert, color: AppColors.textSecondary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  onSelected: (value) {
                    if (value == 'edit') onEdit();
                    if (value == 'delete') onDelete();
                    if (value == 'toggle_public') onTogglePublic();
                    if (value == 'try_on') onSetupTryOn();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'try_on',
                      child: Row(
                        children: [
                          Icon(Icons.visibility_outlined, size: 20, color: AppColors.primary),
                          SizedBox(width: 8),
                          Text('Thiết lập Try-On', style: TextStyle(color: AppColors.primary)),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'edit',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 20),
                          SizedBox(width: 8),
                          Text('Sửa'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'toggle_public',
                      child: Row(
                        children: [
                          Icon(nail.isPublic ? Icons.public_off : Icons.public, size: 20),
                          const SizedBox(width: 8),
                          Text(nail.isPublic ? 'Chuyển riêng tư' : 'Chuyển công khai'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, size: 20, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Xóa', style: TextStyle(color: Colors.red)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
