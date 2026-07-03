// ====================================================================
// FILE: lib/features/my_booking/data/models/waitlist_model.dart
// Mô tả: Model & Mock Data cho tính năng Slot Waitlist
// ====================================================================

enum WaitlistStatus { pending, opened }

class WaitlistModel {
  final String id;
  final String salonName;
  final String address;
  final String time; // "09:00"
  final DateTime date;
  final String staffName;
  final List<String> services;
  final WaitlistStatus status;
  final DateTime holdUntil; // Thời hạn giữ chỗ (chỉ có ý nghĩa khi status == opened)
  final DateTime registeredAt; // Thời điểm đăng ký

  const WaitlistModel({
    required this.id,
    required this.salonName,
    required this.address,
    required this.time,
    required this.date,
    required this.staffName,
    required this.services,
    required this.status,
    required this.holdUntil,
    required this.registeredAt,
  });

  WaitlistModel copyWith({
    String? id,
    String? salonName,
    String? address,
    String? time,
    DateTime? date,
    String? staffName,
    List<String>? services,
    WaitlistStatus? status,
    DateTime? holdUntil,
    DateTime? registeredAt,
  }) {
    return WaitlistModel(
      id: id ?? this.id,
      salonName: salonName ?? this.salonName,
      address: address ?? this.address,
      time: time ?? this.time,
      date: date ?? this.date,
      staffName: staffName ?? this.staffName,
      services: services ?? this.services,
      status: status ?? this.status,
      holdUntil: holdUntil ?? this.holdUntil,
      registeredAt: registeredAt ?? this.registeredAt,
    );
  }
}

// ====================================================================
// MOCK DATA - Dữ liệu giả lập cục bộ
// ====================================================================
class WaitlistMockData {
  static List<WaitlistModel> get initialList => [
        WaitlistModel(
          id: 'wl-001',
          salonName: 'Nailify - Chi nhánh Quận 1',
          address: '12 Nguyễn Huệ, Bến Nghé, Quận 1, TP.HCM',
          time: '09:00',
          date: DateTime.now().add(const Duration(days: 2)),
          staffName: 'Trung Hiếu',
          services: ['Làm móng gel', 'Vẽ nghệ thuật', 'Dưỡng móng'],
          status: WaitlistStatus.opened, // Trạng thái: CÓ CHỖ TRỐNG
          holdUntil: DateTime.now().add(const Duration(minutes: 5)),
          registeredAt: DateTime.now().subtract(const Duration(hours: 3)),
        ),
        WaitlistModel(
          id: 'wl-002',
          salonName: 'Nailify - Chi nhánh Quận 3',
          address: '45 Võ Văn Tần, Phường 6, Quận 3, TP.HCM',
          time: '14:00',
          date: DateTime.now().add(const Duration(days: 1)),
          staffName: 'Thanh Lan',
          services: ['Sơn thường', 'Cắt tỉa'],
          status: WaitlistStatus.pending, // Trạng thái: ĐANG XẾP HÀNG
          holdUntil: DateTime.now().add(const Duration(hours: 2)),
          registeredAt: DateTime.now().subtract(const Duration(hours: 2)),
        ),
        WaitlistModel(
          id: 'wl-003',
          salonName: 'Nailify - Chi nhánh Bình Thạnh',
          address: '87 Đinh Tiên Hoàng, Phường 3, Bình Thạnh, TP.HCM',
          time: '11:30',
          date: DateTime.now().add(const Duration(days: 4)),
          staffName: 'Minh Châu',
          services: ['Làm móng gel', 'Spa tay chân'],
          status: WaitlistStatus.pending,
          holdUntil: DateTime.now().add(const Duration(hours: 1)),
          registeredAt: DateTime.now().subtract(const Duration(minutes: 30)),
        ),
      ];
}
