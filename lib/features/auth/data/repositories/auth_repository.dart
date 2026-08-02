import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/network/signalr_service.dart';
import '../../../../core/utils/api_response_parser.dart';
import '../models/user_profile.dart';

class AuthRepository {
  final ApiClient _apiClient;
  final SignalRService _signalR;

  AuthRepository(this._apiClient, this._signalR);

  Future<void> login({required String email, required String password}) async {
    final response = await _apiClient.post<dynamic>(
      '/Auth/login',
      data: {'email': email, 'password': password},
    );

    _handleAuthTokenResponse(response.data);
  }

  Future<void> loginWithGoogle({required String idToken}) async {
    final response = await _apiClient.post<dynamic>(
      '/Auth/google',
      data: {'idToken': idToken},
    );

    _handleAuthTokenResponse(response.data);
  }

  void _handleAuthTokenResponse(dynamic responseData) {
    final data = ApiResponseParser.unwrapMap(responseData);
    final tokenContainer = data['data'] ?? data['Data'];
    final tokenData = tokenContainer is Map
        ? Map<String, dynamic>.from(tokenContainer)
        : data;
    final token = (tokenData['token'] ?? tokenData['Token'])?.toString();

    if (token == null || token.isEmpty) {
      throw const FormatException('Login response does not include a token.');
    }

    // Set token in ApiClient for future requests
    _apiClient.setAuthToken(token);

    // Kết nối SignalR Hub ngay sau khi đăng nhập thành công
    _signalR.connect(token).catchError((e) {
      // Không crash app nếu SignalR lỗi, chỉ log
      debugPrint('[Auth] Không thể kết nối SignalR: $e');
    });
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

  Future<void> forgotPassword({required String email}) async {
    await _postBooleanResult('/Auth/forgot-password', data: {'email': email});
  }

  Future<void> checkResetToken({required String token}) async {
    await _postBooleanResult('/Auth/check-reset-token', data: {'token': token});
  }

  Future<void> resetPassword({
    required String token,
    required String newPassword,
    required String confirmPassword,
  }) async {
    await _postBooleanResult(
      '/Auth/reset-password',
      data: {
        'token': token,
        'newPassword': newPassword,
        'confirmPassword': confirmPassword,
      },
    );
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
        MapEntry('image', await MultipartFile.fromFile(imagePath)),
      );
    }

    final response = await _apiClient.put<dynamic>(
      '/Profile',
      data: formData,
      options: Options(contentType: 'multipart/form-data'),
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

  void logout() {
    // Ngắt kết nối SignalR trước khi xóa token
    _signalR.disconnect();
    _apiClient.removeAuthToken();
  }

  // Private helper methods (or use ApiResponseParser)
  Map<String, dynamic> _unwrapData(dynamic json) {
    final map = ApiResponseParser.unwrapMap(json);
    final data = map['data'] ?? map['Data'];
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return map;
  }

  Future<void> _postBooleanResult(
    String path, {
    required Map<String, dynamic> data,
  }) async {
    final response = await _apiClient.post<dynamic>(path, data: data);
    final map = ApiResponseParser.unwrapMap(response.data);

    if (map['isSucceeded'] == false || map['data'] == false) {
      throw Exception(map['message']?.toString() ?? 'Request failed');
    }
  }
}
