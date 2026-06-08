import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:get_it/get_it.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../network/api_client.dart';
import '../network/network_info.dart';
import '../../features/nails/data/datasources/nail_api_service.dart';
import '../../features/nails/data/repositories/nail_repository.dart';
import '../../features/nails/services/ar_try_on_service.dart';
import '../../features/auth/data/datasources/auth_api_service.dart';
import '../../features/auth/data/repositories/auth_repository.dart';

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

  // Đăng ký ApiClient làm Engine kết nối mạng chính toàn app
  getIt.registerLazySingleton<ApiClient>(
    () => ApiClient(preferences: getIt<SharedPreferences>()),
  );
  getIt.registerLazySingleton<NailApiService>(
    () => NailApiService(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<AuthApiService>(
    () => AuthApiService(getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<NailRepository>(
    () => NailRepository(getIt<NailApiService>()),
  );
  getIt.registerLazySingleton<AuthRepository>(
    () => AuthRepository(getIt<AuthApiService>(), getIt<ApiClient>()),
  );
  getIt.registerLazySingleton<ArTryOnService>(ArTryOnService.new);
}
