import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../data/models/user_profile.dart';
import '../../data/repositories/auth_repository.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  late Future<UserProfile> _future;

  @override
  void initState() {
    super.initState();
    _future = getIt<AuthRepository>().getCurrentUser();
  }

  void _reload() {
    setState(() {
      _future = getIt<AuthRepository>().getCurrentUser();
    });
  }

  void _logout() {
    getIt<AuthRepository>().logout();
    context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Vui lòng đăng nhập để xem tài khoản',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 20),
                  Wrap(
                    spacing: 12,
                    children: [
                      OutlinedButton(
                        onPressed: _reload,
                        child: const Text('Thử lại'),
                      ),
                      ElevatedButton(
                        onPressed: () => context.go('/login'),
                        child: const Text('Đăng nhập'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }

        final user = snapshot.data!;
        final hasValidAvatar = user.avatarUrl?.trim().isNotEmpty == true;
        final avatarUrl = hasValidAvatar ? user.avatarUrl!.trim() : null;

        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // Avatar section
            Center(
              child: CircleAvatar(
                radius: 60,
                backgroundColor: AppColors.primary,
                backgroundImage: avatarUrl != null
                    ? NetworkImage(avatarUrl)
                    : null,
                onBackgroundImageError: avatarUrl != null
                    ? (_, _) {
                  // Log error silently or show debug message only in development
                  debugPrint('Failed to load avatar: $avatarUrl');
                }
                    : null,
                child: avatarUrl == null
                    ? const Icon(Icons.person, size: 60, color: AppColors.primary)
                    : null,
              ),
            ),
            const SizedBox(height: 24),

            Center(
              child: Column(
                children: [
                  Text(
                    user.fullName,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Action tiles
            ProfileActionTile(
              title: 'Cập nhật thông tin',
              route: '/profile/update-info',
            ),
            ProfileActionTile(
              title: 'Cập nhật sở thích',
              route: '/profile/update-preferences',
            ),
            ProfileActionTile(
              title: 'Lịch sử đặt lịch',
              route: '/profile/booking-history',
            ),
            ProfileActionTile(title: 'Hóa đơn', route: '/profile/invoices'),
            ProfileActionTile(
              title: 'Bộ móng yêu thích',
              route: '/profile/favorite-nails',
            ),
            ProfileActionTile(
              title: 'Studio của tôi',
              route: '/profile/my-studio',
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Đăng xuất'),
            ),
          ],
        );
      },
    );
  }
}

class ProfileInfoTile extends StatelessWidget {
  final String label;
  final String value;

  const ProfileInfoTile({
    super.key,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(value),
    );
  }
}

class ProfileActionTile extends StatelessWidget {
  final String title;
  final String route;

  const ProfileActionTile({
    super.key,
    required this.title,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => context.go(route),
    );
  }
}
