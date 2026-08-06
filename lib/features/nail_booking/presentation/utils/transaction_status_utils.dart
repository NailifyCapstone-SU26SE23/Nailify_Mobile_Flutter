import 'package:flutter/material.dart';

class TransactionStatusView {
  final String key;
  final String label;
  final Color color;
  final IconData icon;

  const TransactionStatusView({
    required this.key,
    required this.label,
    required this.color,
    required this.icon,
  });
}

TransactionStatusView transactionStatusView(String? status) {
  switch (status?.trim()) {
    case 'Pending':
      return const TransactionStatusView(
        key: 'Pending',
        label: 'Chờ thanh toán',
        color: Colors.orange,
        icon: Icons.schedule_rounded,
      );
    case 'Paid':
      return const TransactionStatusView(
        key: 'Paid',
        label: 'Đã thanh toán',
        color: Colors.green,
        icon: Icons.check_circle_rounded,
      );
    case 'Overdue':
      return const TransactionStatusView(
        key: 'Overdue',
        label: 'Quá hạn',
        color: Colors.deepOrange,
        icon: Icons.timer_off_rounded,
      );
    case 'Cancelled':
      return const TransactionStatusView(
        key: 'Cancelled',
        label: 'Đã hủy',
        color: Colors.red,
        icon: Icons.cancel_rounded,
      );
    case 'Refunded':
      return const TransactionStatusView(
        key: 'Refunded',
        label: 'Đã hoàn tiền',
        color: Colors.blue,
        icon: Icons.assignment_return_rounded,
      );
    default:
      return TransactionStatusView(
        key: status?.trim() ?? '',
        label: status?.trim().isNotEmpty == true ? status!.trim() : 'Không rõ',
        color: Colors.grey,
        icon: Icons.receipt_long_rounded,
      );
  }
}

const transactionStatusOptions = <String>[
  'Pending',
  'Paid',
  'Overdue',
  'Cancelled',
  'Refunded',
];
