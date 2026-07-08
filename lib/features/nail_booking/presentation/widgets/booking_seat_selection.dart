import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class BookingSeatSelection extends StatelessWidget {
  final String? selectedSeatId;
  final ValueChanged<String?> onSeatSelected;

  const BookingSeatSelection({
    super.key,
    required this.selectedSeatId,
    required this.onSeatSelected,
  });

  @override
  Widget build(BuildContext context) {
    // 4x4 Grid mock data cho ghế (Dòng 1 là VIP, các dòng khác là Thường)
    final List<Map<String, dynamic>> mockSeats = List.generate(16, (index) {
      final seatNumber = index + 1;
      final isOccupied = index % 5 == 0; // Giả lập ghế đã có người đặt
      final isVip = seatNumber <= 4; // Ghế từ S1 đến S4 là ghế VIP
      return {
        'id': 'seat_$seatNumber',
        'label': 'S$seatNumber',
        'isOccupied': isOccupied,
        'isVip': isVip,
      };
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Chọn ghế tại chi nhánh',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Vui lòng chọn vị trí ghế ngồi mà bạn mong muốn.',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 24),

        // QUẦY LỄ TÂN
        Container(
          width: double.infinity,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade300, width: 1.5),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.02),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.desk_outlined, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 8),
              Text(
                'QUẦY LỄ TÂN',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),

        // Grid 4x4 Ghế ngồi
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 4,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
            childAspectRatio: 1.0,
          ),
          itemCount: mockSeats.length,
          itemBuilder: (context, index) {
            final seat = mockSeats[index];
            final bool isOccupied = seat['isOccupied'];
            final bool isVip = seat['isVip'];
            final bool isSelected = selectedSeatId == seat['id'];

            // Xác định màu sắc dựa trên trạng thái
            Color seatColor = Colors.white;
            Color borderColor = AppColors.borderLight;
            Color iconColor = Colors.grey.shade600;
            Color textColor = Colors.grey.shade700;

            if (isOccupied) {
              seatColor = Colors.grey.shade200;
              borderColor = Colors.grey.shade300;
              iconColor = Colors.grey.shade400;
              textColor = Colors.grey.shade400;
            } else if (isSelected) {
              seatColor = AppColors.primary;
              borderColor = AppColors.primary;
              iconColor = Colors.white;
              textColor = Colors.white;
            } else if (isVip) {
              seatColor = Colors.amber.shade50;
              borderColor = Colors.amber.shade600;
              iconColor = Colors.amber.shade800;
              textColor = Colors.amber.shade800;
            }

            return GestureDetector(
              onTap: () {
                if (!isOccupied) {
                  onSeatSelected(isSelected ? null : seat['id']);
                }
              },
              child: Container(
                decoration: BoxDecoration(
                  color: seatColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: borderColor,
                    width: isVip && !isOccupied && !isSelected ? 2 : 1.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ]
                      : null,
                ),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Nhãn VIP nhỏ ở góc trên phải nếu là ghế VIP chưa chọn/chưa đặt
                    if (isVip && !isOccupied && !isSelected)
                      Positioned(
                        top: 4,
                        right: 6,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 4,
                            vertical: 1,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.shade700,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'VIP',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 8,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),

                    Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isVip && !isOccupied && !isSelected
                              ? Icons.chair_alt
                              : Icons.chair,
                          color: iconColor,
                          size: 26,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          seat['label'],
                          style: TextStyle(
                            color: textColor,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 32),

        // CHÚ THÍCH (ĐÃ CHUYỂN XUỐNG DƯỚI)
        Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderLight),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildLegendItem(
                Colors.white,
                AppColors.borderLight,
                Icons.chair,
                Colors.grey.shade600,
                'Thường',
              ),
              _buildLegendItem(
                Colors.amber.shade50,
                Colors.amber.shade600,
                Icons.chair_alt,
                Colors.amber.shade800,
                'VIP',
              ),
              _buildLegendItem(
                AppColors.primary,
                AppColors.primary,
                Icons.chair,
                Colors.white,
                'Đang chọn',
              ),
              _buildLegendItem(
                Colors.grey.shade200,
                Colors.grey.shade300,
                Icons.chair,
                Colors.grey.shade400,
                'Đã đặt',
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildLegendItem(
    Color color,
    Color borderColor,
    IconData icon,
    Color iconColor,
    String label,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: color,
            border: Border.all(color: borderColor, width: 1.5),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(child: Icon(icon, color: iconColor, size: 14)),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey.shade700,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
