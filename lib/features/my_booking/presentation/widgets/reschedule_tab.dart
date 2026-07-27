// ====================================================================
// FILE: lib/features/my_booking/presentation/widgets/reschedule_tab.dart
// Mô tả: Tab "Dời lịch" — Quản lý danh sách dời lịch (Reschedule)
// ====================================================================

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../data/datasources/my_booking_api_service.dart';
import '../utils/booking_status_utils.dart';

class RescheduleTab extends StatefulWidget {
  final List<Map<String, dynamic>> rescheduleBookings;
  final VoidCallback onRefreshBookings;
  final VoidCallback? onActionSuccess; // Callback khi accept/decline thành công → chuyển tab

  const RescheduleTab({
    super.key,
    required this.rescheduleBookings,
    required this.onRefreshBookings,
    this.onActionSuccess,
  });

  @override
  State<RescheduleTab> createState() => _RescheduleTabState();
}

class _RescheduleTabState extends State<RescheduleTab> {
  final MyBookingApiService _bookingApiService = MyBookingApiService();
  bool _isActionLoading = false;
  DateTime? _selectedFilterDate;

  Future<void> _acceptReschedule(String bookingId) async {
    setState(() => _isActionLoading = true);
    try {
      final success = await _bookingApiService.acceptSuggestedTime(bookingId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã chấp nhận dời lịch hẹn thành công'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        widget.onRefreshBookings();
        // Chuyển về tab Lịch đặt sau khi thành công
        widget.onActionSuccess?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Chấp nhận dời lịch hẹn thất bại'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  Future<void> _declineReschedule(String bookingId) async {
    setState(() => _isActionLoading = true);
    try {
      final success = await _bookingApiService.declineSuggestedTime(bookingId);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Đã từ chối dời lịch hẹn thành công'),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 2),
          ),
        );
        widget.onRefreshBookings();
        // Chuyển về tab Lịch đặt sau khi thành công
        widget.onActionSuccess?.call();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Từ chối dời lịch hẹn thất bại'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Lỗi: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isActionLoading = false);
    }
  }

  List<Map<String, dynamic>> get _filteredBookings {
    final bookings = widget.rescheduleBookings;
    if (_selectedFilterDate == null) return bookings;
    return bookings.where((booking) {
      final dateStr = booking['proposedBookingDate']?.toString() ??
          booking['newDate']?.toString() ??
          booking['suggestedDate']?.toString() ??
          booking['bookingDate']?.toString() ??
          '';
      final bookingDate = DateTime.tryParse(dateStr);
      if (bookingDate == null) return false;
      return bookingDate.year == _selectedFilterDate!.year &&
          bookingDate.month == _selectedFilterDate!.month &&
          bookingDate.day == _selectedFilterDate!.day;
    }).toList();
  }

