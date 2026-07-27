import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../features/try-on/services/try_on_setup_service.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../../features/nails/data/repositories/nail_design_repository.dart';
import '../../features/nails/data/repositories/nail_variant_repository.dart';
import '../../features/nails/data/repositories/customer_nail_repository.dart';
import '../../features/nails/data/repositories/customer_component_repository.dart';
import '../../features/nails/data/repositories/nail_component_repository.dart';
import '../../features/nails/data/repositories/component_catalog_repository.dart';
import '../../features/nails/services/ar_try_on_service.dart';
import '../../features/auth/data/repositories/auth_repository.dart';
import '../network/signalr_service.dart';

final GetIt getIt = GetIt.instance;

Future<void> configureDependencies() async {
  // 1. External Dependencies
  final sharedPreferences = await SharedPreferences.getInstance();
  getIt.registerLazySingleton<SharedPreferences>(() => sharedPreferences);
  getIt.registerLazySingleton<Connectivity>(() => Connectivity());

  // 2. Core Sub-systems
  getIt.registerLazySingleton<NetworkInfo>(
    () => NetworkInfoImpl(getIt<Connectivity>()),
  );

  // 3. API Client (the only network layer!)
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(preferences: getIt<SharedPreferences>()),
  );

  // 3b. SignalR Service (Real-time notifications)
  getIt.registerLazySingleton<SignalRService>(() => SignalRService());

  // 4. Repositories (directly using ApiClient)
  // Auth
  getIt.registerLazySingleton<AuthRepository>(
        () => AuthRepository(getIt<ApiClient>(), getIt<SignalRService>()),
  );

  // Nail repositories
  getIt.registerLazySingleton<NailDesignRepository>(
    () => NailDesignRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<NailVariantRepository>(
    () => NailVariantRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<CustomerNailRepository>(
    () => CustomerNailRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<CustomerComponentRepository>(
    () => CustomerComponentRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<NailComponentRepository>(
    () => NailComponentRepository(getIt<ApiClient>()),
  );

  getIt.registerLazySingleton<ComponentCatalogRepository>(
    () => ComponentCatalogRepository(getIt<ApiClient>()),
  );

  // 5. Services
  getIt.registerLazySingleton<ArTryOnService>(ArTryOnService.new);

  getIt.registerLazySingleton<TryOnSetupService>(
    () => TryOnSetupService(
      nailVariantRepo: getIt<NailVariantRepository>(),
      componentRepo: getIt<ComponentCatalogRepository>(),
      customerComponentRepo: getIt<CustomerComponentRepository>(),
    ),
  );
}
