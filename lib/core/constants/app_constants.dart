class AppConstants {
  static const String appName = 'Mo Nailify Project';
  // static const String baseUrl = 'http://10.0.2.2:5004';
  // Android emulator -> host HTTP backend
  static const String baseUrl = 'https://nailify-be.onrender.com/';

  static const String apiVersion = '/api';
  static const String authTokenKey = 'auth_token';
  static const Duration connectTimeout = Duration(seconds: 60);
  static const Duration receiveTimeout = Duration(seconds: 60);

  // Roboflow Cloud - Segmentation Model (viền móng)
  // Model: kiet-vo-fl2sp/nail-segmentation-vic7o-3t7il-1-yolo26n-seg-t1
  // Workspace: kiet-vo-fl2sp
  static const String roboflowApiKey = '<Publishable API Key>';
  static const String roboflowSegModelId = 'kiet-vo-fl2sp/nail-segmentation-vic7o-3t7il-1-yolo26n-seg-t1';
  static const int roboflowSegVersion = 3;
  static const Duration roboflowTimeout = Duration(seconds: 15);
}
