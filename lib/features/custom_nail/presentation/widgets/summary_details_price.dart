// lib/features/custom_nail/presentation/widgets/summary_details_price.dart
import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/custom_nail_model.dart';

class SummaryDetailsPrice extends StatelessWidget {
  final CustomNailModel nailDesign;

  const SummaryDetailsPrice({super.key, required this.nailDesign});

  int _calculateTotalPrice() {
    int total = 150000; // Giá phom móng nền cơ bản (cho 2 bàn tay)
    if (nailDesign.lengthText == 'Long' ||
        nailDesign.lengthText == 'Very Long') {
      total += 40000;
    }

    if (nailDesign.isApplyAll) {
      // Tính giá đồng bộ: 1 họa tiết * 10 ngón tay, 1 phụ kiện * 10 ngón tay
      if (nailDesign.globalConfig.pattern != 'Solid Color' &&
          nailDesign.globalConfig.pattern.isNotEmpty) {
        total += 60000;
      }
      total += nailDesign.globalConfig.accessories.length * 25000 * 10;
    } else {
      // Tính giá từng ngón (Nhân 2 vì áp dụng cho 2 bàn tay)
      for (var config in nailDesign.fingerConfigs.values) {
        if (config.pattern != 'Solid Color' && config.pattern.isNotEmpty) {
          total += (6000 * 2); // 6k/ngón * 2 tay
        }
        total += config.accessories.length * 25000 * 2; // 25k/phụ kiện * 2 tay
      }
    }
    return total;
  }

  Widget _buildSummaryItem(String step, String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
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

  // Dùng để hiển thị chi tiết cho chế độ Tùy chỉnh từng ngón
  Widget _buildFingerBreakdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: nailDesign.fingerConfigs.entries.map((entry) {
        final finger = entry.key;
        final config = entry.value;
        final accessoriesTxt = config.accessories.isEmpty
            ? 'Không Phụ kiện'
            : '${config.accessories.length} Phụ kiện';

        return Padding(
          padding: const EdgeInsets.only(bottom: 8.0),
          child: Row(
            children: [
              SizedBox(
                width: 80,
                child: Text(
                  finger,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  '${config.color}, ${config.pattern}, $accessoriesTxt',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
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
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 20),

          _buildSummaryItem(
            '1',
            'Phom & Độ dài (Shape & Length)',
            '${nailDesign.selectedShape} - ${nailDesign.lengthText}',
          ),

          if (nailDesign.isApplyAll) ...[
            _buildSummaryItem(
              '2',
              'Màu nền (Color)',
              nailDesign.globalConfig.color,
            ),
            _buildSummaryItem(
              '3',
              'Hoa văn (Pattern & Design)',
              nailDesign.globalConfig.pattern,
            ),
            _buildSummaryItem(
              '4',
              'Phụ kiện đính kèm (Accessories)',
              nailDesign.globalConfig.accessories.isEmpty
                  ? 'Không có phụ kiện'
                  : nailDesign.globalConfig.accessories.join(', '),
            ),
          ] else ...[
            // Nếu chọn tùy chỉnh, hiển thị dạng danh sách chi tiết
            _buildSummaryItem('2-4', 'Cấu hình chi tiết từng ngón', ''),
            Container(
              margin: const EdgeInsets.only(left: 36, bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.borderLight),
              ),
              child: _buildFingerBreakdown(),
            ),
          ],

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Divider(height: 1, color: AppColors.borderLight),
          ),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Tổng chi phí ước tính:',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Text(
                '${_calculateTotalPrice().toString().replaceAllMapped(RegExp(r'(\d{3})(?=\d)'), (Match m) => '${m[1]}.')} Đ',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
