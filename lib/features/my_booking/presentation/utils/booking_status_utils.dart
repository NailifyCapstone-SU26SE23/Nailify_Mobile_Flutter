import 'package:flutter/material.dart';

class BookingStatusView {
  final String label;
  final Color backgroundColor;
  final Color textColor;

  const BookingStatusView(
    this.label,
    this.backgroundColor,
    this.textColor,
  );
}

BookingStatusView bookingStatusView(String? status) {
  switch (status) {
    case 'Pending':
      return BookingStatusView(
        'Đang chờ xác nhận',
        Colors.orange.shade50,
        Colors.orange.shade800,
      );
    case 'Assigned':
      return BookingStatusView(
        'Đã xếp lịch',
        Colors.blue.shade50,
        Colors.blue.shade800,
      );
    case 'Reviewed':
      return BookingStatusView(
        'Đã xem xét',
        Colors.indigo.shade50,
        Colors.indigo.shade800,
      );
    case 'Approved':
      return BookingStatusView(
        'Đã chấp nhận',
        Colors.green.shade50,
        Colors.green.shade800,
      );
    case 'Rejected':
      return BookingStatusView(
        'Đã từ chối',
        Colors.red.shade50,
        Colors.red.shade800,
      );
    case 'Cancelled':
      return BookingStatusView(
        'Đã hủy',
        Colors.grey.shade200,
        Colors.grey.shade800,
      );
    case 'CheckedIn':
      return BookingStatusView(
        'Đã Checked In',
        Colors.teal.shade50,
        Colors.teal.shade800,
      );
    case 'InProgress':
      return BookingStatusView(
        'Đang thực hiện',
        Colors.purple.shade50,
        Colors.purple.shade800,
      );
    case 'Completed':
      return BookingStatusView(
        'Đã hoàn thành',
        Colors.green.shade50,
        Colors.green.shade800,
      );
    case 'Repaired':
      return BookingStatusView(
        'Đã bảo hành',
        Colors.cyan.shade50,
        Colors.cyan.shade800,
      );
    default:
      return BookingStatusView(
        status ?? 'N/A',
        Colors.grey.shade100,
        Colors.grey.shade800,
      );
  }
}

bool bookingIsRated(Map<String, dynamic> booking) {
  final value = booking['isRated'] ?? booking['IsRated'];
  if (value is bool) return value;
  return value?.toString().toLowerCase() == 'true';
}
