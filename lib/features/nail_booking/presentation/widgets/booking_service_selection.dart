import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/booking_mock_data.dart';

class BookingServiceSelection extends StatelessWidget {
  final Map<String, dynamic>? nailData;
  final List<String?> selectedExtraServices;
  final Function(List<String?>) onChanged;

  const BookingServiceSelection({
    super.key,
    required this.nailData,
    required this.selectedExtraServices,
    required this.onChanged,
  });

  void _addService() {
    final newList = List<String?>.from(selectedExtraServices);
    newList.add(null);
    onChanged(newList);
  }

  void _removeService(int index) {
    final newList = List<String?>.from(selectedExtraServices);
    newList.removeAt(index);
    onChanged(newList);
  }

  void _updateService(int index, String? value) {
    final newList = List<String?>.from(selectedExtraServices);
    newList[index] = value;
    onChanged(newList);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Dịch vụ *', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        const SizedBox(height: 16),

        // 1. DỊCH VỤ CHÍNH (GẮN CỨNG NẾU CÓ MẪU NAIL)
        if (nailData != null)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                const Icon(Icons.diamond_outlined, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Dịch vụ thiết kế Nail (Mặc định)', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                      const SizedBox(height: 4),
                      Text(nailData!['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.primary)),
                    ],
                  ),
                ),
                const Icon(Icons.lock_outline, size: 16, color: Colors.grey), // không cho xóa
              ],
            ),
          ),

        // 2. chọn thêm dịch vụ
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: selectedExtraServices.length,
          itemBuilder: (context, index) {
            final service = selectedExtraServices[index];

            return Padding(
              padding: const EdgeInsets.only(bottom: 12.0),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 48,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey.shade300),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: service,
                          hint: const Text('Chọn dịch vụ phụ trợ', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          isExpanded: true,
                          icon: const Icon(Icons.keyboard_arrow_down, size: 20, color: Colors.grey),
                          items: BookingMockData.extraServices.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 14)))).toList(),
                          onChanged: (val) => _updateService(index, val),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.cancel_outlined, color: Colors.grey),
                    onPressed: () => _removeService(index),
                  )
                ],
              ),
            );
          },
        ),

        // 3. NÚT THÊM DỊCH VỤ
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _addService,
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Thêm dịch vụ', style: TextStyle(fontWeight: FontWeight.bold)),
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.primary,
            side: const BorderSide(color: AppColors.primary),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
        ),
      ],
    );
  }
}