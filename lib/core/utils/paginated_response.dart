class PaginatedResponse<T> {
  final List<T> items;
  final int currentPage;
  final int totalPages;
  final int pageSize;
  final int totalItems;
  final bool hasPrevious;
  final bool hasNext;
  final int firstRowOnPage;
  final int lastRowOnPage;

  PaginatedResponse({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.pageSize,
    required this.totalItems,
    required this.hasPrevious,
    required this.hasNext,
    required this.firstRowOnPage,
    required this.lastRowOnPage,
  });

  factory PaginatedResponse.fromJson(
    Map<String, dynamic> json,
    T Function(dynamic) fromJsonItem,
  ) {
    final data = json['data'] as Map<String, dynamic>;
    final items = (data['items'] as List)
        .map((item) => fromJsonItem(item))
        .toList();
    final metaData = data['metaData'] as Map<String, dynamic>;

    int readInt(String key, int fallback) {
      final raw = metaData[key];
      if (raw is int) return raw;
      if (raw is num) return raw.toInt();
      if (raw is String) return int.tryParse(raw) ?? fallback;
      return fallback;
    }

    bool readBool(String key, bool fallback) {
      final raw = metaData[key];
      if (raw is bool) return raw;
      if (raw is String) {
        final lower = raw.toLowerCase();
        if (lower == 'true') return true;
        if (lower == 'false') return false;
      }
      return fallback;
    }

    return PaginatedResponse(
      items: items,
      currentPage: readInt('currentPage', 1),
      totalPages: readInt('totalPages', 1),
      pageSize: readInt('pageSize', items.length),
      totalItems: readInt('totalItems', items.length),
      hasPrevious: readBool('hasPrevious', false),
      hasNext: readBool('hasNext', false),
      firstRowOnPage: readInt('firstRowOnPage', 1),
      lastRowOnPage: readInt('lastRowOnPage', items.length),
    );
  }

  // Helper properties for UI - MAKE SURE THESE EXIST
  int get page => currentPage;
  bool get hasPreviousPage => hasPrevious;
  bool get hasNextPage => hasNext;
}
