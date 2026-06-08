class PaginatedResponse<T> {
  final List<T> items;
  final int page;
  final int pageSize;
  final int totalCount;
  final bool hasNextPage;

  const PaginatedResponse({
    required this.items,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.hasNextPage,
  });

  factory PaginatedResponse.fromJson(
    dynamic json,
    T Function(Map<String, dynamic>) itemBuilder, {
    int fallbackPage = 1,
    int fallbackPageSize = 10,
  }) {
    if (json is List) {
      final items = _parseItems(json, itemBuilder);
      return PaginatedResponse(
        items: items,
        page: fallbackPage,
        pageSize: fallbackPageSize,
        totalCount: items.length,
        hasNextPage: items.length >= fallbackPageSize,
      );
    }

    final map = json is Map<String, dynamic>
        ? json
        : json is Map
            ? Map<String, dynamic>.from(json)
            : <String, dynamic>{};
    final data = map['data'] ?? map['Data'] ?? map;
    final dataMap = data is Map<String, dynamic>
        ? data
        : data is Map
            ? Map<String, dynamic>.from(data)
            : <String, dynamic>{};
    final rawItems = dataMap['items'] ??
        dataMap['Items'] ??
        dataMap['results'] ??
        dataMap['Results'] ??
        dataMap['data'] ??
        dataMap['Data'] ??
        data;
    final items = rawItems is List ? _parseItems(rawItems, itemBuilder) : <T>[];
    final metaData = dataMap['metaData'] ?? dataMap['MetaData'];
    final metaMap = metaData is Map<String, dynamic>
        ? metaData
        : metaData is Map
            ? Map<String, dynamic>.from(metaData)
            : <String, dynamic>{};
    final page = _asInt(
      dataMap['page'] ??
          dataMap['Page'] ??
          dataMap['pageNumber'] ??
          dataMap['PageNumber'] ??
          metaMap['currentPage'] ??
          metaMap['CurrentPage'],
      fallbackPage,
    );
    final pageSize = _asInt(
      dataMap['pageSize'] ?? dataMap['PageSize'] ?? metaMap['pageSize'] ?? metaMap['PageSize'],
      fallbackPageSize,
    );
    final totalCount = _asInt(
      dataMap['totalCount'] ??
          dataMap['TotalCount'] ??
          dataMap['totalItems'] ??
          dataMap['TotalItems'] ??
          metaMap['totalItems'] ??
          metaMap['TotalItems'],
      items.length,
    );
    final explicitHasNext = dataMap['hasNextPage'] ?? dataMap['HasNextPage'] ?? metaMap['hasNext'] ?? metaMap['HasNext'];
    return PaginatedResponse(
      items: items,
      page: page,
      pageSize: pageSize,
      totalCount: totalCount,
      hasNextPage: explicitHasNext is bool ? explicitHasNext : page * pageSize < totalCount || items.length >= pageSize,
    );
  }

  static List<T> _parseItems<T>(List list, T Function(Map<String, dynamic>) itemBuilder) {
    return list.whereType<Map>().map((item) => itemBuilder(Map<String, dynamic>.from(item))).toList();
  }

  static int _asInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
