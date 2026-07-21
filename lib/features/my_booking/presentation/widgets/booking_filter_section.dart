import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';

class BookingFilterSection extends StatelessWidget {
  final int? selectedMonth;
  final int? selectedYear;
  final String selectedStatus;
  final List<int> availableYears;
  final List<Map<String, String>> statusOptions;
  final ValueChanged<int?> onMonthChanged;
  final ValueChanged<int?> onYearChanged;
  final ValueChanged<String> onStatusChanged;

  const BookingFilterSection({
    super.key,
    required this.selectedMonth,
    required this.selectedYear,
    required this.selectedStatus,
    required this.availableYears,
    required this.statusOptions,
    required this.onMonthChanged,
    required this.onYearChanged,
    required this.onStatusChanged,
  });

  IconData _getStatusIcon(String key) {
    switch (key) {
      case 'Tất cả':
        return Icons.apps_rounded;
      case 'Pending':
        return Icons.hourglass_empty_rounded;
      case 'Approved':
        return Icons.check_circle_outline_rounded;
      case 'Assigned':
        return Icons.calendar_today_rounded;
      case 'CheckedIn':
        return Icons.login_rounded;
      case 'InProgress':
        return Icons.brush_rounded;
      case 'Completed':
        return Icons.done_all_rounded;
      case 'Reviewed':
        return Icons.rate_review_rounded;
      case 'Repaired':
        return Icons.build_circle_rounded;
      case 'Rejected':
        return Icons.cancel_rounded;
      case 'Cancelled':
        return Icons.delete_sweep_rounded;
      default:
        return Icons.info_outline_rounded;
    }
  }

  void _showMonthPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFDFBF7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chọn tháng',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  if (selectedMonth != null)
                    TextButton(
                      onPressed: () {
                        onMonthChanged(null);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Xóa lọc',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  childAspectRatio: 1.5,
                ),
                itemCount: 12,
                itemBuilder: (context, index) {
                  final month = index + 1;
                  final isSelected = selectedMonth == month;
                  return InkWell(
                    onTap: () {
                      onMonthChanged(month);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : const Color(0xFFF3EFEA),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Tháng $month',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showYearPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFFFDFBF7),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Chọn năm',
                    style: TextStyle(
                      fontFamily: 'Georgia',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryDark,
                    ),
                  ),
                  if (selectedYear != null)
                    TextButton(
                      onPressed: () {
                        onYearChanged(null);
                        Navigator.pop(context);
                      },
                      child: const Text(
                        'Xóa lọc',
                        style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: availableYears.map((year) {
                  final isSelected = selectedYear == year;
                  return InkWell(
                    onTap: () {
                      onYearChanged(year);
                      Navigator.pop(context);
                    },
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary : Colors.white,
                        border: Border.all(
                          color: isSelected ? AppColors.primary : const Color(0xFFF3EFEA),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Năm $year',
                        style: TextStyle(
                          color: isSelected ? Colors.white : AppColors.textPrimary,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasActiveFilter = selectedMonth != null || selectedYear != null || selectedStatus != 'Tất cả';

    return Container(
      color: const Color(0xFFFDFBF7),
      padding: const EdgeInsets.only(top: 8, bottom: 16),
      child: Column(
        children: [
          // 1. Selector buttons in row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: _buildPickerButton(
                    context: context,
                    icon: Icons.calendar_month_rounded,
                    label: selectedMonth == null ? 'Lọc theo Tháng' : 'Tháng $selectedMonth',
                    isActive: selectedMonth != null,
                    onTap: () => _showMonthPicker(context),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _buildPickerButton(
                    context: context,
                    icon: Icons.calendar_today_rounded,
                    label: selectedYear == null ? 'Lọc theo Năm' : 'Năm $selectedYear',
                    isActive: selectedYear != null,
                    onTap: () => _showYearPicker(context),
                  ),
                ),
                if (hasActiveFilter) ...[
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: () {
                      onMonthChanged(null);
                      onYearChanged(null);
                      onStatusChanged('Tất cả');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.red.shade100, width: 1),
                      ),
                      child: Icon(
                        Icons.refresh_rounded,
                        color: Colors.red.shade600,
                        size: 20,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // 2. Status chips horizontally scrollable with icons
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: statusOptions.map((status) {
                final isSelected = selectedStatus == status['key'];
                final icon = _getStatusIcon(status['key']!);
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    avatar: Icon(
                      icon,
                      size: 16,
                      color: isSelected ? Colors.white : AppColors.primary,
                    ),
                    label: Text(
                      status['label']!,
                      style: TextStyle(
                        color: isSelected ? Colors.white : AppColors.textPrimary,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                    selected: isSelected,
                    onSelected: (selected) {
                      onStatusChanged(status['key']!);
                    },
                    selectedColor: AppColors.primary,
                    backgroundColor: Colors.white,
                    checkmarkColor: Colors.white,
                    showCheckmark: false,
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(
                      color: isSelected ? AppColors.primary : const Color(0xFFF3EFEA),
                      width: 1.2,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: isActive ? const Color(0xFFFFF0F5) : Colors.white,
          border: Border.all(
            color: isActive ? AppColors.primary : const Color(0xFFF3EFEA),
            width: 1.2,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.01),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 18,
              color: isActive ? AppColors.primary : Colors.grey.shade500,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: isActive ? FontWeight.bold : FontWeight.w600,
                  color: isActive ? AppColors.primary : AppColors.textPrimary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Icon(
              Icons.expand_more_rounded,
              size: 18,
              color: isActive ? AppColors.primary : Colors.grey.shade400,
            ),
          ],
        ),
      ),
    );
  }
}