  Future<void> _selectFilterDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedFilterDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2101),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedFilterDate) {
      setState(() {
        _selectedFilterDate = picked;
      });
    }
  }

  Widget _buildDateFilterBar() {
    final hasFilter = _selectedFilterDate != null;
    final textDisplay = hasFilter
        ? 'Ngày: ${_selectedFilterDate!.day}/${_selectedFilterDate!.month}/${_selectedFilterDate!.year}'
        : 'Lọc theo ngày';

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: () => _selectFilterDate(context),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8FB), // Tông hồng sữa ngọt ngào tinh tế
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.primary.withValues(alpha: 0.15)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.calendar_month, color: AppColors.primary, size: 20),
                    const SizedBox(width: 10),
                    Text(
                      textDisplay,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: hasFilter ? FontWeight.bold : FontWeight.w500,
                        color: hasFilter ? AppColors.primary : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (hasFilter) ...[
            const SizedBox(width: 10),
            IconButton(
              onPressed: () {
                setState(() {
                  _selectedFilterDate = null;
                });
              },
              icon: const Icon(Icons.highlight_off_rounded, color: Colors.grey, size: 24),
              tooltip: 'Xóa lọc ngày',
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _handleRefresh() async {
    widget.onRefreshBookings();
  }

  @override
  Widget build(BuildContext context) {
    final filteredBookings = _filteredBookings;

    Widget content;
    if (filteredBookings.isEmpty) {
      content = _buildEmptyState(isFiltered: _selectedFilterDate != null);
    } else {
      content = RefreshIndicator(
        onRefresh: _handleRefresh,
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
          itemCount: filteredBookings.length,
          itemBuilder: (context, index) {
            return _buildRescheduleCard(filteredBookings[index]);
          },
        ),
      );
    }

    return Column(
      children: [
        _buildDateFilterBar(),
        Expanded(
          child: Stack(
            children: [
              content,
              if (_isActionLoading)
                Container(
                  color: Colors.black.withValues(alpha: 0.3),
                  child: const Center(
                    child: Card(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.all(Radius.circular(12)),
                      ),
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: 32, vertical: 24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            CircularProgressIndicator(),
                            SizedBox(height: 12),
                            Text('Đang xử lý...'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildRescheduleCard(Map<String, dynamic> booking) {
    final bookingIdStr = booking['bookingId']?.toString() ?? '';
    final dateStr = booking['bookingDate']?.toString() ?? '';
    final bookingDate = DateTime.tryParse(dateStr) ?? DateTime.now();

    final newDateStr = booking['proposedBookingDate']?.toString() ??
        booking['newDate']?.toString() ??
        booking['suggestedDate']?.toString() ??
        booking['bookingDate']?.toString() ??
        '';
    final newBookingDate = DateTime.tryParse(newDateStr) ?? bookingDate;

    final items = booking['bookingItems'] as List<dynamic>? ?? [];
    var nailName = 'Dịch vụ làm móng';

    if (items.isNotEmpty && items.first is Map) {
      final firstItem = items.first as Map;
      final variantName = firstItem['nailVariantName']?.toString().trim() ?? '';
      final customNailName = firstItem['customerNailName']?.toString().trim() ?? '';
      final serviceName = firstItem['serviceName']?.toString().trim() ?? '';
      if (variantName.isNotEmpty) {
        nailName = variantName;
      } else if (customNailName.isNotEmpty) {
        nailName = customNailName;
      } else if (serviceName.isNotEmpty) {
        nailName = serviceName;
      }
    }

    String timeStr = booking['startTime']?.toString() ?? '';
    if (timeStr.length >= 5) timeStr = timeStr.substring(0, 5);

    String newTimeStr = booking['proposedStartTime']?.toString() ??
        booking['newTime']?.toString() ??
        booking['suggestedTime']?.toString() ??
        timeStr;
    if (newTimeStr.length >= 5) newTimeStr = newTimeStr.substring(0, 5);

    final artistName = booking['artistName']?.toString() ?? 'Bất kỳ';
    final salonName = booking['salonName']?.toString() ?? 'Nailify Salon';
    final salonAddress = booking['salonAddress']?.toString() ?? '';
    final reason = booking['rescheduleReason']?.toString() ??
        booking['reason']?.toString() ??
        '';

    final rawStatus = booking['status']?.toString();
    final statusView = bookingStatusView(rawStatus);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusView.textColor.withValues(alpha: 0.5),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: statusView.backgroundColor.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Badge trạng thái
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusView.backgroundColor,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: statusView.textColor.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      Icon(statusView.icon, size: 12, color: statusView.textColor),
                      const SizedBox(width: 4),
                      Text(
                        statusView.label,
                        style: TextStyle(
                          color: statusView.textColor,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  'Mới',
                  style: TextStyle(
                    fontSize: 11,
                    color: statusView.textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),

            // Tên Salon & Địa chỉ
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.storefront_outlined, size: 16, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        salonName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      if (salonAddress.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          salonAddress,
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Khung giờ đề xuất (màu tương ứng với trạng thái)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: statusView.backgroundColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: statusView.textColor.withValues(alpha: 0.15)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(statusView.icon, size: 16, color: statusView.textColor),
                      const SizedBox(width: 6),
                      Text(
                        rawStatus == 'RescheduleSuggested'
                            ? 'Giờ hẹn đề xuất mới từ salon:'
                            : 'Khung giờ bạn yêu cầu dời:',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: statusView.textColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '$newTimeStr • ${newBookingDate.day}/${newBookingDate.month}/${newBookingDate.year}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: statusView.textColor,
                    ),
                  ),
                  if (timeStr.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Lịch cũ: $timeStr • ${bookingDate.day}/${bookingDate.month}/${bookingDate.year}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey.shade600,
                        decoration: TextDecoration.lineThrough,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Dịch vụ & Thợ
            Row(
              children: [
                Icon(Icons.cut_rounded, size: 15, color: Colors.grey.shade500),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    nailName,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(Icons.person_outline, size: 15, color: Colors.grey.shade500),
                const SizedBox(width: 4),
                Text(
                  artistName,
                  style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                ),
              ],
            ),

            if (reason.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline, size: 15, color: statusView.textColor),
                  const SizedBox(width: 6),
                  Expanded(
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade700, height: 1.4),
                        children: [
                          const TextSpan(
                            text: 'Lý do dời: ',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          TextSpan(text: reason),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],

            if (rawStatus == 'RescheduleSuggested') ...[
              // Nút hành động Đồng ý / Từ chối dời lịch
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _isActionLoading
                            ? null
                            : () => _declineReschedule(bookingIdStr),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade400,
                          side: BorderSide(color: Colors.red.shade200),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                        ),
                        child: const Text(
                          'Từ chối',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: _isActionLoading
                            ? null
                            : () => _acceptReschedule(bookingIdStr),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 11),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Chấp nhận dời lịch',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else ...[
              // For ReschedulePending
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                  decoration: BoxDecoration(
                    color: statusView.backgroundColor.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: statusView.textColor.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    children: [
                      Icon(statusView.icon, size: 14, color: statusView.textColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Đang chờ salon phản hồi yêu cầu dời lịch của bạn',
                          style: TextStyle(
                            fontSize: 12,
                            color: statusView.textColor,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState({bool isFiltered = false}) {
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
              isFiltered ? Icons.filter_alt_off_outlined : Icons.edit_calendar_outlined,
              size: 52,
              color: Colors.grey.shade400,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isFiltered ? 'Không có yêu cầu dời lịch trong ngày này' : 'Không có yêu cầu dời lịch nào',
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isFiltered
                ? 'Thử chọn ngày khác hoặc xóa bộ lọc ngày.'
                : 'Khi có yêu cầu dời lịch từ Salon hoặc\nyêu cầu dời lịch của bạn đang được xử lý,\nbản ghi sẽ được hiển thị tại đây.',
            style: TextStyle(color: Colors.grey.shade500, height: 1.5),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
