import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

class NailDetailsPage extends StatelessWidget {
  final Map<String, dynamic> nailData;

  const NailDetailsPage({super.key, required this.nailData});

  void _showPopupNotification(BuildContext context, String actionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.info_outline, color: AppColors.primary),
            SizedBox(width: 8),
            Text('Thông báo'),
          ],
        ),
        content: Text('Tính năng "$actionName" cho mẫu móng này hiện đang được tích hợp hệ thống.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng', style: TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Widget xây dựng hàng thông số chi tiết (Label bên trái, Value đậm bên phải)
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 14, color: AppColors.textPrimary, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 402), // Đồng bộ kích thước khung dự án
          child: Stack(
            children: [
              // HÌNH ẢNH VÀ THÔNG TIN CHI TIẾT (CUỘN DỌC)

              SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // MẢNG 1: Hình ảnh mẫu nail lớn sắc nét
                    Image.asset(
                      nailData['image'] ?? '',
                      width: double.infinity,
                      height: MediaQuery.of(context).size.height * 0.42,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        height: MediaQuery.of(context).size.height * 0.42,
                        color: AppColors.surface,
                        child: const Icon(Icons.image, size: 64, color: AppColors.textSecondary),
                      ),
                    ),

                    // MẢNG 2: Tên và bảng 7 thông số kỹ thuật chi tiết sản phẩm
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 100), // Thừa khoảng trống đáy để không bị cụm nút che
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            nailData['name'] ?? 'Nail Design',
                            style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Premium Collection',
                            style: TextStyle(fontSize: 14, color: AppColors.primary, fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 16),
                          const Divider(height: 1, color: AppColors.border),
                          const SizedBox(height: 8),

                          // Hiển thị danh sách 7 thuộc tính kỹ thuật
                          _buildInfoRow('Shape', nailData['shape'] ?? 'Standard'),
                          _buildInfoRow('Length', nailData['length'] ?? 'Medium'),
                          _buildInfoRow('Surface', nailData['surface'] ?? 'Glossy'),
                          _buildInfoRow('Decorate', nailData['decorate'] ?? 'None'),
                          _buildInfoRow('Occasion', nailData['occasion'] ?? 'General'),
                          _buildInfoRow('Color', nailData['color'] ?? 'Multi-color'),
                          _buildInfoRow('Personality', nailData['personality'] ?? 'Trendy'),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              //back
              Positioned(
                top: MediaQuery.of(context).padding.top + 12,
                left: 16,
                child: GestureDetector(
                  onTap: () => context.pop(), // Back quay lại màn hình
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(color: AppColors.textPrimary, blurRadius: 8, offset: const Offset(0, 2)),
                      ],
                    ),
                    child: const Icon(Icons.arrow_back_ios_new, size: 18, color: AppColors.textPrimary),
                  ),
                ),
              ),


              //CỤM NÚT HÀNH ĐỘNG (BOOK NOW & VIRTUAL TRY ON)

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    boxShadow: [
                      BoxShadow(color: AppColors.textPrimary, blurRadius: 10, offset: const Offset(0, -4)),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Nút Thử móng ảo (Virtual Try On) - Dạng Outline cao cấp
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: OutlinedButton.icon(
                            onPressed: () => _showPopupNotification(context, 'Virtual Try On'),
                            icon: const Icon(Icons.camera_alt_outlined, color: AppColors.primary, size: 20),
                            label: const Text('Virtual Try On', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold, fontSize: 14)),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppColors.primary, width: 1.5),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),

                      // Nút Đặt lịch (Book Now) - Hồng chủ đạo rực rỡ thu hút hành động
                      Expanded(
                        child: SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            onPressed: () {
                              context.push('/nail-booking', extra: nailData);
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Book Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}