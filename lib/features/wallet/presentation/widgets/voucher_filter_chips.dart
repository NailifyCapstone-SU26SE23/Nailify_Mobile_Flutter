import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n_x.dart';

enum VoucherFilterType { all, percentage, fixedAmount }

class VoucherFilterChips extends StatelessWidget {
  final VoucherFilterType selected;
  final ValueChanged<VoucherFilterType> onChanged;

  const VoucherFilterChips({
    super.key,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          _chip(
            context: context,
            label: context.l10n.filterAll,
            type: VoucherFilterType.all,
          ),
          const SizedBox(width: 8),
          _chip(
            context: context,
            label: context.l10n.filterPercentage,
            type: VoucherFilterType.percentage,
          ),
          const SizedBox(width: 8),
          _chip(
            context: context,
            label: context.l10n.filterFixedAmount,
            type: VoucherFilterType.fixedAmount,
          ),
        ],
      ),
    );
  }

  Widget _chip({
    required BuildContext context,
    required String label,
    required VoucherFilterType type,
  }) {
    final isSelected = type == selected;
    return Material(
      color: isSelected ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => onChanged(type),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isSelected ? AppColors.primary : Colors.grey.shade300,
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: isSelected ? Colors.white : AppColors.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}
