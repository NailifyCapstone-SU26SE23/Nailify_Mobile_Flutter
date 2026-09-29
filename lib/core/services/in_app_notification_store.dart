import 'package:flutter/material.dart';

class InAppNotificationItem {
  final String id;
  final String title;
  final String message;
  final DateTime timestamp;
  final IconData icon;
  final Color color;
  final String? route;
  final Map<String, dynamic>? extra;
  bool isRead;

  InAppNotificationItem({
    required this.id,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.icon,
    required this.color,
    this.route,
    this.extra,
    this.isRead = false,
  });
}

class InAppNotificationStore extends ChangeNotifier {
  final List<InAppNotificationItem> _notifications = [];

  List<InAppNotificationItem> get notifications =>
      List.unmodifiable(_notifications);

  int get unreadCount => _notifications.where((n) => !n.isRead).length;

  bool get hasNotifications => _notifications.isNotEmpty;

  void addNotification({
    required String title,
    required String message,
    required IconData icon,
    required Color color,
    String? route,
    Map<String, dynamic>? extra,
  }) {
    final item = InAppNotificationItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      title: title,
      message: message,
      timestamp: DateTime.now(),
      icon: icon,
      color: color,
      route: route,
      extra: extra,
    );

    _notifications.insert(0, item);
    notifyListeners();
  }

  void markAsRead(String id) {
    final index = _notifications.indexWhere((n) => n.id == id);
    if (index != -1 && !_notifications[index].isRead) {
      _notifications[index].isRead = true;
      notifyListeners();
    }
  }

  void markAllAsRead() {
    bool updated = false;
    for (var item in _notifications) {
      if (!item.isRead) {
        item.isRead = true;
        updated = true;
      }
    }
    if (updated) {
      notifyListeners();
    }
  }

  void removeNotification(String id) {
    _notifications.removeWhere((n) => n.id == id);
    notifyListeners();
  }

  /// Xóa toàn bộ thông báo (dùng khi Đăng xuất hoặc Thoát app)
  void clear() {
    _notifications.clear();
    notifyListeners();
  }
}
