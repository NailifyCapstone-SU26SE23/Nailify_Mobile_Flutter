class NailDesignItem {
  final String id;
  final String name;
  final String image;
  final String style;
  final String sortDate;
  final double rating;
  final int likesCount;
  final bool isFavorite;

  const NailDesignItem({
    required this.id,
    required this.name,
    required this.image,
    required this.style,
    required this.sortDate,
    this.rating = 4.9,
    this.likesCount = 128,
    this.isFavorite = false,
  });

  Map<String, dynamic> toNailData() => {
    'id': id,
    'name': name,
    'image': image,
    'tags': [style],
  };

  NailDesignItem copyWith({
    String? id,
    String? name,
    String? image,
    String? style,
    String? sortDate,
    double? rating,
    int? likesCount,
    bool? isFavorite,
  }) {
    return NailDesignItem(
      id: id ?? this.id,
      name: name ?? this.name,
      image: image ?? this.image,
      style: style ?? this.style,
      sortDate: sortDate ?? this.sortDate,
      rating: rating ?? this.rating,
      likesCount: likesCount ?? this.likesCount,
      isFavorite: isFavorite ?? this.isFavorite,
    );
  }
}

class AnotherDesignMockData {
  static const List<String> styleFilters = [
    'All styles',
    'Minimal',
    'Floral',
    'Chrome',
    'French',
    'Abstract',
  ];

  static const List<String> sortOptions = ['Newest', 'Oldest', 'A-Z'];

  static const List<NailDesignItem> designs = [
    NailDesignItem(
      id: '1',
      name: 'Candy Bloom',
      image: 'assets/images/Rectangle 1.png',
      style: 'Chrome',
      sortDate: '2026-03-01',
      rating: 4.9,
      likesCount: 245,
      isFavorite: true,
    ),
    NailDesignItem(
      id: '2',
      name: 'Marshmallow',
      image: 'assets/images/image 1.png',
      style: 'Floral',
      sortDate: '2026-02-28',
      rating: 4.8,
      likesCount: 189,
    ),
    NailDesignItem(
      id: '3',
      name: 'Galaxy Magic',
      image: 'assets/images/image 2.png',
      style: 'Abstract',
      sortDate: '2026-02-25',
      rating: 5.0,
      likesCount: 312,
      isFavorite: true,
    ),
    NailDesignItem(
      id: '4',
      name: 'Ruby Minimal',
      image: 'assets/images/image 3.png',
      style: 'Minimal',
      sortDate: '2026-02-20',
      rating: 4.7,
      likesCount: 156,
    ),
    NailDesignItem(
      id: '5',
      name: 'Pink Art French',
      image: 'assets/images/image 4.png',
      style: 'French',
      sortDate: '2026-02-15',
      rating: 4.9,
      likesCount: 278,
    ),
    NailDesignItem(
      id: '6',
      name: 'Socola Floral',
      image: 'assets/images/pink 1.png',
      style: 'Floral',
      sortDate: '2026-02-10',
      rating: 4.8,
      likesCount: 142,
    ),
  ];
}
