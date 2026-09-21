import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';

class PaymentTableItem {
  final String name;
  final int quantity;
  final num unitPrice;
  final num totalPrice;

  const PaymentTableItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    num? totalPrice,
  }) : totalPrice = totalPrice ?? (unitPrice * quantity);
}

class PaymentDetailTable extends StatelessWidget {
  final List<PaymentTableItem> items;

  const PaymentDetailTable({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          items[i].name,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                      ),
                      if (items[i].quantity > 1) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFFF0F5),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFFFFD1DC)),
                          ),
                          child: Text(
                            'x${items[i].quantity}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  PriceFormatter.format(items[i].totalPrice),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          if (i < items.length - 1)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 4),
              child: Divider(
                height: 1,
                thickness: 0.8,
                color: Color(0xFFF3E8EE),
              ),
            ),
        ],
      ],
    );
  }
}
