// lib/features/auth/data/models/user_mock_data.dart

class UserMockData {
  // Tài khoản dùng để kiểm thử đăng nhập
  static const String testEmail = 'khachhang@nailify.com';
  static const String testPassword = 'password123';

  static final Map<String, dynamic> mockCustomer = {
    'id': 'CUST_001',
    'fullName': 'Amanda',
    'email': testEmail,
    'avatar': 'assets/images/Ellipse 1.png',
    'token': 'mock_jwt_token_123456789',
  };
}