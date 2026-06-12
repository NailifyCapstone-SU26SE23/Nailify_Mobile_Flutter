// lib/features/booking/data/models/booking_mock_data.dart

class BookingMockData {
  // Dữ liệu Chi nhánh salon (Đã có ở bước trước)
  static const List<Map<String, String>> branches = [
    {
      'id': 'branch_1',
      'name': 'Nailify Premium - Quận 1',
      'address': '123 Nguyễn Trãi, Phường Bến Thành, Quận 1, TP.HCM',
      'distance': '1.2 km',
      'rating': '4.9',
    },
    {
      'id': 'branch_2',
      'name': 'Nailify Studio - Tân Bình',
      'address': '456 Lê Văn Sỹ, Phường 2, Tân Bình, TP.HCM',
      'distance': '4.5 km',
      'rating': '4.8',
    },
    {
      'id': 'branch_3',
      'name': 'Nailify Boutique - Quận 5',
      'address': '789 Trần Hưng Đạo, Phường 1, Quận 5, TP.HCM',
      'distance': '3.0 km',
      'rating': '4.7',
    },
  ];

  // TẠO MỚI: Danh sách Kỹ thuật viên (Stylists)
  static const List<Map<String, String>> stylists = [
    {
      'id': 'stylist_1',
      'name': 'Amanda',
      'role': 'Master Stylist',
      'rating': '4.9',
      'experience': '5 năm EXP',
    },
    {
      'id': 'stylist_2',
      'name': 'Jessica',
      'role': 'Expert Stylist',
      'rating': '4.8',
      'experience': '3 năm EXP',
    },
    {
      'id': 'stylist_3',
      'name': 'Chloe',
      'role': 'Senior Stylist',
      'rating': '4.7',
      'experience': '2 năm EXP',
    },
    {
      'id': 'stylist_4',
      'name': 'Megan',
      'role': 'Junior Stylist',
      'rating': '4.6',
      'experience': '1 năm EXP',
    },
  ];

  // TẠO MỚI: Các khung giờ hẹn trống trong ngày
  static const List<String> timeSlots = [
    '09:00',
    '09:30',
    '10:00',
    '10:30',
    '11:00',
    '13:30',
    '14:00',
    '14:30',
    '15:00',
    '15:30',
    '16:00',
    '16:30',
    '17:00',
    '17:30',
    '18:00',
  ];
}