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

  static const List<Map<String, dynamic>> stylists = [
    {
      'id': 'anyone',
      'name': 'Anyone',
      'role': 'Không ưu tiên thợ',
      'rating': '',
      'experience': '',
      'busySchedules': <int, List<String>>{},
    },
    {
      'id': 'stylist_1',
      'name': 'Amanda',
      'role': 'Master Stylist',
      'rating': '4.9',
      'experience': '5 năm EXP',
      'busySchedules': <int, List<String>>{
        14: ['09:30', '13:30', '14:30', '15:00', '15:30'],
        16: ['09:30', '13:30'],
        17: [
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
        ],
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

  static const List<Map<String, dynamic>> extraServices = [
    {
      'id': 'f512b732-231c-4584-b3f0-647603b1f167',
      'name': 'Chà gót chân',
      'price': 12000,
    },
    {'id': 'tay-gel', 'name': 'Tẩy gel', 'price': 30000},
    {'id': 'lam-sach-mong', 'name': 'Làm sạch móng (Cắt da)', 'price': 40000},
    {'id': 'duong-mong-co-ban', 'name': 'Dưỡng móng cơ bản', 'price': 50000},
    {'id': 'phuc-hoi-mong', 'name': 'Phục hồi móng hư tổn', 'price': 100000},
  ];

  static final Map<String, int> servicePrices = {
    for (final service in extraServices)
      service['id'] as String: service['price'] as int,
  };
}
