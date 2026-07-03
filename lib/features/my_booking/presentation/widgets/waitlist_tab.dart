// ====================================================================
// FILE: lib/features/my_booking/presentation/widgets/waitlist_tab.dart
// Mô tả: Tab "Lịch chờ" — Quản lý danh sách Waitlist với mock data
// ====================================================================

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/models/waitlist_model.dart';
import 'waitlist_card.dart';

class WaitlistTab extends StatefulWidget {
  const WaitlistTab({super.key});

  @override
  State<WaitlistTab> createState() => _WaitlistTabState();
}

class _WaitlistTabState extends State<WaitlistTab> {
  late List<WaitlistModel> _waitlist;

  @override
  void initState() {
    super.initState();
    // Load mock data, sort: opened (có chỗ) luôn đứng đầu
    _waitlist = _sortedWaitlist(WaitlistMockData.initialList);
  }

  List<WaitlistModel> _sortedWaitlist(List<WaitlistModel> list) {
    final opened = list.where((e) => e.status == WaitlistStatus.opened).toList();
    final pending = list.where((e) => e.status == WaitlistStatus.pending).toList();
    return [...opened, ...pending];
  }

  void _cancelWaitlist(String id) {
    setState(() {
      _waitlist.removeWhere((e) => e.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã hủy chờ thành công.'),
        backgroundColor: Colors.grey.shade800,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _confirmBook(String id) {
    setState(() {
      _waitlist.removeWhere((e) => e.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Row(
          children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Text('Xác nhận đặt lịch thành công!'),
          ],
        ),
        backgroundColor: AppColors.primary,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _declineOpened(String id) {
    setState(() {
      _waitlist.removeWhere((e) => e.id == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Đã từ chối lịch chờ.'),
        backgroundColor: Colors.grey.shade700,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_waitlist.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      physics: const BouncingScrollPhysics(),
      itemCount: _waitlist.length,
      itemBuilder: (context, index) {
        final item = _waitlist[index];
        return WaitlistCard(
          key: ValueKey(item.id), // Key để AnimatedList hoạt động tốt
          item: item,
          onCancel: () => _cancelWaitlist(item.id),
          onConfirmBook: () => _confirmBook(item.id),
          onDecline: () => _declineOpened(item.id),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.notifications_off_outlined,
              size: 52,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Không có lịch chờ nào',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Khi khung giờ bạn chờ có chỗ trống,\nbạn sẽ nhận được thông báo tại đây.',
            style: TextStyle(
              color: Colors.grey.shade500,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
