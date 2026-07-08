// ====================================================================
// FILE: lib/features/nail_booking/presentation/widgets/booking_time_slot_waitlist.dart
// Mô tả: Widget danh sách khung giờ có tích hợp tính năng Slot Waitlist.
//        Khi slot bị đầy, user có thể tap để tham gia danh sách chờ.
// ====================================================================

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';

// ────────────────────────────────────────────────
// MODEL: Trạng thái của một khung giờ
// ────────────────────────────────────────────────
enum TimeSlotState {
  available,  // Còn chỗ, có thể chọn
  full,       // Hết chỗ (chưa đăng ký chờ)
  waiting,    // Hết chỗ, đã đăng ký danh sách chờ
  past,       // Giờ đã qua
  selected,   // Đang được chọn
}

class TimeSlotItem {
  final String time; // "09:00"
  TimeSlotState state;

  TimeSlotItem({required this.time, required this.state});
}

// ────────────────────────────────────────────────
// MOCK DATA — Giả lập danh sách giờ
// ────────────────────────────────────────────────
class TimeSlotMockData {
  static List<TimeSlotItem> get slots => [
        TimeSlotItem(time: '08:00', state: TimeSlotState.past),
        TimeSlotItem(time: '08:30', state: TimeSlotState.past),
        TimeSlotItem(time: '09:00', state: TimeSlotState.full),     // Slot bị đầy — demo waitlist
        TimeSlotItem(time: '09:30', state: TimeSlotState.available),
        TimeSlotItem(time: '10:00', state: TimeSlotState.available),
        TimeSlotItem(time: '10:30', state: TimeSlotState.available),
        TimeSlotItem(time: '11:00', state: TimeSlotState.available),
        TimeSlotItem(time: '11:30', state: TimeSlotState.full),
        TimeSlotItem(time: '12:00', state: TimeSlotState.available),
        TimeSlotItem(time: '13:00', state: TimeSlotState.available),
        TimeSlotItem(time: '13:30', state: TimeSlotState.available),
        TimeSlotItem(time: '14:00', state: TimeSlotState.available),
      ];
}

// ────────────────────────────────────────────────
// MAIN WIDGET: Lưới giờ có Waitlist
// ────────────────────────────────────────────────
class BookingTimeSlotWaitlist extends StatefulWidget {
  /// Callback khi user chọn được 1 giờ hợp lệ
  final ValueChanged<String>? onTimeSelected;

  const BookingTimeSlotWaitlist({super.key, this.onTimeSelected});

  @override
  State<BookingTimeSlotWaitlist> createState() =>
      _BookingTimeSlotWaitlistState();
}

class _BookingTimeSlotWaitlistState extends State<BookingTimeSlotWaitlist> {
  late List<TimeSlotItem> _slots;
  String? _selectedTime;

  @override
  void initState() {
    super.initState();
    _slots = TimeSlotMockData.slots;
  }

  void _handleSlotTap(TimeSlotItem slot) {
    switch (slot.state) {
      case TimeSlotState.available:
        setState(() {
          // Bỏ chọn cũ
          for (var s in _slots) {
            if (s.state == TimeSlotState.selected) {
              s.state = TimeSlotState.available;
            }
          }
          slot.state = TimeSlotState.selected;
          _selectedTime = slot.time;
        });
        widget.onTimeSelected?.call(slot.time);
        break;

      case TimeSlotState.selected:
        // Bỏ chọn
        setState(() {
          slot.state = TimeSlotState.available;
          _selectedTime = null;
        });
        break;

      case TimeSlotState.full:
        // Hiện BottomSheet mời tham gia waitlist
        _showWaitlistBottomSheet(slot);
        break;

      case TimeSlotState.waiting:
        // Thông báo đã đăng ký rồi
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.notifications_active,
                    color: Colors.white, size: 16),
                const SizedBox(width: 8),
                Text('Bạn đã đăng ký chờ cho giờ ${slot.time}'),
              ],
            ),
            backgroundColor: AppColors.primary,
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
        break;

      case TimeSlotState.past:
        // Không làm gì
        break;
    }
  }

  void _showWaitlistBottomSheet(TimeSlotItem slot) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WaitlistJoinSheet(
        time: slot.time,
        onJoin: () {
          Navigator.pop(context);
          setState(() {
            slot.state = TimeSlotState.waiting;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.notifications_active,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 8),
                  Text('Đã tham gia hàng chờ lúc ${slot.time}!'),
                ],
              ),
              backgroundColor: AppColors.primary,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          );
        },
        onPickOther: () => Navigator.pop(context),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        const Text(
          'Chọn khung giờ',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 10),

        // Chú thích
        _buildLegend(),
        const SizedBox(height: 14),

        // Lưới giờ
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            childAspectRatio: 2.4,
            crossAxisSpacing: 10,
            mainAxisSpacing: 10,
          ),
          itemCount: _slots.length,
          itemBuilder: (context, index) {
            return _SlotTile(
              slot: _slots[index],
              onTap: () => _handleSlotTap(_slots[index]),
            );
          },
        ),
      ],
    );
  }

  Widget _buildLegend() {
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: [
        _LegendDot(color: AppColors.primary, label: 'Đang chọn'),
        _LegendDot(color: Colors.grey.shade300, label: 'Hết chỗ'),
        _LegendDot(
            color: AppColors.primary.withOpacity(0.15),
            label: 'Đang chờ',
            borderColor: AppColors.primary),
        _LegendDot(color: Colors.grey.shade100, label: 'Đã qua'),
      ],
    );
  }
}

