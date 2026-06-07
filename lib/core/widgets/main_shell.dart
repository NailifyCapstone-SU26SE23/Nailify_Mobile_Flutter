// lib/core/widgets/main_shell.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class MainShell extends StatefulWidget {
  final Widget child;
  const MainShell({super.key, required this.child});

  @override
  State<MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<MainShell> {
  // 1. Hàm tính toán vị trí Tab hiện tại dựa trên tuyến đường của GoRouter
  // Đưa hàm này vào trong State Class để tránh lỗi Compiler
  int _calculateCurrentIndex(BuildContext context) {
    final String location = GoRouterState.of(context).matchedLocation;
    if (location.startsWith('/appointments')) return 1;
    if (location.startsWith('/chatbot')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0; // Mặc định là trang chủ '/'
  }

  // 2. Xử lý điều hướng: Chỉ '/' hoạt động, các tính năng khác hiển thị thông báo
  void _onTabTapped(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/'); // Chỉ chuyển trang đối với HomePage
        break;
      case 1:
        _showPopupNotification(context, 'Lịch hẹn');
        break;
      case 2:
        _showPopupNotification(context, 'Chatbot');
        break;
      case 3:
        _showPopupNotification(context, 'Tài khoản');
        break;
    }
  }

  // 3. Cửa sổ thông báo bảo trì phân hệ chưa có Page
  void _showPopupNotification(BuildContext context, String actionName) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.construction, color: Colors.amber),
            SizedBox(width: 8),
            Text('Thông báo'),
          ],
        ),
        content: Text('Tính năng "$actionName" đang được xử lý. Trang mục tiêu hiện tại chưa được khởi tạo.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Đóng', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      // 1. HEADER DÙNG CHUNG
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        toolbarHeight: 80,
        // -- Logo góc trái --
        title: GestureDetector(
          onTap: () {
            context.go('/');
          },
          child: Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Image.asset(
              'assets/images/pink.png',
              height: 40,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Text(
                'Nailify',
                style: TextStyle(
                  color: Color(0xFFFF66C4),
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ),
        // -- Nút Sign in & Register --
        actions: [
          OutlinedButton(
            onPressed: () => context.push('/login'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Color(0xFFFF66C4), width: 1.2),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            ),
            child: const Text(
              'Sign in',
              style: TextStyle(
                color: Color(0xFFFF66C4),
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => context.push('/register'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF66C4),
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
            ),
            child: const Text(
              'Register',
              style: TextStyle(
                fontWeight: FontWeight.w500,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 16),
        ],
      ),

      // PHẦN THÂN (FRAGMENT)
      body: widget.child,

      // FOOTER DÙNG CHUNG
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _calculateCurrentIndex(context),
        onTap: (index) => _onTabTapped(context, index), // SỬA LỖI: Truyền chính xác context của widget vào hàm điều hướng
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.pinkAccent,
        unselectedItemColor: Colors.grey,
        backgroundColor: Colors.white,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Trang chủ'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_month), label: 'Lịch hẹn'),
          BottomNavigationBarItem(icon: Icon(Icons.chat_bubble_outline), label: 'Chatbot'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Tài khoản'),
        ],
      ),
    );
  }
}