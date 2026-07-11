import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class SummaryNotes extends StatelessWidget {
  final TextEditingController controller;

  const SummaryNotes({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Ghi chú thêm',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          maxLines: 3,
          maxLength: 200,
          decoration: InputDecoration(
            hintText:
                'Nhập yêu cầu đặc biệt cho thợ nail (ví dụ: form móng mỏng, đổi charm xà cừ...)',
            hintStyle: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 13,
            ),
            fillColor: Colors.grey.shade50,
            filled: true,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.borderLight),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                color: AppColors.primary,
                width: 1.5,
              ),
            ),
            counterText: '', // Ẩn bộ đếm số mặc định của hệ thống
          ),
        ),
      ],
    );
  }
}
