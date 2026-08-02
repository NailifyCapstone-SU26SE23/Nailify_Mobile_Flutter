import 'package:flutter/material.dart';

class BookingStatusView {
  final String label;
  final Color backgroundColor;
  final Color textColor;
  final IconData icon;

  const BookingStatusView(
    this.label,
    this.backgroundColor,
    this.textColor,
    this.icon,
  );
}

BookingStatusView bookingStatusView(String? status) {
  switch (status) {
    case 'Pending':
      return BookingStatusView(
        'Đang chờ xác nhận',
        Colors.orange.shade50,
        Colors.orange.shade800,
        Icons.hourglass_empty_rounded,
      );
    case 'Assigned':
      return BookingStatusView(
        'Đã xếp lịch',
        Colors.blue.shade50,
        Colors.blue.shade800,
        Icons.calendar_today_rounded,
      );
    case 'Reviewed':
      return BookingStatusView(
        'Đã xem xét',
        Colors.indigo.shade50,
        Colors.indigo.shade800,
        Icons.rate_review_rounded,
      );
    case 'Approved':
      return BookingStatusView(
        'Đã chấp nhận',
        Colors.green.shade50,
        Colors.green.shade800,
        Icons.check_circle_outline_rounded,
      );
    case 'Rejected':
      return BookingStatusView(
        'Đã từ chối',
        Colors.red.shade50,
        Colors.red.shade800,
        Icons.cancel_outlined,
      );
    case 'Cancelled':
      return BookingStatusView(
        'Đã hủy',
        Colors.grey.shade200,
        Colors.grey.shade800,
        Icons.block_rounded,
      );
    case 'CheckedIn':
      return BookingStatusView(
        'Đã Checked In',
        Colors.teal.shade50,
        Colors.teal.shade800,
        Icons.login_rounded,
      );
    case 'InProgress':
      return BookingStatusView(
        'Đang thực hiện',
        Colors.purple.shade50,
        Colors.purple.shade800,
        Icons.play_circle_outline_rounded,
      );
    case 'Completed':
      return BookingStatusView(
        'Đã hoàn thành',
        Colors.green.shade50,
        Colors.green.shade800,
        Icons.check_circle_rounded,
      );
    case 'ServiceCompleted':
      return BookingStatusView(
        'Hoàn thành dịch vụ',
        Colors.teal.shade50,
        Colors.teal.shade800,
        Icons.task_alt_rounded,
      );
    case 'Repaired':
      return BookingStatusView(
        'Đã bảo hành',
        Colors.cyan.shade50,
        Colors.cyan.shade800,
        Icons.build_rounded,
      );
    case 'ReschedulePending':
      return BookingStatusView(
        'Chờ duyệt dời lịch',
        Colors.indigo.shade50,
        Colors.indigo.shade800,
        Icons.hourglass_empty_rounded,
      );
    case 'RescheduleSuggested':
      return BookingStatusView(
        'Đề xuất dời lịch',
        Colors.amber.shade50,
        Colors.amber.shade800,
        Icons.event_note_rounded,
      );
    case 'RescheduleApproved':
      return BookingStatusView(
        'Đã duyệt dời lịch',
        Colors.green.shade50,
        Colors.green.shade800,
        Icons.event_available_rounded,
      );
    case 'RescheduleRejected':
      return BookingStatusView(
        'Từ chối dời lịch',
        Colors.red.shade50,
        Colors.red.shade800,
        Icons.event_busy_rounded,
      );
    default:
      return BookingStatusView(
        status ?? 'N/A',
        Colors.grey.shade100,
        Colors.grey.shade800,
        Icons.info_outline_rounded,
      );
  }
}

bool bookingIsRated(Map<String, dynamic> booking) {
  final value = booking['isRated'] ?? booking['IsRated'];
  if (value is bool) return value;
  return value?.toString().toLowerCase() == 'true';
}
