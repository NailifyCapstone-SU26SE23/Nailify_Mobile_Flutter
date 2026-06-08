import '../../../../core/network/api_client.dart';
import '../datasources/auth_api_service.dart';
import '../models/user_profile.dart';

class AuthRepository {
  final AuthApiService _apiService;
  final ApiClient _apiClient;

  AuthRepository(this._apiService, this._apiClient);

  Future<void> login({
    required String email,
    required String password,
  }) async {
    final token = await _apiService.login(email: email, password: password);
    _apiClient.setAuthToken(token);
  }

  Future<UserProfile> register({
    required String email,
    required String password,
    required String confirmPassword,
    required String firstName,
    required String lastName,
    required String phone,
  }) {
    return _apiService.register(
      email: email,
      password: password,
      confirmPassword: confirmPassword,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
    );
  }

  Future<UserProfile> getCurrentUser() => _apiService.getCurrentUser();

  Future<UserProfile> getCustomerProfile() => _apiService.getCustomerProfile();

  Future<UserProfile> updateProfile({
    required String email,
    required String firstName,
    required String lastName,
    required String phone,
    String? imagePath,
  }) {
    return _apiService.updateProfile(
      email: email,
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      imagePath: imagePath,
    );
  }

  Future<void> updateCustomerPreferences({
    required String skinTone,
    required String occupation,
    required String nailCondition,
    required String personaId,
  }) {
    return _apiService.updateCustomerPreferences(
      skinTone: skinTone,
      occupation: occupation,
      nailCondition: nailCondition,
      personaId: personaId,
    );
  }

  void logout() => _apiClient.removeAuthToken();
}
