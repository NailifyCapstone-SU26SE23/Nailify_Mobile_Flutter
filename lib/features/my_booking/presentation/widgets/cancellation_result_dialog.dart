import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

/// Reusable Custom Dialog to display cancellation result (Success / Fail)
class CancellationResultDialog extends StatelessWidget {
  final bool isSuccess;
  final String? title;
  final String message;
  final String? subMessage;
  final VoidCallback? onPressed;

  const CancellationResultDialog({
    super.key,
    required this.isSuccess,
    this.title,
    required this.message,
    this.subMessage,
    this.onPressed,
  });

  static Future<void> show({
    required BuildContext context,
    required bool isSuccess,
    String? title,
    required String message,
    String? subMessage,
    VoidCallback? onPressed,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => CancellationResultDialog(
        isSuccess: isSuccess,
        title: title,
        message: message,
        subMessage: subMessage,
        onPressed: onPressed,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final defaultTitle =
        isSuccess ? 'Hủy đặt lịch thành công' : 'Hủy đặt lịch thất bại';
    final iconColor =
        isSuccess ? const Color(0xFF10B981) : const Color(0xFFEF4444);
    final bgColor =
        isSuccess ? const Color(0xFFD1FAE5) : const Color(0xFFFEE2E2);
    final iconData =
        isSuccess ? Icons.check_circle_rounded : Icons.cancel_rounded;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 10,
      backgroundColor: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Icon Header Container
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: bgColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withValues(alpha: 0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Icon(
                iconData,
                color: iconColor,
                size: 34,
              ),
            ),
            const SizedBox(height: 18),

            // Title
            Text(
              title ?? defaultTitle,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 8),

            // Message
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade600,
                height: 1.4,
              ),
            ),

            if (subMessage != null && subMessage!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: isSuccess
                      ? Colors.teal.shade50
                      : Colors.orange.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSuccess
                        ? Colors.teal.shade200
                        : Colors.orange.shade200,
                  ),
                ),
                child: Text(
                  subMessage!,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isSuccess
                        ? Colors.teal.shade800
                        : Colors.orange.shade900,
                  ),
                ),
              ),
            ],

            const SizedBox(height: 22),

            // Action Button
            SizedBox(
              width: double.infinity,
              child: Container(
                decoration: BoxDecoration(
                  gradient: isSuccess
                      ? const LinearGradient(
                          colors: [Color(0xFF10B981), Color(0xFF059669)],
                        )
                      : const LinearGradient(
                          colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                        ),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: iconColor.withValues(alpha: 0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    if (onPressed != null) onPressed!();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text(
                    'Đóng',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
