import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../data/models/promotion_model.dart';

/// Selector khuyến mãi dùng chung cho cả 3 luồng booking.
///
/// Fix lỗi Flutter: RadioListTile wrapped in a DecoratedBox that has a
/// background color — by wrapping each tile in its own Material we restore
/// the ink ripple effect that was being hidden by the outer DecoratedBox.
class PromotionSelectorCard extends StatelessWidget {
  /// Danh sách khuyến mãi khả dụng.
  final List<PromotionModel> promotions;

  /// ID khuyến mãi đang được chọn (null = không chọn).
  final int? selectedPromotionId;

  /// Loading state.
  final bool isLoading;

  /// single = Radio (chọn 1); multi = Checkbox (chọn nhiều).
  final bool multiSelect;

  /// Danh sách các promotion id đang được chọn (chỉ dùng khi multiSelect).
  final List<int> selectedIds;

  /// Callback khi user chọn/bỏ chọn 1 promotion (single mode).
  final ValueChanged<int?> onChanged;

  /// Callback khi user toggle 1 promotion (multi mode).
  final void Function(int promotionId, bool selected) onMultiChanged;

  const PromotionSelectorCard({
    super.key,
    required this.promotions,
    required this.selectedPromotionId,
    required this.isLoading,
    required this.onChanged,
    this.multiSelect = false,
    this.selectedIds = const [],
    required this.onMultiChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.shade100),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (multiSelect)
              ..._buildCheckboxChildren(context)
            else
              ..._buildRadioChildren(context),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildRadioChildren(BuildContext context) {
    return <Widget>[
      _NoPromotionRadio(
        value: 0,
        groupValue: selectedPromotionId ?? 0,
        onChanged: (v) => onChanged(null),
      ),
      if (!isLoading && promotions.isEmpty)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            'Không có khuyến mại khả dụng.',
            style: const TextStyle(color: Colors.grey, fontSize: 13),
          ),
        ),
      ...promotions.map(
        (p) => _PromotionRadioTile(
          value: p.promotionId,
          groupValue: selectedPromotionId ?? 0,
          onChanged: (_) => onChanged(p.promotionId),
          title: p.name,
          subtitle: p.description.isNotEmpty
              ? '${p.discountLabel} - ${p.description}'
              : p.discountLabel,
        ),
      ),
    ];
  }

  List<Widget> _buildCheckboxChildren(BuildContext context) {
    return <Widget>[
      if (isLoading)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        )
      else if (promotions.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Không có khuyến mại khả dụng.',
            style: TextStyle(color: Colors.grey, fontSize: 13),
          ),
        )
      else
        ...promotions.map(
          (p) => _PromotionCheckboxTile(
            value: selectedIds.contains(p.promotionId),
            onChanged: (checked) =>
                onMultiChanged(p.promotionId, checked ?? false),
            title: p.name,
            subtitle: p.description.isNotEmpty
                ? '${p.discountLabel} - ${p.description}'
                : p.discountLabel,
          ),
        ),
    ];
  }
}

/// RadioItem "Không áp dụng" — wrap Material để hiện ink ripple.
class _NoPromotionRadio extends StatelessWidget {
  final int value;
  final int groupValue;
  final ValueChanged<int?> onChanged;
  const _NoPromotionRadio({
    required this.value,
    required this.groupValue,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: RadioListTile<int>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        title: const Text('Không áp dụng'),
        dense: true,
        contentPadding: EdgeInsets.zero,
        activeColor: AppColors.primary,
        selected: value == groupValue,
        selectedTileColor: Colors.transparent,
      ),
    );
  }
}

/// Promotion radio item — wrap Material để hiện ink ripple.
class _PromotionRadioTile extends StatelessWidget {
  final int value;
  final int groupValue;
  final ValueChanged<int?> onChanged;
  final String title;
  final String subtitle;

  const _PromotionRadioTile({
    required this.value,
    required this.groupValue,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: RadioListTile<int>(
        value: value,
        groupValue: groupValue,
        onChanged: onChanged,
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          subtitle,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        dense: true,
        contentPadding: EdgeInsets.zero,
        activeColor: AppColors.primary,
        selected: value == groupValue,
        selectedTileColor: Colors.transparent,
      ),
    );
  }
}

/// Promotion checkbox item — wrap Material để hiện ink ripple.
class _PromotionCheckboxTile extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final String title;
  final String subtitle;

  const _PromotionCheckboxTile({
    required this.value,
    required this.onChanged,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: CheckboxListTile(
        value: value,
        onChanged: onChanged,
        title: Text(title),
        subtitle: Text(subtitle),
        dense: true,
        contentPadding: EdgeInsets.zero,
        activeColor: AppColors.primary,
        selected: value,
        selectedTileColor: Colors.transparent,
        controlAffinity: ListTileControlAffinity.leading,
      ),
    );
  }
}
