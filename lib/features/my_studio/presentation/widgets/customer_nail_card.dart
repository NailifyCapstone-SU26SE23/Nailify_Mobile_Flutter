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
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFF0F5), width: 1.5),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryDark.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () {}, // Ripple effect
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: nail.imageUrl.isEmpty
                      ? Container(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          child: const Icon(
                            Icons.spa_rounded,
                            size: 32,
                            color: AppColors.primary,
                          ),
                        )
                      : Image.network(
                          nail.imageUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (_, _, _) => Container(
                            color: const Color(0xFFF5F5F7),
                            child: const Icon(Icons.broken_image_rounded, color: Colors.grey),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(
                      nail.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: nail.isPublic
                                ? const Color(0xFFE8F5E9)
                                : const Color(0xFFECEFF1),
                            borderRadius: BorderRadius.circular(30),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                nail.isPublic ? Icons.public_rounded : Icons.lock_outline_rounded,
                                size: 12,
                                color: nail.isPublic
                                    ? const Color(0xFF2E7D32)
                                    : const Color(0xFF546E7A),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                nail.isPublic ? 'Công khai' : 'Riêng tư',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: nail.isPublic
                                      ? const Color(0xFF2E7D32)
                                      : const Color(0xFF546E7A),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topRight,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F5F7),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: PopupMenuButton<String>(
                    icon: const Icon(
                      Icons.more_horiz_rounded,
                      color: AppColors.textSecondary,
                      size: 20,
                    ),
                    padding: EdgeInsets.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
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
                            Icon(
                              Icons.visibility_rounded,
                              size: 18,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Thiết lập Try-On',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'edit',
                        child: Row(
                          children: [
                            Icon(Icons.edit_rounded, size: 18, color: AppColors.textSecondary),
                            SizedBox(width: 8),
                            Text('Sửa'),
                          ],
                        ),
                      ),
                      PopupMenuItem(
                        value: 'toggle_public',
                        child: Row(
                          children: [
                            Icon(
                              nail.isPublic ? Icons.public_off_rounded : Icons.public_rounded,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              nail.isPublic
                                  ? 'Chuyển riêng tư'
                                  : 'Chuyển công khai',
                            ),
                          ],
                        ),
                      ),
                      const PopupMenuItem(
                        value: 'delete',
                        child: Row(
                          children: [
                            Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                              color: Colors.red,
                            ),
                            SizedBox(width: 8),
                            Text('Xóa', style: TextStyle(color: Colors.red, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
