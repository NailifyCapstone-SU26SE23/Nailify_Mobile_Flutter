import 'package:equatable/equatable.dart';

import '../../../../core/utils/paginated_response.dart';
import '../datasources/nail_api_service.dart';
import '../models/category_type_model.dart';
import '../models/component_model.dart';
import '../models/customer_nail_models.dart';
import '../models/nail_design_model.dart';
import '../models/nail_shape_model.dart';
import '../models/nail_surface_model.dart';
import '../models/nail_variant_model.dart';

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

  Future<List<ComponentModel>> getComponents() => _apiService.getComponents();

  Future<PaginatedResponse<CustomerNailModel>> getCustomerNails({
    required int page,
    int pageSize = 10,
    String? name,
    bool? isPublic,
    bool? isFavorite,
  }) {
    return _apiService.getCustomerNails(
      page: page,
      pageSize: pageSize,
      name: name,
      isPublic: isPublic,
      isFavorite: isFavorite,
    );
  }

  Future<CustomerNailModel> getCustomerNailById(int id) => _apiService.getCustomerNailById(id);

  Future<int> createCustomerNail({
    required String name,
    bool isFavorite = false,
    bool isPublic = false,
    String? imagePath,
  }) {
    return _apiService.createCustomerNail(
      name: name,
      isFavorite: isFavorite,
      isPublic: isPublic,
      imagePath: imagePath,
    );
  }

  Future<CustomerNailModel> updateCustomerNail({
    required int customerNailId,
    required String name,
    int? nailShapeId,      // Keep as nullable
    int? nailSurfaceId,    // Keep as nullable
    String? customColor,   // Keep as nullable
    int? duration,         // Keep as nullable
    bool isFavorite = false,
    bool isPublic = false,
    String? imagePath,
  }) {
    return _apiService.updateCustomerNail(
      customerNailId: customerNailId,
      name: name,
      nailShapeId: nailShapeId,
      nailSurfaceId: nailSurfaceId,
      customColor: customColor,
      duration: duration,
      isFavorite: isFavorite,
      isPublic: isPublic,
      imagePath: imagePath,
    );
  }

  Future<void> deleteCustomerNail(int id) => _apiService.deleteCustomerNail(id);

  Future<PaginatedResponse<CustomerNailComponentModel>> getCustomerNailComponents({
    required int page,
    int pageSize = 50,
    int? customerNailId,
  }) {
    return _apiService.getCustomerNailComponents(
      page: page,
      pageSize: pageSize,
      customerNailId: customerNailId,
    );
  }

  Future<void> createCustomerNailComponent({
    required int customerNailId,
    int? componentId,
    int? customerComponentId,
    required double posX,
    required double posY,
    required int fingerIndex,
    required String configJson,
  }) {
    return _apiService.createCustomerNailComponent(
      customerNailId: customerNailId,
      componentId: componentId,
      customerComponentId: customerComponentId,
      posX: posX,
      posY: posY,
      fingerIndex: fingerIndex,
      configJson: configJson,
    );
  }

  Future<void> updateCustomerNailComponent({
    required int customerNailComponentId,
    required int customerNailId,
    int? componentId,
    int? customerComponentId,
    required double posX,
    required double posY,
    required int fingerIndex,
    required String configJson,
  }) {
    return _apiService.updateCustomerNailComponent(
      customerNailComponentId: customerNailComponentId,
      customerNailId: customerNailId,
      componentId: componentId,
      customerComponentId: customerComponentId,
      posX: posX,
      posY: posY,
      fingerIndex: fingerIndex,
      configJson: configJson,
    );
  }

  Future<void> deleteCustomerNailComponent(int id) => _apiService.deleteCustomerNailComponent(id);

  Future<PaginatedResponse<CustomerComponentModel>> getCustomerComponents({
    required int page,
    int pageSize = 10,
    String? name,
    int? componentType,
  }) {
    return _apiService.getCustomerComponents(
      page: page,
      pageSize: pageSize,
      name: name,
      componentType: componentType,
    );
  }

  Future<void> createCustomerComponent({
    required String name,
    required int componentType,
    double? price,
    String? customDataJson,
    bool isPublic = false,
    String? imagePath,
  }) {
    return _apiService.createCustomerComponent(
      name: name,
      componentType: componentType,
      price: price,
      customDataJson: customDataJson,
      isPublic: isPublic,
      imagePath: imagePath,
    );
  }

  Future<void> updateCustomerComponent({
    required int customerComponentId,
    required String name,
    required int componentType,
    double? price,
    String customDataJson = '',
    bool isPublic = false,
    String? imagePath,
  }) {
    return _apiService.updateCustomerComponent(
      customerComponentId: customerComponentId,
      name: name,
      componentType: componentType,
      price: price,
      customDataJson: customDataJson,
      isPublic: isPublic,
      imagePath: imagePath,
    );
  }

  Future<void> deleteCustomerComponent(int id) => _apiService.deleteCustomerComponent(id);
}
