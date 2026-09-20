import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

class CashWalletCard extends StatelessWidget {
  final double balance;
  final double frozenBalance;
  final int loyaltyPoints;
  final String? loyaltyTierName;
  final VoidCallback onDepositPressed;
  final VoidCallback onWithdrawPressed;
  final VoidCallback onConvertPressed;
  final VoidCallback onHistoryPressed;

  const CashWalletCard({
    super.key,
    required this.balance,
    required this.frozenBalance,
    required this.loyaltyPoints,
    this.loyaltyTierName,
    required this.onDepositPressed,
    required this.onWithdrawPressed,
    required this.onConvertPressed,
    required this.onHistoryPressed,
  });

  String _formatVnd(double amount) {
    final formatter = NumberFormat.currency(locale: 'vi_VN', symbol: 'đ');
    return formatter.format(amount);
  }

  @override
  Widget build(BuildContext context) {
    final availableBalance = balance - frozenBalance;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF1E1E2C),
            Color(0xFF2D2B42),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Subtle background decoration circle
          Positioned(
            right: -30,
            top: -30,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: 0.12),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Title & Tier Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.account_balance_wallet_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        const Text(
                          'Ví tiền mặt Nailify',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
                    if (loyaltyTierName != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                          ),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          loyaltyTierName!,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w900,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 18),

                // Main Cash Balance
                const Text(
                  'Số dư khả dụng',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatVnd(availableBalance > 0 ? availableBalance : 0),
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),

                if (frozenBalance > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(
                        Icons.lock_clock_rounded,
                        size: 13,
                        color: Colors.amberAccent,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Đang rút (đóng băng): ${_formatVnd(frozenBalance)}',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: Colors.amberAccent,
                        ),
                      ),
                    ],
                  ),
                ],

                const SizedBox(height: 14),
                const Divider(color: Colors.white12, height: 1),
                const SizedBox(height: 14),

                // Loyalty Points display
                Row(
                  children: [
                    const Icon(
                      Icons.stars_rounded,
                      size: 16,
                      color: Color(0xFFFFD700),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Điểm thưởng tích lũy: ',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white.withValues(alpha: 0.7),
                      ),
                    ),
                    Text(
                      '$loyaltyPoints điểm',
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFFFFD700),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Quick Action Bar (4 Buttons)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildActionButton(
                      icon: Icons.add_card_rounded,
                      label: 'Nạp tiền',
                      color: const Color(0xFF4CAF50),
                      onTap: onDepositPressed,
                    ),
                    _buildActionButton(
                      icon: Icons.outbox_rounded,
                      label: 'Rút tiền',
                      color: const Color(0xFFFF9800),
                      onTap: onWithdrawPressed,
                    ),
                    _buildActionButton(
                      icon: Icons.published_with_changes_rounded,
                      label: 'Đổi điểm',
                      color: AppColors.primary,
                      onTap: onConvertPressed,
                    ),
                    _buildActionButton(
                      icon: Icons.receipt_long_rounded,
                      label: 'Lịch sử',
                      color: const Color(0xFF64B5F6),
                      onTap: onHistoryPressed,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.12),
              ),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}
