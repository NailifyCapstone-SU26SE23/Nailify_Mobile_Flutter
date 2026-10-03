import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class ScoreCard extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int>? onChanged;
  final bool enabled;

  const ScoreCard({
    super.key,
    required this.label,
    required this.value,
    this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF3EFEA), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.01),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          Row(
            children: List.generate(5, (index) {
              final score = index + 1;
              final isSelected = score <= value;
              return GestureDetector(
                onTap: enabled && onChanged != null
                    ? () => onChanged!(score)
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    isSelected
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: isSelected
                        ? const Color(0xFFFFB300)
                        : Colors.grey.shade300,
                    size: 28,
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class RatingCommentInput extends StatelessWidget {
  final TextEditingController controller;
  final bool enabled;

  const RatingCommentInput({
    super.key,
    required this.controller,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      minLines: 4,
      maxLines: 6,
      enabled: enabled,
      style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
      decoration: InputDecoration(
        labelText: 'Nhận xét của bạn',
        labelStyle: TextStyle(color: Colors.grey.shade600, fontSize: 14),
        hintText: 'Hãy chia sẻ trải nghiệm dịch vụ của bạn...',
        hintStyle: TextStyle(color: Colors.grey.shade400, fontSize: 13),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.all(16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF3EFEA)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: Color(0xFFF3EFEA)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
      ),
    );
  }
}

class RatingImagePicker extends StatelessWidget {
  final String? existingImageUrl;
  final File? localImage;
  final VoidCallback onPickImage;
  final VoidCallback onRemoveImage;
  final bool enabled;

  const RatingImagePicker({
    super.key,
    this.existingImageUrl,
    this.localImage,
    required this.onPickImage,
    required this.onRemoveImage,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (localImage == null &&
            (existingImageUrl == null || existingImageUrl!.isEmpty))
          OutlinedButton.icon(
            onPressed: enabled ? onPickImage : null,
            icon: const Icon(Icons.add_photo_alternate_outlined, size: 20),
            label: const Text(
              'Thêm hình ảnh thực tế',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              disabledForegroundColor: Colors.grey,
              side: BorderSide(
                color: enabled ? AppColors.primary : Colors.grey.shade300,
                width: 1.2,
              ),
              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          )
        else ...[
          Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: localImage != null
                    ? Image.file(
                        localImage!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                      )
                    : Image.network(
                        existingImageUrl!,
                        width: double.infinity,
                        height: 200,
                        fit: BoxFit.cover,
                        errorBuilder: (_, _, _) => Container(
                          height: 120,
                          color: Colors.grey.shade100,
                          alignment: Alignment.center,
                          child: const Icon(
                            Icons.broken_image_outlined,
                            color: Colors.grey,
                          ),
                        ),
                      ),
              ),
              if (enabled)
                Positioned(
                  top: 8,
                  right: 8,
                  child: GestureDetector(
                    onTap: onRemoveImage,
                    child: Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Colors.black54,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}
