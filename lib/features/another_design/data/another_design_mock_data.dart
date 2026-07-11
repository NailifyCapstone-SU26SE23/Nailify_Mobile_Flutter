class NailDesignItem {
  final String id;
  final String name;
  final String image;
  final String style;
  final String sortDate;

  const NailDesignItem({
    required this.id,
    required this.name,
    required this.image,
    required this.style,
    required this.sortDate,
  });

  Map<String, dynamic> toNailData() => {
    'id': id,
    'name': name,
    'image': image,
    'tags': [style],
  };
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
    ),
    NailDesignItem(
      id: '2',
      name: 'Marshmallow',
      image: 'assets/images/image 1.png',
      style: 'Floral',
      sortDate: '2026-02-28',
    ),
    NailDesignItem(
      id: '3',
      name: 'Galaxy',
      image: 'assets/images/image 2.png',
      style: 'Abstract',
      sortDate: '2026-02-25',
    ),
    NailDesignItem(
      id: '4',
      name: 'Ruby',
      image: 'assets/images/image 3.png',
      style: 'Minimal',
      sortDate: '2026-02-20',
    ),
    NailDesignItem(
      id: '5',
      name: 'Pink Art',
      image: 'assets/images/image 4.png',
      style: 'French',
      sortDate: '2026-02-15',
    ),
    NailDesignItem(
      id: '6',
      name: 'Socola',
      image: 'assets/images/pink 1.png',
      style: 'Floral',
      sortDate: '2026-02-10',
    ),
  ];
}
