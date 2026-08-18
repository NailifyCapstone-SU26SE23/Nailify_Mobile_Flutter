class AppConstants {
  static const String appName = 'Mo Nailify Project';
  static const String baseUrl = 'http://10.0.2.2:5004';
  // Android emulator -> host HTTP backend
  // static const String baseUrl = 'https://nailify.onrender.com';
  static const String apiVersion = '/api';
  static const String authTokenKey = 'auth_token';
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);
}
