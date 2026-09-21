import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/wallet_voucher_model.dart';

class TicketVoucherWidget extends StatelessWidget {
  final WalletVoucherModel voucher;
  final bool isSelected;
  final VoidCallback onTap;

  const TicketVoucherWidget({
    super.key,
    required this.voucher,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: ClipPath(
          clipper: TicketClipper(),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Left side: Icon & Amount
                Container(
                  width: 100,
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary.withOpacity(0.1) : Colors.orange.shade50,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        voucher.discountType.toLowerCase() == 'percentage'
                            ? Icons.percent
                            : Icons.discount_outlined,
                        color: isSelected ? AppColors.primary : Colors.orange.shade700,
                        size: 28,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        voucher.displayDiscount,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? AppColors.primary : Colors.orange.shade700,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),

                // Dashed line
                CustomPaint(
                  size: const Size(1, double.infinity),
                  painter: DashedLinePainter(
                    color: isSelected ? AppColors.primary.withOpacity(0.5) : Colors.grey.shade300,
                  ),
                ),

                // Right side: Details
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                voucher.promotionName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Radio button representation
                            Icon(
                              isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                              color: isSelected ? AppColors.primary : Colors.grey.shade400,
                              size: 22,
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        if (voucher.description.isNotEmpty) ...[
                          Text(
                            voucher.description,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 13,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                        ],
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Text(
                            'Còn ${voucher.remainingCount}/${voucher.receivedCount} lượt',
                            style: TextStyle(
                              color: Colors.green.shade700,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class TicketClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    final path = Path();
    
    // Draw outer rectangle
    path.lineTo(0, size.height);
    path.lineTo(size.width, size.height);
    path.lineTo(size.width, 0);
    path.close();

    // Left and right cutouts (semi-circles at the dashed line)
    final double holeRadius = 8.0;
    final double holePositionX = 100.0; // Same as left container width

    // Top hole
    final topHole = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(holePositionX, 0), radius: holeRadius),
        0,
        3.14159,
      );

    // Bottom hole
    final bottomHole = Path()
      ..addArc(
        Rect.fromCircle(center: Offset(holePositionX, size.height), radius: holeRadius),
        -3.14159,
        3.14159,
      );

    final fullPath = Path.combine(PathOperation.difference, path, topHole);
    return Path.combine(PathOperation.difference, fullPath, bottomHole);
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}

class DashedLinePainter extends CustomPainter {
  final Color color;

  DashedLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const dashWidth = 5.0;
    const dashSpace = 5.0;
    double startY = 12.0;

    while (startY < size.height - 12) {
      canvas.drawLine(
        Offset(0, startY),
        Offset(0, startY + dashWidth),
        paint,
      );
      startY += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
