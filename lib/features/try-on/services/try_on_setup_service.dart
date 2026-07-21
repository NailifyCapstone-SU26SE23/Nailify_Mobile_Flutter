// lib/features/try_on/services/try_on_setup_service.dart
import '../../../core/utils/paginated_response.dart';
import '../../nails/data/models/component_model.dart';
import '../../nails/data/models/customer_nail_models.dart';
import '../../nails/data/models/nail_shape_model.dart';
import '../../nails/data/models/nail_surface_model.dart';
import '../models/try_on_data.dart';
import '../../nails/data/repositories/nail_variant_repository.dart';
import '../../nails/data/repositories/component_catalog_repository.dart';
import '../../nails/data/repositories/customer_component_repository.dart';

class TryOnSetupService {
  final NailVariantRepository _nailVariantRepo;
  final ComponentCatalogRepository _componentRepo;
  final CustomerComponentRepository _customerComponentRepo;

  TryOnSetupService({
    required NailVariantRepository nailVariantRepo,
    required ComponentCatalogRepository componentRepo,
    required CustomerComponentRepository customerComponentRepo,
  }) : _nailVariantRepo = nailVariantRepo,
        _componentRepo = componentRepo,
        _customerComponentRepo = customerComponentRepo;

  Future<TryOnData> fetchTryOnData() async {
    // Fetch all data in parallel for performance
    final results = await Future.wait([
      _nailVariantRepo.getNailShapes(),  // Now using NailVariantRepository
      _nailVariantRepo.getNailSurfaces(),
      _componentRepo.getComponents(),
      _customerComponentRepo.getCustomerComponents(
        page: 1,
        pageSize: 100, // Fetch all customer components
      ),
    ]);

    return TryOnData(
      nailShapes: results[0] as List<NailShapeModel>,
      nailSurfaces: results[1] as List<NailSurfaceModel>,
      components: results[2] as List<ComponentModel>,
      customerComponents: (results[3] as PaginatedResponse<CustomerComponentModel>).items,
    );
  }
}
