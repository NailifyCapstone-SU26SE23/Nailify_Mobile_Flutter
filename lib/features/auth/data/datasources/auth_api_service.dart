import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';
import '../models/user_profile.dart';

class AuthApiService {
  final ApiClient _apiClient;

  AuthApiService(this._apiClient);

  Future<String> login({
    required String email,
    required String password,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/Auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );
    final data = _unwrapMap(response.data);
    final tokenContainer = data['data'] ?? data['Data'];
    final tokenData = tokenContainer is Map
        ? Map<String, dynamic>.from(tokenContainer)
        : data;
    final token = (tokenData['token'] ?? tokenData['Token'])?.toString();
    if (token == null || token.isEmpty) {
      throw const FormatException('Login response does not include a token.');
    }
    return token;
  }

  Future<UserProfile> register({
    required String email,
    required String password,
    required String confirmPassword,
    required String firstName,
    required String lastName,
    required String phone,
  }) async {
    final response = await _apiClient.post<dynamic>(
      '/Auth/register',
      data: {
        'email': email,
        'password': password,
        'confirmPassword': confirmPassword,
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
      },
    );
    return UserProfile.fromJson(_unwrapData(response.data));
  }

  Future<UserProfile> getCurrentUser() async {
    final response = await _apiClient.get<dynamic>('/Profile');
    return UserProfile.fromJson(_unwrapData(response.data));
  }

  Future<UserProfile> getCustomerProfile() async {
    final response = await _apiClient.get<dynamic>('/Profile/customers');
    return UserProfile.fromJson(_unwrapData(response.data));
  }

  Future<UserProfile> updateProfile({
    required String email,
    required String firstName,
    required String lastName,
    required String phone,
    String? imagePath,
  }) async {
    final formData = FormData.fromMap({
      'Email': email,
      'FirstName': firstName,
      'LastName': lastName,
      'Phone': phone,
    });
    if (imagePath != null && imagePath.isNotEmpty) {
      formData.files.add(
        MapEntry(
          'image',
          await MultipartFile.fromFile(imagePath),
        ),
      );
    }

    final response = await _apiClient.put<dynamic>(
      '/Profile',
      data: formData,
    );
    return UserProfile.fromJson(_unwrapData(response.data));
  }

  Future<void> updateCustomerPreferences({
    required String skinTone,
    required String occupation,
    required String nailCondition,
    required String personaId,
  }) async {
    await _apiClient.put<dynamic>(
      '/Profile/customers/preferences',
      data: {
        'SkinTone': skinTone,
        'Occupation': occupation,
        'NailCondition': nailCondition,
        'PersonaId': personaId,
      },
    );
  }

  Map<String, dynamic> _unwrapData(dynamic json) {
    final map = _unwrapMap(json);
    final data = map['data'] ?? map['Data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return map;
  }

  Map<String, dynamic> _unwrapMap(dynamic json) {
    if (json is Map<String, dynamic>) return json;
    if (json is Map) return Map<String, dynamic>.from(json);
    return <String, dynamic>{};
  }
}
