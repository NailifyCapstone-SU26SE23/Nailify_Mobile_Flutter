// lib/features/custom_nail/presentation/widgets/summary_details_price.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/custom_nail_model.dart';

class SummaryDetailsPrice extends StatelessWidget {
  final CustomNailModel nailDesign;

  const SummaryDetailsPrice({super.key, required this.nailDesign});

  // Hàm tính toán giá giả lập dựa trên lựa chọn cấu hình móng
  int _calculateTotalPrice() {
    int total = 150000; // Giá phom móng nền cơ bản
    if (nailDesign.lengthText == 'Long' || nailDesign.lengthText == 'Very Long') {
      total += 40000; // Phụ thu móng dài
    }
    if (nailDesign.selectedPattern != 'Solid Color' && nailDesign.selectedPattern.isNotEmpty) {
      total += 60000; // Phụ thu vẽ họa tiết phức tạp
    }
    total += nailDesign.accessories.length * 25000; // Phụ thu mỗi hạt charm/phụ kiện
    return total;
  }

  // Widget hiển thị từng mục đã chọn kèm theo đánh số thứ tự bước
  Widget _buildSummaryItem(String step, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0), // Khoảng cách giữa các bước
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Vòng tròn đánh số bước
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: const TextStyle(
                color: AppColors.primary,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Khối nội dung thông tin (Tiêu đề + Lựa chọn của khách)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? 'Không chọn' : value,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Xử lý chuỗi text cho phụ kiện (nếu chọn nhiều thì cách nhau bằng dấu phẩy)
    final String accessoryListText = nailDesign.accessories.isEmpty
        ? 'Không có phụ kiện'
        : nailDesign.accessories.join(', ');

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Chi tiết thiết kế của bạn',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
          ),
          const SizedBox(height: 20),

          // LIỆT KÊ NHỮNG GÌ KHÁCH HÀNG ĐÃ CHỌN TỪ PAGE 1 ĐẾN PAGE 4
          _buildSummaryItem('1', 'Phom & Độ dài (Shape & Length)', '${nailDesign.selectedShape} - ${nailDesign.lengthText}'),
          _buildSummaryItem('2', 'Màu nền (Color)', nailDesign.selectedColor),
          _buildSummaryItem('3', 'Hoa văn (Pattern & Design)', nailDesign.selectedPattern),
          _buildSummaryItem('4', 'Phụ kiện đính kèm (Accessories)', accessoryListText),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(height: 1, color: AppColors.borderLight),
          ),

          // TỔNG TIỀN ƯỚC TÍNH
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Tổng chi phí ước tính:',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
              ),
              Text(
                '${_calculateTotalPrice().toString().replaceAllMapped(RegExp(r'(\d{3})(?=\d)'), (Match m) => '${m[1]}.')} Đ',
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: AppColors.primary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}