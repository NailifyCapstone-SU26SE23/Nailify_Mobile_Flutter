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

  const PaymentDetailTable({
    super.key,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFD1E3), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(11),
        child: Table(
          border: const TableBorder(
            horizontalInside: BorderSide(
              color: Color(0xFFFFEBF2),
              width: 1,
            ),
            verticalInside: BorderSide(
              color: Color(0xFFFFEBF2),
              width: 1,
            ),
          ),
          columnWidths: const {
            0: FixedColumnWidth(32),   // TT
            1: FlexColumnWidth(3.2),  // Dịch vụ
            2: FixedColumnWidth(34),   // SL
            3: FlexColumnWidth(2.2),  // Đơn giá
            4: FlexColumnWidth(2.4),  // Thành tiền
          },
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          children: [
            // ── HEADER ROW ──────────────────────────────────────────
            const TableRow(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF85A1), Color(0xFFFFA4BA)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
              ),
              children: [
                _HeaderCell('TT', alignment: Alignment.center),
                _HeaderCell('Dịch Vụ', alignment: Alignment.centerLeft),
                _HeaderCell('SL', alignment: Alignment.center),
                _HeaderCell('Đơn Giá', alignment: Alignment.centerRight),
                _HeaderCell('Thành Tiền', alignment: Alignment.centerRight),
              ],
            ),
            // ── DATA ROWS ───────────────────────────────────────────
            for (int i = 0; i < items.length; i++)
              TableRow(
                decoration: BoxDecoration(
                  color: i % 2 == 0
                      ? Colors.white
                      : const Color(0xFFFFF9FB),
                ),
                children: [
                  _DataCell(
                    '${i + 1}',
                    alignment: Alignment.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.black54,
                    ),
                  ),
                  _DataCell(
                    items[i].name,
                    alignment: Alignment.centerLeft,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  _DataCell(
                    '${items[i].quantity}',
                    alignment: Alignment.center,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  _DataCell(
                    PriceFormatter.format(items[i].unitPrice).replaceAll(' VNĐ', ''),
                    alignment: Alignment.centerRight,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                  _DataCell(
                    PriceFormatter.format(items[i].totalPrice).replaceAll(' VNĐ', ''),
                    alignment: Alignment.centerRight,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  final Alignment alignment;

  const _HeaderCell(this.text, {required this.alignment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      alignment: alignment,
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _DataCell extends StatelessWidget {
  final String text;
  final Alignment alignment;
  final TextStyle style;

  const _DataCell(
    this.text, {
    required this.alignment,
    required this.style,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
      alignment: alignment,
      child: Text(
        text,
        style: style,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
