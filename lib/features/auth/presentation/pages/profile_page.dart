import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../generated/l10n.dart';
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
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text(
          'Đăng xuất',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: const Text('Bạn có chắc chắn muốn đăng xuất khỏi tài khoản?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              getIt<AuthRepository>().logout();
              context.go('/login');
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryDark,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Đăng xuất',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFDFBF7),
      body: SafeArea(
        child: FutureBuilder<UserProfile>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Container(
                    padding: const EdgeInsets.all(28),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: AppColors.primaryLight),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          blurRadius: 20,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: const BoxDecoration(
                            color: AppColors.primarySurface,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.lock_outline_rounded,
                            size: 40,
                            color: AppColors.primary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          S.of(context).pleaseLoginToViewProfile,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          snapshot.error.toString(),
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            OutlinedButton(
                              onPressed: _reload,
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: const Text('Thử lại'),
                            ),
                            const SizedBox(width: 12),
                            ElevatedButton(
                              onPressed: () => context.go('/login'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.primary,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                S.of(context).login,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final user = snapshot.data!;
            final hasValidAvatar = user.avatarUrl?.trim().isNotEmpty == true;
            final avatarUrl = hasValidAvatar ? user.avatarUrl!.trim() : null;

            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
              children: [
                // Page Header Title
                Row(
                  children: [
                    const Text(
                      'Tài khoản cá nhân',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: AppColors.textPrimary,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Colors.white,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'VIP MEMBER',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // User Hero Profile Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: AppColors.primaryLight,
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        blurRadius: 20,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Avatar with Outer Ring
                      Container(
                        padding: const EdgeInsets.all(3),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppColors.primaryGradient,
                        ),
                        child: CircleAvatar(
                          radius: 36,
                          backgroundColor: Colors.white,
                          backgroundImage: avatarUrl != null
                              ? NetworkImage(avatarUrl)
                              : null,
                          onBackgroundImageError: avatarUrl != null
                              ? (_, _) {
                                  debugPrint(
                                    'Failed to load avatar: $avatarUrl',
                                  );
                                }
                              : null,
                          child: avatarUrl == null
                              ? const Icon(
                                  Icons.person_rounded,
                                  size: 38,
                                  color: AppColors.primary,
                                )
                              : null,
                        ),
                      ),

                      const SizedBox(width: 16),

                      // Name & Contact details
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.fullName,
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.w800,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              user.email,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            if (user.phone != null &&
                                user.phone!.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                user.phone!,
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDark,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),

                      // Edit Profile Quick Button
                      IconButton(
                        onPressed: () => context.go('/profile/update-info'),
                        icon: const Icon(
                          Icons.edit_note_rounded,
                          color: AppColors.primary,
                          size: 26,
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // Section 1: Account Management
                const _SectionTitle(title: 'Cài đặt cá nhân'),
                const SizedBox(height: 10),
                _ProfileActionCard(
                  icon: Icons.person_outline_rounded,
                  iconBgColor: AppColors.primarySurface,
                  iconColor: AppColors.primary,
                  title: 'Cập nhật thông tin cá nhân',
                  subtitle: 'Tên, số điện thoại, email và ảnh đại diện',
                  onTap: () => context.go('/profile/update-info'),
                ),
                const SizedBox(height: 10),
                _ProfileActionCard(
                  icon: Icons.auto_awesome_outlined,
                  iconBgColor: const Color(0xFFFFF8E1),
                  iconColor: Colors.orange.shade700,
                  title: 'Cập nhật sở thích móng AI',
                  subtitle: 'Tông da, dáng móng, nghề nghiệp & persona',
                  onTap: () => context.go('/profile/update-preferences'),
                ),

                const SizedBox(height: 24),

                // Section 2: Activity & Studio
                const _SectionTitle(title: 'Hoạt động & Dịch vụ'),
                const SizedBox(height: 10),
                _ProfileActionCard(
                  icon: Icons.calendar_month_outlined,
                  iconBgColor: AppColors.primarySurface,
                  iconColor: AppColors.primaryDark,
                  title: 'Lịch sử đặt lịch',
                  subtitle: 'Xem trạng thái các lịch hẹn làm móng',
                  onTap: () => context.go('/profile/booking-history'),
                ),
                const SizedBox(height: 10),
                _ProfileActionCard(
                  icon: Icons.receipt_long_outlined,
                  iconBgColor: const Color(0xFFE8F5E9),
                  iconColor: AppColors.success,
                  title: 'Hóa đơn & Giao dịch',
                  subtitle: 'Lịch sử thanh toán và biên nhận',
                  onTap: () => context.go('/profile/transactions'),
                ),
                const SizedBox(height: 10),
                _ProfileActionCard(
                  icon: Icons.favorite_border_rounded,
                  iconBgColor: const Color(0xFFFFEBEE),
                  iconColor: Colors.pinkAccent,
                  title: 'Bộ móng yêu thích',
                  subtitle: 'Danh sách mẫu móng đã thả tim',
                  onTap: () => context.go('/profile/favorite-nails'),
                ),
                const SizedBox(height: 10),
                _ProfileActionCard(
                  icon: Icons.brush_outlined,
                  iconBgColor: const Color(0xFFEDE7F6),
                  iconColor: Colors.deepPurple,
                  title: 'Studio của tôi',
                  subtitle: 'Quản lý yêu cầu thiết kế custom',
                  onTap: () => context.go('/profile/my-studio'),
                ),

                const SizedBox(height: 32),

                // Logout Action Button
                Container(
                  height: 50,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: AppColors.error.withValues(alpha: 0.4),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.error.withValues(alpha: 0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: OutlinedButton.icon(
                    onPressed: _logout,
                    style: OutlinedButton.styleFrom(
                      side: BorderSide.none,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(
                      Icons.logout_rounded,
                      color: AppColors.error,
                      size: 20,
                    ),
                    label: const Text(
                      'Đăng xuất khỏi tài khoản',
                      style: TextStyle(
                        color: AppColors.error,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: 0.3,
      ),
    );
  }
}

class _ProfileActionCard extends StatelessWidget {
  final IconData icon;
  final Color iconBgColor;
  final Color iconColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileActionCard({
    required this.icon,
    required this.iconBgColor,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderLight.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: AppColors.textPrimary.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: iconBgColor,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: iconColor, size: 22),
        ),
        title: Text(
          title,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios_rounded,
          size: 15,
          color: AppColors.borderLight,
        ),
      ),
    );
  }
}
