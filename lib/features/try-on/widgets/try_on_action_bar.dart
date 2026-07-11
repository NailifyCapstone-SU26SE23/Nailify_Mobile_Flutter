import 'package:flutter/material.dart';

class TryOnActionBar extends StatelessWidget {
  final bool canSave;
  final bool isSaving;
  final VoidCallback onSave;

  const TryOnActionBar({
    super.key,
    required this.canSave,
    required this.isSaving,
    required this.isLaunching,
    required this.onSave,
    required this.onLiveTryOn,
    required this.onPhotoTryOn,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = canSave && !isSaving && !isLaunching;

    return Container(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom > 0 ? MediaQuery.of(context).padding.bottom : 16,
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
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: canSave && !isSaving ? onSave : null,
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              backgroundColor: Colors.pink,
            ),
            child: isSaving
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                  )
                : const Text(
                    'Lưu mẫu thiết kế',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
          ),
        ),
      ),
    );
  }
}
