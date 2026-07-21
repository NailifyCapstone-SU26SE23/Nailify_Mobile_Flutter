import 'package:flutter/material.dart';
import '../../../nails/data/models/customer_nail_models.dart';
import '../../../../core/utils/price_formatter.dart';

class CustomerComponentCard extends StatelessWidget {
  final CustomerComponentModel component;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const CustomerComponentCard({
    super.key,
    required this.component,
    required this.onEdit,
    required this.onDelete,
  });

  String _getComponentTypeName(int type) {
    switch (type) {
      case 0:
        return 'Gem';
      case 1:
        return 'Sticker';
      case 2:
        return 'Charm';
      case 3:
        return 'Art';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 60,
                height: 60,
                child: component.imageUrl.isEmpty
                    ? Container(
                  color: Colors.grey[200],
                  child: Icon(Icons.image_outlined, size: 30, color: Colors.grey[400]),
                )
                    : Image.network(
                  component.imageUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (context, error, stackTrace) =>
                      Container(color: Colors.grey[200], child: const Icon(Icons.broken_image)),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(component.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue[100], borderRadius: BorderRadius.circular(4)),
                        child: Text(_getComponentTypeName(int.tryParse(component.componentType) ?? 0), style: const TextStyle(fontSize: 11)),
                      ),
                      if (component.price > 0)
                        Text(PriceFormatter.format(component.price), style: const TextStyle(fontSize: 12, color: Colors.green)),
                      if (component.isPublic)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(color: Colors.purple[100], borderRadius: BorderRadius.circular(4)),
                          child: const Text('Công khai', style: TextStyle(fontSize: 11)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            Row(
              children: [
                IconButton(icon: const Icon(Icons.edit_outlined), onPressed: onEdit, tooltip: 'Sửa'),
                IconButton(icon: const Icon(Icons.delete_outline), onPressed: onDelete, tooltip: 'Xóa', color: Colors.red),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
