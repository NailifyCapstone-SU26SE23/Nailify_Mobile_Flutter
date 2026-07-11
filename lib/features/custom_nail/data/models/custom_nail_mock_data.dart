import 'package:flutter/material.dart';

class CustomNailMockData {
  // 1. Dữ liệu cho Bước 1: Shape (Hình dạng móng)
  static const List<String> shapes = [
    'Oval',
    'Almond',
    'Square',
    'Coffin',
    'Stiletto',
    'Round',
  ];

  // 2. Dữ liệu cho Bước 2: Bảng màu sắc (Color Palettes)
  static const Map<String, List<Map<String, dynamic>>> colorPalettes = {
    'Solid': [
      {'name': 'Soft Pink', 'color': Color(0xFFFFB6C1)},
      {'name': 'Classic Red', 'color': Color(0xFFFF0000)},
      {'name': 'Nude Beige', 'color': Color(0xFFF5F5DC)},
      {'name': 'Pure White', 'color': Color(0xFFFFFFFF)},
      {'name': 'Deep Black', 'color': Color(0xFF1A1A1A)},
      {'name': 'Lavender', 'color': Color(0xFFE6E6FA)},
      {'name': 'Mint', 'color': Color(0xFF98FF98)},
      {'name': 'Sky Blue', 'color': Color(0xFF87CEEB)},
    ],
    'Glitter': [
      {'name': 'Rose Gold', 'color': Color(0xFFB76E79)},
      {'name': 'Silver Spark', 'color': Color(0xFFC0C0C0)},
      {'name': 'Gold Dust', 'color': Color(0xFFFFD700)},
    ],
    'Ombre': [
      {'name': 'Pink Fade', 'color': Color(0xFFFFC0CB)},
      {'name': 'Peach Sunset', 'color': Color(0xFFFFDAB9)},
    ],
    'Cat Eye': [
      {'name': 'Mystic Blue', 'color': Color(0xFF000080)},
      {'name': 'Emerald Eye', 'color': Color(0xFF50C878)},
    ],
  };

  // 3. Dữ liệu cho Bước 3: Pattern & Design (Hoa văn)
  static const List<Map<String, String>> patterns = [
    {'name': 'French Tip', 'image': 'assets/images/Rectangle 1.png'},
    {'name': 'Ombre', 'image': 'assets/images/Rectangle 2.png'},
    {'name': 'Gradient', 'image': 'assets/images/image 1.png'},
    {'name': 'Solid Color', 'image': 'assets/images/image 2.png'},
    {'name': 'Marble', 'image': 'assets/images/image 3.png'},
    {'name': 'Chrome', 'image': 'assets/images/image 4.png'},
  ];

  // 4. Dữ liệu cho Bước 4: Accessories (Phụ kiện)
  static const List<Map<String, String>> accessories = [
    {'name': 'Silver Charm', 'image': 'assets/images/Rectangle 1.png'},
    {'name': 'Gold Charm', 'image': 'assets/images/Rectangle 2.png'},
    {'name': 'Pearl', 'image': 'assets/images/image 1.png'},
    {'name': 'Rhinestone', 'image': 'assets/images/image 2.png'},
    {'name': '3D Flower', 'image': 'assets/images/image 3.png'},
    {'name': 'Ribbon Bow', 'image': 'assets/images/image 4.png'},
  ];
}
