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

    return PaginatedResponse(
      items: items,
      currentPage: metaData['currentPage'] as int,
      totalPages: metaData['totalPages'] as int,
      pageSize: metaData['pageSize'] as int,
      totalItems: metaData['totalItems'] as int,
      hasPrevious: metaData['hasPrevious'] as bool,
      hasNext: metaData['hasNext'] as bool,
      firstRowOnPage: metaData['firstRowOnPage'] as int,
      lastRowOnPage: metaData['lastRowOnPage'] as int,
    );
  }

  // Helper properties for UI - MAKE SURE THESE EXIST
  int get page => currentPage;
  bool get hasPreviousPage => hasPrevious;
  bool get hasNextPage => hasNext;
}