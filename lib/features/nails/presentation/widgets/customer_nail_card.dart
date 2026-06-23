import 'package:flutter/material.dart';

import '../../../try-on/presentation/try_on_setup_screen.dart';
import '../../data/models/customer_nail_models.dart';

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
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 70,
                height: 70,
                child: nail.imageUrl.isEmpty
                    ? Container(
                  color: Colors.pink[50],
                  child: const Icon(
                    Icons.spa,
                    size: 30,
                    color: Colors.pink,
                  ),
                )
                    : Image.network(
                  nail.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.broken_image),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: 12),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          nail.name,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                    ],
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (nail.isPublic)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.purple[100],
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Công khai',
                            style: TextStyle(fontSize: 10),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  // Color preview

                ],
              ),
            ),

            // Actions
            Column(
              children: [
                IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 20),
                  onPressed: onEdit,
                  tooltip: 'Sửa',
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: onDelete,
                  tooltip: 'Xóa',
                  color: Colors.red,
                ),
                IconButton(
                  icon: Icon(
                    nail.isPublic ? Icons.public : Icons.public_off,
                    size: 20,
                  ),
                  onPressed: onTogglePublic,
                  tooltip: nail.isPublic ? 'Chuyển thành riêng tư' : 'Chuyển thành công khai',
                  color: nail.isPublic ? Colors.blue : Colors.grey,
                ),
                const SizedBox(height: 4),
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => TryOnSetupScreen(customerNail: nail),
                      ),
                    );
                  },
                  icon: const Icon(Icons.visibility, size: 16),
                  label: const Text('Set Up Try On'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}