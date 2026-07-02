import 'package:flutter/material.dart';

import '../../nails/data/models/nail_shape_model.dart';
import '../models/try_on_data.dart';

class TryOnActionBar extends StatelessWidget {
  final NailShapeModel? selectedNailShape;
  final CombinedComponent? selectedComponent;
  final bool canSave;
  final bool isSaving;
  final VoidCallback onLiveTryOn;
  final VoidCallback onPhotoTryOn;
  final VoidCallback onSave;

  const TryOnActionBar({
    super.key,
    required this.selectedNailShape,
    required this.selectedComponent,
    required this.canSave,
    required this.isSaving,
    required this.onLiveTryOn,
    required this.onPhotoTryOn,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final hasShape = selectedNailShape != null;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom:
            MediaQuery.of(context).padding.bottom +
            16, // Protects safe areas on modern iPhones
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(15),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            canSave ? 'Ready to save' : 'Selection missing',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          Text(
            hasShape
                ? selectedComponent == null
                      ? selectedNailShape!.name
                      : '${selectedNailShape!.name} + ${selectedComponent!.name}'
                : 'Pick a nail shape',
            style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ElevatedButton.icon(
                  onPressed: hasShape && !isSaving ? onLiveTryOn : null,
                  icon: const Icon(Icons.view_in_ar, size: 18),
                  label: const Text('Live Try On'),
                ),
                const SizedBox(width: 8),
                ElevatedButton.icon(
                  onPressed: hasShape && !isSaving ? onPhotoTryOn : null,
                  icon: const Icon(Icons.photo_camera, size: 18),
                  label: const Text('Photo Try On'),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: canSave && !isSaving ? onSave : null,
                  icon: isSaving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