// ────────────────────────────────────────────────
// SUB-WIDGET: Ô giờ đơn lẻ
// ────────────────────────────────────────────────
class _SlotTile extends StatelessWidget {
  final TimeSlotItem slot;
  final VoidCallback onTap;

  const _SlotTile({required this.slot, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cfg = _slotConfig(slot.state);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: cfg.bgColor,
          borderRadius: BorderRadius.circular(9),
          border: Border.all(
            color: cfg.borderColor,
            width: cfg.borderWidth,
          ),
        ),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              slot.time,
              style: TextStyle(
                fontSize: 13,
                fontWeight: cfg.bold ? FontWeight.bold : FontWeight.normal,
                color: cfg.textColor,
                decoration: slot.state == TimeSlotState.past
                    ? TextDecoration.lineThrough
                    : null,
                decorationColor: Colors.grey.shade400,
              ),
            ),
            // Icon chuông cho trạng thái "đang chờ"
            if (slot.state == TimeSlotState.waiting) ...[
              const SizedBox(width: 3),
              Icon(
                Icons.notifications_active,
                size: 12,
                color: AppColors.primary,
              ),
            ],
          ],
        ),
      ),
    );
  }

  _SlotStyle _slotConfig(TimeSlotState state) {
    switch (state) {
      case TimeSlotState.selected:
        return _SlotStyle(
          bgColor: AppColors.primary,
          borderColor: AppColors.primary,
          textColor: Colors.white,
          borderWidth: 2,
          bold: true,
        );
      case TimeSlotState.available:
        return _SlotStyle(
          bgColor: Colors.white,
          borderColor: Colors.grey.shade300,
          textColor: AppColors.textPrimary,
          borderWidth: 1,
          bold: true,
        );
      case TimeSlotState.full:
        return _SlotStyle(
          bgColor: Colors.grey.shade100,
          borderColor: Colors.grey.shade200,
          textColor: Colors.grey.shade400,
          borderWidth: 1,
          bold: false,
        );
      case TimeSlotState.waiting:
        return _SlotStyle(
          bgColor: AppColors.primary.withOpacity(0.08),
          borderColor: AppColors.primary.withOpacity(0.5),
          textColor: AppColors.primary,
          borderWidth: 1.5,
          bold: true,
        );
      case TimeSlotState.past:
        return _SlotStyle(
          bgColor: Colors.grey.shade50,
          borderColor: Colors.transparent,
          textColor: Colors.grey.shade300,
          borderWidth: 0,
          bold: false,
        );
    }
  }
}

class _SlotStyle {
  final Color bgColor;
  final Color borderColor;
  final Color textColor;
  final double borderWidth;
  final bool bold;
  const _SlotStyle({
    required this.bgColor,
    required this.borderColor,
    required this.textColor,
    required this.borderWidth,
    required this.bold,
  });
}

// ────────────────────────────────────────────────
// SUB-WIDGET: BottomSheet mời tham gia Waitlist
// ────────────────────────────────────────────────
class _WaitlistJoinSheet extends StatelessWidget {
  final String time;
  final VoidCallback onJoin;
  final VoidCallback onPickOther;

  const _WaitlistJoinSheet({
    required this.time,
    required this.onJoin,
    required this.onPickOther,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Biểu tượng
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.notification_add_outlined,
              color: AppColors.primary,
              size: 36,
            ),
          ),
          const SizedBox(height: 16),

          // Tiêu đề
          Text(
            'Khung giờ $time đã kín chỗ!',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),

          // Mô tả
          Text(
            'Bạn có muốn tham gia danh sách chờ không?\nHệ thống sẽ báo ngay cho bạn nếu lịch này trống.',
            style: TextStyle(
              color: Colors.grey.shade600,
              height: 1.55,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),

          // Nút chính: Tham gia hàng chờ
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: onJoin,
              icon: const Icon(Icons.notifications_active_outlined, size: 18),
              label: const Text(
                'Tham gia hàng chờ',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
            ),
          ),
          const SizedBox(height: 10),

          // Nút phụ: Chọn giờ khác
          SizedBox(
            width: double.infinity,
            child: TextButton(
              onPressed: onPickOther,
              style: TextButton.styleFrom(
                foregroundColor: Colors.grey.shade600,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              child: const Text(
                'Chọn giờ khác',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────
// SUB-WIDGET: Chú thích màu (Legend)
// ────────────────────────────────────────────────
class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  final Color? borderColor;

  const _LegendDot({required this.color, required this.label, this.borderColor});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1.5)
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}
