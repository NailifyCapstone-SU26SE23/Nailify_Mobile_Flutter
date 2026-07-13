// ====================================================================
// FILE: lib/features/my_booking/presentation/widgets/waitlist_tab.dart
// Mô tả: Tab "Lịch chờ" — Quản lý danh sách Waitlist với API thật
// ====================================================================

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/datasources/waitlist_api_service.dart';
import '../../data/models/waitlist_model.dart';
import 'waitlist_card.dart';

class WaitlistTab extends StatefulWidget {
  const WaitlistTab({super.key});

  @override
  State<WaitlistTab> createState() => _WaitlistTabState();
}

class _WaitlistTabState extends State<WaitlistTab> {
  final WaitlistApiService _apiService = WaitlistApiService();

  List<WaitlistModel> _waitlist = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchWaitlists();
  }

  Future<void> _fetchWaitlists() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final apiItems = await _apiService.getMyWaitlists();
      // Map API models sang WaitlistModel và sort: opened trước
      final models = apiItems.map((e) => WaitlistModel.fromApi(e)).toList();
      models.sort((a, b) {
        if (a.status == WaitlistStatus.opened && b.status != WaitlistStatus.opened) return -1;
        if (a.status != WaitlistStatus.opened && b.status == WaitlistStatus.opened) return 1;
        return 0;
      });
      if (mounted) setState(() => _waitlist = models);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
      debugPrint('==== LỖI API WAITLIST: $e ====');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _cancelWaitlist(String id) async {
    try {
      final success = await _apiService.cancelWaitlist(id);
      if (!mounted) return;
      if (success) {
        setState(() => _waitlist.removeWhere((e) => e.id == id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Đã hủy chờ thành công.'),
            backgroundColor: Colors.grey.shade800,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi hủy chờ: $e')),
      );
    }
  }

  Future<void> _confirmBook(String id) async {
    try {
      final success = await _apiService.confirmWaitlist(id);
      if (!mounted) return;
      if (success) {
        setState(() => _waitlist.removeWhere((e) => e.id == id));
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lỗi xác nhận: $e')),
      );
    }
  }

  void _declineOpened(String id) => _cancelWaitlist(id);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Center(child: CircularProgressIndicator());

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 52, color: Colors.red.shade300),
            const SizedBox(height: 12),
            Text('Không thể tải lịch chờ', style: TextStyle(color: Colors.grey.shade700)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: _fetchWaitlists,
              icon: const Icon(Icons.refresh),
              label: const Text('Thử lại'),
            ),
          ],
        ),
      );
    }

    if (_waitlist.isEmpty) return _buildEmptyState();

    return RefreshIndicator(
      onRefresh: _fetchWaitlists,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        physics: const BouncingScrollPhysics(),
        itemCount: _waitlist.length,
        itemBuilder: (context, index) {
          final item = _waitlist[index];
          return WaitlistCard(
            key: ValueKey(item.id),
            item: item,
            onCancel: () => _cancelWaitlist(item.id),
            onConfirmBook: () => _confirmBook(item.id),
            onDecline: () => _declineOpened(item.id),
          );
        },
      ),
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
            style: TextStyle(color: Colors.grey.shade500, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
