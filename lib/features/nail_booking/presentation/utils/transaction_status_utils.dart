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
  final raw = status?.trim() ?? '';
  if (raw.isEmpty) {
    return const TransactionStatusView(
      key: '',
      label: 'Không rõ',
      color: Colors.grey,
      icon: Icons.receipt_long_rounded,
    );
  }

  final lower = raw.toLowerCase();

  if (lower == 'pending' || lower == 'processing' || lower == 'in_progress') {
    return const TransactionStatusView(
      key: 'Pending',
      label: 'Chờ xử lý',
      color: Color(0xFFF59E0B),
      icon: Icons.schedule_rounded,
    );
  }

  if (lower == 'paid' ||
      lower == 'completed' ||
      lower == 'success' ||
      lower == 'succeeded') {
    return const TransactionStatusView(
      key: 'Completed',
      label: 'Đã hoàn thành',
      color: Color(0xFF10B981),
      icon: Icons.check_circle_rounded,
    );
  }

  if (lower == 'overdue') {
    return const TransactionStatusView(
      key: 'Overdue',
      label: 'Quá hạn',
      color: Color(0xFFEA580C),
      icon: Icons.timer_off_rounded,
    );
  }

  if (lower == 'cancelled' || lower == 'failed' || lower == 'rejected') {
    return const TransactionStatusView(
      key: 'Cancelled',
      label: 'Đã hủy',
      color: Color(0xFFEF4444),
      icon: Icons.cancel_rounded,
    );
  }

  if (lower == 'refunded' || lower.contains('refund')) {
    return const TransactionStatusView(
      key: 'Refunded',
      label: 'Đã hoàn tiền',
      color: Color(0xFF0284C7),
      icon: Icons.assignment_return_rounded,
    );
  }

  return TransactionStatusView(
    key: raw,
    label: raw,
    color: const Color(0xFF6B7280),
    icon: Icons.receipt_long_rounded,
  );
}

const transactionStatusOptions = <String>[
  'Pending',
  'Paid',
  'Overdue',
  'Cancelled',
  'Refunded',
];

/// Trả về chuỗi mô tả giao dịch sạch, không chứa booking ID / GUID.
String formatTransactionDescription(dynamic rawValue) {
  if (rawValue == null) return '';
  String text = rawValue.toString().trim();
  if (text.isEmpty) return '';

  final lower = text.toLowerCase();

  // Kiểm tra loại giao dịch hoàn tiền
  if (lower.contains('hoàn') || lower.contains('refund')) {
    if (lower.contains('ví') || lower.contains('wallet')) {
      return 'Hoàn phần tiền thanh toán bằng ví';
    }
    return 'Hoàn tiền cọc';
  }

  // Kiểm tra loại giao dịch thanh toán
  if (lower.contains('thanh toán') ||
      lower.contains('cọc') ||
      lower.contains('đặt lịch') ||
      lower.contains('payment') ||
      lower.contains('deposit')) {
    return 'Thanh toán cọc/đơn đặt lịch';
  }

  // Nếu là chuỗi khác, loại bỏ GUID / booking ID nếu có
  text = text.replaceAll(
    RegExp(
      r'#?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}',
    ),
    '',
  );
  text = text.replaceAll(
    RegExp(r'(của|of)?\s*booking\s*', caseSensitive: false),
    '',
  );
  text = text.replaceAll(RegExp(r'#+\s*'), '');
  text = text.trim().replaceAll(RegExp(r'[\s\-:]+$'), '').trim();

  return text;
}

