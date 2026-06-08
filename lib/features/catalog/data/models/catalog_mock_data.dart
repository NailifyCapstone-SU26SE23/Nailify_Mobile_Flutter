class CatalogMockData {
  static const List<String> styles = ['Cute & Sweet', 'Minimalist Cool', 'Luxury Art', 'Y2K', 'Vintage'];
  static const List<String> themes = ['Floral', 'Geometric', 'Abstract', 'Animal Print', 'Seasonal'];
  static const List<String> designs = ['French Tip', 'Ombre', 'Solid Color', '3D Art', 'Hand-painted'];
  static const List<String> variants = ['Short Round', 'Medium Almond', 'Long Coffin', 'Square', 'Stiletto'];
  static const List<String> detailElement = ['Stones/Pearls', 'Charms', 'Foil', 'Ribbon', 'Dried Flowers'];
  static const List<String> surfaces = ['Glossy Shine', 'Matte Velvet', 'Glitter Sparkle', 'Metallic', 'Chrome'];
  static const List<String> occasions = ['Go to work', 'Party/event', 'Wedding', 'Tourism', 'Date night'];

  // Cập nhật danh sách Nails đầy đủ các thuộc tính chi tiết phục vụ trang Nail Details
  static final List<Map<String, dynamic>> nails = [
    {
      'id': '1',
      'name': 'Candy Bloom',
      'image': 'assets/images/Rectangle 1.png',
      'tags': ['Cute & Sweet', 'Glossy Shine', 'Date night'],
      'shape': 'Medium Almond',
      'length': 'Medium',
      'surface': 'Glossy Shine',
      'decorate': 'Flower Art & Ribbon',
      'occasion': 'Date night',
      'color': 'Pastel Pink & White',
      'personality': 'Cute & Sweet'
    },
    {
      'id': '2',
      'name': 'Galaxy Sparkle',
      'image': 'assets/images/Rectangle 2.png',
      'tags': ['Luxury Art', 'Glitter Sparkle', 'Party/event'],
      'shape': 'Long Coffin',
      'length': 'Long',
      'surface': 'Glitter Sparkle',
      'decorate': 'Stones & Crystals',
      'occasion': 'Party/event',
      'color': 'Deep Purple & Silver',
      'personality': 'Luxury Art'
    },
    {
      'id': '3',
      'name': 'Velvet Dream',
      'image': 'assets/images/image 1.png',
      'tags': ['Minimalist Cool', 'Matte Velvet', 'Go to work'],
      'shape': 'Short Round',
      'length': 'Short',
      'surface': 'Matte Velvet',
      'decorate': 'Geometric Lines',
      'occasion': 'Go to work',
      'color': 'Nude Brown & Beige',
      'personality': 'Minimalist Cool'
    },
    {
      'id': '4',
      'name': 'Wedding Bliss',
      'image': 'assets/images/image 2.png',
      'tags': ['Luxury Art', 'Wedding'],
      'shape': 'Medium Almond',
      'length': 'Medium',
      'surface': 'Glossy Shine',
      'decorate': 'Pearls & Dried Flowers',
      'occasion': 'Wedding',
      'color': 'Soft Cream & Gold Foil',
      'personality': 'Elegant Luxury'
    }
  ];
}