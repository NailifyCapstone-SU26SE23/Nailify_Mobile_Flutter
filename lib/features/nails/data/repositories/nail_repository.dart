import 'package:equatable/equatable.dart';

import '../datasources/nail_api_service.dart';
import '../models/category_type_model.dart';
import '../models/nail_design_model.dart';
import '../models/nail_shape_model.dart';
import '../models/nail_surface_model.dart';
import '../models/nail_variant_model.dart';
import '../models/paginated_response.dart';

class NailFilters extends Equatable {
  final String? name;
  final List<int> categoryIds;
  final int? shapeId;
  final int? surfaceId;
  final double? minPrice;
  final double? maxPrice;

  const NailFilters({
    this.name,
    this.categoryIds = const [],
    this.shapeId,
    this.surfaceId,
    this.minPrice,
    this.maxPrice,
  });

  bool get isEmpty =>
      (name == null || name!.trim().isEmpty) &&
      categoryIds.isEmpty &&
      shapeId == null &&
      surfaceId == null &&
      minPrice == null &&
      maxPrice == null;

  @override
  List<Object?> get props => [name, categoryIds, shapeId, surfaceId, minPrice, maxPrice];
}

class NailRepository {
  final NailApiService _apiService;

  NailRepository(this._apiService);

  Future<PaginatedResponse<NailDesignModel>> getNailDesigns({
    required int page,
    int pageSize = 10,
    NailFilters filters = const NailFilters(),
  }) {
    return _apiService.getNailDesigns(
      page: page,
      pageSize: pageSize,
      name: filters.name,
      categoryIds: filters.categoryIds,
    );
  }

  Future<NailDesignModel> getNailDesignById(int id) => _apiService.getNailDesignById(id);

  Future<List<CategoryTypeModel>> getCategoryTypes() => _apiService.getCategoryTypes();

  Future<PaginatedResponse<NailVariantModel>> getNailVariants({
    required int page,
    int pageSize = 10,
    NailFilters filters = const NailFilters(),
  }) {
    return _apiService.getNailVariants(
      page: page,
      pageSize: pageSize,
      shapeId: filters.shapeId,
      surfaceId: filters.surfaceId,
      minPrice: filters.minPrice,
      maxPrice: filters.maxPrice,
    );
  }

  Future<NailVariantModel> getNailVariantById(int id) => _apiService.getNailVariantById(id);

  Future<List<NailShapeModel>> getNailShapes() => _apiService.getNailShapes();

  Future<List<NailSurfaceModel>> getNailSurfaces() => _apiService.getNailSurfaces();
}
