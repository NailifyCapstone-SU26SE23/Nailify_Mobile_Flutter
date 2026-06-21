import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../data/studio_mock_data.dart';

class CustomerNailDetailPage extends StatelessWidget {
  final String id;

  const CustomerNailDetailPage({super.key, required this.id});

  void _showSalonSelection(BuildContext context) {
    // Popup mốc chọn Salon để gửi yêu cầu
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Chọn Salon yêu cầu duyệt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.storefront, color: AppColors.primary),
              title: const Text('Nailify Premium - Quận 1', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi yêu cầu duyệt thành công!')));
                context.pop();
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.storefront, color: AppColors.primary),
              title: const Text('Nailify Studio - Tân Bình', style: TextStyle(fontWeight: FontWeight.bold)),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Đã gửi yêu cầu duyệt thành công!')));
                context.pop();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final nail = StudioMockData.myCustomNails.firstWhere((n) => n.id == id);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios, size: 20), onPressed: () => context.pop()),
        title: const Text('Chi tiết thiết kế', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                nail.imageUrl,
                width: double.infinity,
                height: 250,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => Container(height: 250, color: Colors.pink.shade50),
              ),
            ),
            const SizedBox(height: 24),
            Text(nail.name, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            const SizedBox(height: 16),

            // Hiện lý do từ chối nếu có
            if (nail.status == 'Rejected' && nail.rejectReason != null)
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.red.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [Icon(Icons.error_outline, color: Colors.red), SizedBox(width: 8), Text('Lý do từ chối:', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))]),
                    const SizedBox(height: 8),
                    Text(nail.rejectReason!, style: const TextStyle(color: Colors.red)),
                  ],
                ),
              ),

            // Hiện Báo giá & Thời gian nếu Đã duyệt
            if (nail.status == 'Approved')
              Container(
                margin: const EdgeInsets.only(bottom: 20),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.green.shade200)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(children: [Icon(Icons.check_circle, color: Colors.green), SizedBox(width: 8), Text('Đã duyệt khả thi!', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold))]),
                    const Divider(color: Colors.green),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Báo giá dự kiến:', style: TextStyle(color: Colors.green)),
                        Text(PriceFormatter.format(nail.price), style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Thời gian dự kiến:', style: TextStyle(color: Colors.green)),
                        Text('${nail.duration} phút', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Thợ thực hiện:', style: TextStyle(color: Colors.green)),
                        Text(nail.stylistName ?? 'Đã được chỉ định', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 16)),
                      ],
                    ),
                  ],
                ),
              ),

            const Text('Chi tiết kỹ thuật', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), border: Border.all(color: AppColors.borderLight)),
              child: Column(
                children: [
                  _buildRow('Phom móng', nail.shape),
                  _buildRow('Độ dài', nail.lengthText),
                  _buildRow('Màu nền', nail.color),
                  _buildRow('Hoa văn', nail.pattern),
                  _buildRow('Phụ kiện', nail.accessories.isEmpty ? 'Không' : nail.accessories.join(', '), isLast: true),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: _buildFooterAction(context, nail),
    );
  }

  Widget _buildRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 100, child: Text(label, style: const TextStyle(color: Colors.grey))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary))),
        ],
      ),
    );
  }

  Widget? _buildFooterAction(BuildContext context, StudioNailModel nail) {
    if (nail.status == 'Draft') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: ElevatedButton.icon(
          onPressed: () => _showSalonSelection(context),
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          icon: const Icon(Icons.send, color: Colors.white),
          label: const Text('Gửi yêu cầu duyệt', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      );
    }
    if (nail.status == 'Approved') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))]),
        child: ElevatedButton.icon(
          onPressed: () {
            context.push('/custom-nail-booking', extra: nail);
          },
          style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
          icon: const Icon(Icons.calendar_month, color: Colors.white),
          label: const Text('Đặt lịch ngay', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
        ),
      );
    }
    return null;
  }
}