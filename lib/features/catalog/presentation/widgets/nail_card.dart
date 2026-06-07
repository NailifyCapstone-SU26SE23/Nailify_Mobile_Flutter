import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

class NailCard extends StatelessWidget {
  // Thay đổi: Nhận toàn bộ Map data của mẫu nail để truyền đi dễ dàng
  final Map<String, dynamic> nailData;

  const NailCard({super.key, required this.nailData});

  @override
  Widget build(BuildContext context) {
    final String name = nailData['name'] ?? 'Unknown';
    final String imagePath = nailData['image'] ?? '';
    final List<String> tags = List<String>.from(nailData['tags'] ?? []);

    return GestureDetector(
      // Bấm vào thẻ móng sẽ nhảy sang trang chi tiết, đính kèm dữ liệu móng qua thuộc tính extra
      onTap: () => context.push('/catalog/details', extra: nailData),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.textPrimary.withOpacity(0.1)),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
                child: Image.asset(
                  imagePath,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) => Container(
                    color: AppColors.primary.withOpacity(0.05),
                    child: const Icon(Icons.image, color: AppColors.textSecondary),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 4,
                    runSpacing: 4,
                    children: tags.take(2).map((tag) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.textPrimary.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(tag, style: const TextStyle(fontSize: 10, color: AppColors.textSecondary)),
                    )).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}