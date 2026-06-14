
class BookingMockData {
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

  // Danh sách Kỹ thuật viên kèm lịch bận (busySchedules)
  static const List<Map<String, dynamic>> stylists = [
    {
      'id': 'anyone',
      'name': 'Anyone',
      'role': 'Không ưu tiên thợ',
      'rating': '',
      'experience': '',
      'busySchedules': <int, List<String>>{}, // Không có lịch bận
    },
    {
      'id': 'stylist_1',
      'name': 'Amanda',
      'role': 'Master Stylist',
      'rating': '4.9',
      'experience': '5 năm EXP',
      'busySchedules': <int, List<String>>{
        14: ['09:30', '13:30', '14:30', '15:00', '15:30',],
        16: ['09:30', '13:30'],
        17: ['09:00', '09:30', '10:00', '10:30', '11:00',
          '13:30', '14:00', '14:30', '15:00', '15:30',
          '16:00', '16:30', '17:00', '17:30', '18:00'],
      },
    },
    {
      'id': 'stylist_2',
      'name': 'Jessica',
      'role': 'Expert Stylist',
      'rating': '4.8',
      'experience': '3 năm EXP',
      'busySchedules': <int, List<String>>{},
    },
    {
      'id': 'stylist_3',
      'name': 'Chloe',
      'role': 'Senior Stylist',
      'rating': '4.7',
      'experience': '2 năm EXP',
      'busySchedules': <int, List<String>>{},
    },
  ];

  static const List<String> timeSlots = [
    '09:00', '09:30', '10:00', '10:30', '11:00',
    '13:30', '14:00', '14:30', '15:00', '15:30',
    '16:00', '16:30', '17:00', '17:30', '18:00',
  ];
  //static const List<String> serviceGroups = ['NAIL', 'NAIL CARE'];

  static const List<String> extraServices = [
    'Tẩy gel', 'Làm sạch móng (Cắt da)',
    'Dưỡng móng cơ bản', 'Phục hồi móng hư tổn'
  ];

  static const Map<String, int> servicePrices = {
    'Tẩy gel': 30000, 'Làm sạch móng (Cắt da)': 40000,
    'Dưỡng móng cơ bản': 50000, 'Phục hồi móng hư tổn': 100000,
  };
}