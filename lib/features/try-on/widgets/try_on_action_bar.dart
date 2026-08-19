import 'package:flutter/material.dart';

class TryOnActionBar extends StatelessWidget {
  final bool canSave;
  final bool isSaving;
  final bool isLaunching;
  final VoidCallback onSave;
  final VoidCallback onLiveTryOn;
  final VoidCallback onPhotoTryOn;
  final VoidCallback? onRegenerate;

  const TryOnActionBar({
    super.key,
    required this.canSave,
    required this.isSaving,
    required this.isLaunching,
    required this.onSave,
    required this.onLiveTryOn,
    required this.onPhotoTryOn,
    this.onRegenerate,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = canSave && !isSaving && !isLaunching;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom > 0
            ? MediaQuery.of(context).padding.bottom
            : 16,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled ? onLiveTryOn : null,
                    icon: const Icon(Icons.videocam_outlined),
                    label: const Text('Live'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: enabled ? onPhotoTryOn : null,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Photo'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (onRegenerate != null)
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: !isSaving && !isLaunching
                          ? onRegenerate
                          : null,
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text(
                        'Tạo lại',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        foregroundColor: Colors.pink,
                        side: const BorderSide(color: Colors.pink, width: 1.5),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: enabled ? onSave : null,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        backgroundColor: Colors.pink,
                      ),
                      child: isSaving
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.5,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Lưu thiết kế',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                    ),
                  ),
                ],
              )
            else
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: enabled ? onSave : null,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    backgroundColor: Colors.pink,
                  ),
                  child: isSaving
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Lưu mẫu thiết kế',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}