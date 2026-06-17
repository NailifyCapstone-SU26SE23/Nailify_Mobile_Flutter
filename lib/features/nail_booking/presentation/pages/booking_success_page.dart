import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';

class BookingSuccessPage extends StatelessWidget {
  final Map<String, dynamic> bookingDetails;

  const BookingSuccessPage({super.key, required this.bookingDetails});

  @override
  Widget build(BuildContext context) {
    final date = bookingDetails['date'] as DateTime?;
    final dateString = date != null ? '${date.day}/${date.month}/${date.year}' : '';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 100),
              const SizedBox(height: 24),
              const Text(
                'Đặt lịch thành công!',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
              ),
              const SizedBox(height: 8),
              const Text(
                'Cảm ơn bạn đã tin tưởng Nailify. Dưới đây là thông tin chi tiết lịch hẹn của bạn.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 14, height: 1.5),
              ),
              const SizedBox(height: 32),

              // Bảng tóm tắt thông tin
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.borderLight),
                  boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4))],
                ),
                child: Column(
                  children: [
                    _buildInfoRow(Icons.spa, 'Dịch vụ', bookingDetails['serviceName'] ?? ''),
                    const Divider(height: 24, color: AppColors.borderLight),
                    _buildInfoRow(Icons.calendar_month, 'Ngày hẹn', dateString),
                    const Divider(height: 24, color: AppColors.borderLight),
                    _buildInfoRow(Icons.access_time, 'Thời gian', bookingDetails['time']?.substring(0, 5) ?? ''),
                    const Divider(height: 24, color: AppColors.borderLight),
                    _buildInfoRow(Icons.face_2, 'Nhân viên', bookingDetails['stylistName'] ?? ''),
                  ],
                ),
              ),
              const SizedBox(height: 40),

              // Nút Xem Booking (Popup tạm thời)
              ElevatedButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Row(children: [Icon(Icons.construction, color: Colors.amber), SizedBox(width:8), Text('Đang phát triển')]),
                      content: const Text('Trang chi tiết quản lý Booking của khách hàng đang được xây dựng.'),
                      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Đóng'))],
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('View Booking', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
              const SizedBox(height: 16),

              // Nút Về Trang Chủ
              OutlinedButton(
                onPressed: () => context.go('/'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  minimumSize: const Size(double.infinity, 50),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text('Back to Home', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String title, String value) {
    return Row(
      children: [
        Icon(icon, color: AppColors.primary, size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(value, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ],
    );
  }
}