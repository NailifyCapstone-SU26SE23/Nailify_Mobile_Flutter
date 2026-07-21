import '../../../../core/network/api_client.dart';
import '../models/component_model.dart';

class ComponentCatalogRepository {
  final ApiClient _apiClient;

  ComponentCatalogRepository(this._apiClient);

  Future<List<ComponentModel>> getComponents() async {
    final response = await _apiClient.get<dynamic>(
      '/Components',
      queryParameters: {
        'pageNumber': 1,
        'pageSize': 100,
      },
    );
    return _unwrapList(response.data).map(ComponentModel.fromJson).toList();
  }

  List<Map<String, dynamic>> _unwrapList(dynamic json) {
    if (json is Map) {
      final data = json['data'] ?? json['Data'] ?? json['items'] ?? json['Items'];
      if (data != null && data != json) return _unwrapList(data);
    }
    if (json is List) {
      return json.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
    }
    return [];
  }
}