class StudioNailModel {
  final String id;
  final String name;
  final String status; // 'Draft', 'Pending', 'Approved', 'Rejected'
  final String imageUrl;
  final String shape;
  final String lengthText;
  final String color;
  final String pattern;
  final List<String> accessories;
  final String? salonName;
  final int? price;
  final int? duration;
  final String? rejectReason;
  final String? stylistId;
  final String? stylistName;
  final DateTime createdAt;

  StudioNailModel({
    required this.id,
    required this.name,
    required this.status,
    required this.imageUrl,
    required this.shape,
    required this.lengthText,
    required this.color,
    required this.pattern,
    required this.accessories,
    this.salonName,
    this.price,
    this.duration,
    this.rejectReason,
    this.stylistId,
    this.stylistName,
    required this.createdAt,
  });
}

class StudioMockData {
  static List<StudioNailModel> myCustomNails = [
    // --- DRAFT ---
    StudioNailModel(
      id: 'nail_1',
      name: 'Mẫu hoa cúc mùa xuân',
      status: 'Draft',
      imageUrl: 'assets/images/Rectangle 1.png',
      shape: 'Almond',
      lengthText: 'Medium',
      color: 'Soft Pink',
      pattern: 'French Tip',
      accessories: ['3D Flower', 'Pearl'],
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
    ),
    StudioNailModel(
      id: 'nail_2',
      name: 'Black Pink cá tính',
      status: 'Draft',
      imageUrl: 'assets/images/Rectangle 2.png',
      shape: 'Coffin',
      lengthText: 'Long',
      color: 'Deep Black',
      pattern: 'Gradient',
      accessories: ['Silver Charm'],
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
    ),

    // --- PENDING ---
    StudioNailModel(
      id: 'nail_4',
      name: 'Dạ hội lấp lánh',
      status: 'Pending',
      imageUrl: 'assets/images/image 2.png',
      shape: 'Stiletto',
      lengthText: 'Very Long',
      color: 'Rose Gold',
      pattern: 'Chrome',
      accessories: ['Rhinestone', 'Gold Charm'],
      salonName: 'Nailify Premium - Quận 1',
      createdAt: DateTime.now().subtract(const Duration(days: 4)),
    ),
    StudioNailModel(
      id: 'nail_5',
      name: 'Xanh rêu cổ điển',
      status: 'Pending',
      imageUrl: 'assets/images/image 3.png',
      shape: 'Square',
      lengthText: 'Medium',
      color: 'Moss Green',
      pattern: 'Matte',
      accessories: ['Gold Foil'],
      salonName: 'Nailify Studio - Tân Bình',
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
    ),

    // --- APPROVED (Đã có thông tin Thợ) ---
    StudioNailModel(
      id: 'nail_6',
      name: 'Mint nhẹ nhàng',
      status: 'Approved',
      imageUrl: 'assets/images/image 4.png',
      shape: 'Round',
      lengthText: 'Short',
      color: 'Mint',
      pattern: 'Marble',
      accessories: ['Ribbon Bow'],
      salonName: 'Nailify Boutique - Quận 5',
      price: 250000,
      duration: 60,
      stylistId: 'stylist_1',
      stylistName: 'Anna (Senior Stylist)',
      createdAt: DateTime.now().subtract(const Duration(days: 6)),
    ),
    StudioNailModel(
      id: 'nail_7',
      name: 'Hoàng hôn rực rỡ',
      status: 'Approved',
      imageUrl: 'assets/images/home-mid.jpg',
      shape: 'Almond',
      lengthText: 'Long',
      color: 'Peach Sunset',
      pattern: 'Ombre',
      accessories: ['Rhinestone', '3D Flower'],
      salonName: 'Nailify Premium - Quận 1',
      price: 450000,
      duration: 90,
      stylistId: 'stylist_2',
      stylistName: 'Jessica (Expert Stylist)',
      createdAt: DateTime.now().subtract(const Duration(days: 7)),
    ),

    // --- REJECTED ---
    StudioNailModel(
      id: 'nail_8',
      name: 'Full đính đá',
      status: 'Rejected',
      imageUrl: 'assets/images/Rectangle 1.png',
      shape: 'Coffin',
      lengthText: 'Very Long',
      color: 'Pure White',
      pattern: 'Solid Color',
      accessories: ['Rhinestone', 'Pearl', 'Gold Charm'],
      salonName: 'Nailify Studio - Tân Bình',
      rejectReason:
          'Tiệm hiện tại đang hết đá khối lớn, bạn có thể cân nhắc đổi sang charm kim loại nhé.',
      createdAt: DateTime.now().subtract(const Duration(days: 8)),
    ),
    StudioNailModel(
      id: 'nail_9',
      name: 'Galaxy huyền bí',
      status: 'Rejected',
      imageUrl: 'assets/images/Rectangle 2.png',
      shape: 'Stiletto',
      lengthText: 'Long',
      color: 'Navy Blue',
      pattern: 'Galaxy',
      accessories: ['Silver Glitter'],
      salonName: 'Nailify Boutique - Quận 5',
      rejectReason:
          'Kỹ thuật vẽ Galaxy hiện tại thợ chính đang nghỉ phép, vui lòng chọn mẫu khác hoặc đợi sau ngày 20.',
      createdAt: DateTime.now().subtract(const Duration(days: 9)),
    ),
  ];
}
