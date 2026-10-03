class ApiResponseParser {
  static Map<String, dynamic> unwrapMap(dynamic json) {
    if (json is Map<String, dynamic>) {
      final data = json['data'] ?? json['Data'];
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return json;
    }
    if (json is Map) return Map<String, dynamic>.from(json);
    return <String, dynamic>{};
  }

  static List<Map<String, dynamic>> unwrapList(dynamic json) {
    if (json is Map) {
      final data =
          json['data'] ?? json['Data'] ?? json['items'] ?? json['Items'];
      if (data != null && data != json) return unwrapList(data);
    }
    if (json is List) {
      return json
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    }
    return [];
  }

  static int asInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
