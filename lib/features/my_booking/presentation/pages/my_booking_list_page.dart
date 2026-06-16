import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/datasources/my_booking_api_service.dart';

class MyBookingListPage extends StatefulWidget {
  const MyBookingListPage({super.key});

  @override
  State<MyBookingListPage> createState() => _MyBookingListPageState();
}

class _MyBookingListPageState extends State<MyBookingListPage> {
  final MyBookingApiService _apiService = MyBookingApiService();
  List<dynamic> _bookings = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBookings();
  }

  Future<void> _fetchBookings() async {
    try {
      final data = await _apiService.getMyBookings();
      // Sắp xếp lịch hẹn mới nhất lên đầu
      data.sort((a, b) => DateTime.parse(b['bookingDate']).compareTo(DateTime.parse(a['bookingDate'])));
      if (mounted) setState(() { _bookings = data; _isLoading = false; });
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Lỗi tải lịch hẹn: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Lịch hẹn của tôi', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _bookings.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          final booking = _bookings[index];
          return _buildBookingCard(booking);
        },
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.calendar_today_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text('Bạn chưa có lịch hẹn nào', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
          const SizedBox(height: 8),
          const Text('Hãy đặt ngay một lịch làm móng để trải nghiệm!', style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.go('/'),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
            child: const Text('Khám phá dịch vụ'),
          )
        ],
      ),
    );
  }

  Widget _buildBookingCard(Map<String, dynamic> booking) {
    final bookingDate = DateTime.parse(booking['bookingDate']);
    final isUpcoming = bookingDate.isAfter(DateTime.now());

    final items = booking['bookingItems'] as List<dynamic>? ?? [];
    String nailName = 'Dịch vụ làm móng';
    if (items.isNotEmpty) {
      nailName = items[0]['nailVariantName'] ?? items[0]['customerNailName'] ?? items[0]['serviceName'] ?? 'Dịch vụ làm móng';
    }

    return GestureDetector(
      // === THAY ĐỔI TẠI ĐÂY: CHỈ TRUYỀN ID ===
      onTap: () => context.push('/my-bookings/detail', extra: booking['bookingId']),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.borderLight),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: isUpcoming ? Colors.orange.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    isUpcoming ? 'Sắp tới' : 'Đã hoàn thành',
                    style: TextStyle(color: isUpcoming ? Colors.orange.shade800 : Colors.green.shade800, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
                Text(
                  '${bookingDate.day}/${bookingDate.month}/${bookingDate.year}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                )
              ],
            ),
            const Padding(padding: EdgeInsets.symmetric(vertical: 12), child: Divider(height: 1, color: AppColors.borderLight)),
            Text(nailName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textPrimary), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.access_time, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Text(booking['startTime']?.substring(0, 5) ?? '', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                const SizedBox(width: 16),
                const Icon(Icons.face_2, size: 16, color: Colors.grey),
                const SizedBox(width: 4),
                Expanded(child: Text(booking['artistName'] ?? 'Bất kỳ', style: const TextStyle(color: Colors.grey, fontSize: 13), overflow: TextOverflow.ellipsis)),
              ],
            )
          ],
        ),
      ),
    );
  }
}