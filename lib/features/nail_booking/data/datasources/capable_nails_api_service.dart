import 'package:flutter/material.dart';

import '../../../nails/data/models/nail_variant_model.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/api_client.dart';

/// API service gọi endpoint lấy danh sách mẫu nail mà thợ có thể thực hiện.
///
/// Endpoint: GET /api/NailVariants/capable-by-artist/{artistId}
/// Trả về ApiResult chứa danh sách NailVariantDto trong `data`.
class CapableNailsApiService {
  final ApiClient _apiClient = getIt<ApiClient>();

  /// Lấy danh sách nail variant mà [artistId] có thể thực hiện.
  /// Throws nếu response không thành công.
  Future<List<NailVariantModel>> getCapableNailsByArtist(
    String artistId,
  ) async {
    if (artistId.isEmpty) return [];
    final response = await _apiClient.get<dynamic>(
      '/NailVariants/capable-by-artist/$artistId',
    );
    final body = response.data;
    if (body is! Map) return const [];
    final data = body['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((item) {
          try {
            return NailVariantModel.fromJson(Map<String, dynamic>.from(item));
          } catch (e) {
            debugPrint('CapableNailsApiService parse error: $e');
            return null;
          }
        })
        .whereType<NailVariantModel>()
        .toList();
  }
}
