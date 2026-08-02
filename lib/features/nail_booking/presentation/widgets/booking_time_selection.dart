import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n.dart';
import '../../../my_booking/data/datasources/waitlist_api_service.dart';

class BookingTimeSelection extends StatefulWidget {
  final List<dynamic> timeSlots;
  final bool isLoading;
  final String? selectedTime;
  final bool canSelect;
  final DateTime? selectedDate;
  final String? salonId; // Dùng cho Waitlist join API
  final String? artistId; // Dùng cho Waitlist join API (nullable = bất kỳ)
  final Function(String) onTimeChanged;

  /// Callback để trang cha reload lại danh sách giờ khi phát hiện isHeld.
  final VoidCallback? onRefreshSlots;

  const BookingTimeSelection({
    super.key,
    required this.timeSlots,
    required this.isLoading,
    required this.selectedTime,
    required this.canSelect,
    required this.selectedDate,
    required this.onTimeChanged,
    this.salonId,
    this.artistId,
    this.onRefreshSlots,
  });

  @override
  State<BookingTimeSelection> createState() => _BookingTimeSelectionState();
}

class _BookingTimeSelectionState extends State<BookingTimeSelection> {
  final Set<String> _waitlistedTimes = {};
  final WaitlistApiService _waitlistApi = WaitlistApiService();
  bool _isJoining = false;

  Future<void> _showWaitlistBottomSheet(String time) async {
    if (widget.salonId == null) {
      // Nếu không có salonId thì show UI cũ (no-op API)
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => _WaitlistJoinSheet(
          time: time.substring(0, 5),
          onJoin: () {
            setState(() => _waitlistedTimes.add(time));
          },
          onPickOther: () => Navigator.pop(context),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _WaitlistJoinSheet(
        time: time.substring(0, 5),
        onJoin: () async {
          if (_isJoining) return;
          _isJoining = true;
          try {
            await _waitlistApi.joinWaitlist(
              salonId: widget.salonId!,
              preferredNailArtistId: widget.artistId,
              requestedDate: widget.selectedDate ?? DateTime.now(),
              requestedStartTime: time,
            );
            if (mounted) setState(() => _waitlistedTimes.add(time));
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(S.of(context).bookingWaitlistError(e.toString()))),
              );
            }
          } finally {
            _isJoining = false;
          }
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
        Text(
          S.of(context).bookingAvailableSlots,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        if (!widget.canSelect)
          Text(
            S.of(context).bookingSelectArtistFirst,
            style: const TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
          )
        else if (widget.isLoading)
          const CircularProgressIndicator()
        else if (widget.timeSlots.isEmpty)
          Text(S.of(context).bookingNoSchedule)
        else
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              childAspectRatio: 2.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: widget.timeSlots.length,
            itemBuilder: (context, index) {
              final slot = widget.timeSlots[index];
              final String time = slot['startTime']; // "09:30:00"
              final bool isAvailableApi = slot['isAvailable'] == true;
              final bool isHeld = slot['isHeld'] == true;
              final bool isSelected = widget.selectedTime == time;
              final bool isWaitlisted = _waitlistedTimes.contains(time);

              bool isPast = false;

              // ==========================================
              // LOGIC CHỐT CHẶN KHÔNG CHO CHỌN GIỜ QUÁ KHỨ
              // ==========================================
              if (widget.selectedDate != null) {
                final now = DateTime.now();
                final DateTime todayStart = DateTime(
                  now.year,
                  now.month,
                  now.day,
                );
                final DateTime selectedDateStart = DateTime(
                  widget.selectedDate!.year,
                  widget.selectedDate!.month,
                  widget.selectedDate!.day,
                );

                if (selectedDateStart.isBefore(todayStart)) {
                  isPast = true;
                } else if (selectedDateStart.isAtSameMomentAs(todayStart)) {
                  final List<String> timeParts = time.split(':');
                  final int slotHour = int.tryParse(timeParts[0]) ?? 0;
                  final int slotMinute = int.tryParse(timeParts[1]) ?? 0;

                  if (slotHour < now.hour ||
                      (slotHour == now.hour && slotMinute <= now.minute)) {
                    isPast = true;
                  }
                }
              }
              // ==========================================

              // isAvail: chỉ khi isAvailable: true VÀ isHeld: false → có thể chọn
              final bool isAvail = isAvailableApi && !isHeld && !isPast;
              // isHeldOnly: đang bị giữ tạm (5 phút) bởi ai đó → mờ, cho vào waitlist
              final bool isHeldOnly = isHeld && !isPast;
              // isFull: đã đặt hẳn (isAvailable: false) và KHÔNG đang held → mờ, waitlist
              final bool isFull = !isAvailableApi && !isHeld && !isPast;

              // Xác định style cho ô
              Color bgColor;
              Color borderColor;
              Color textColor;
              bool showBell = false;
              bool lineThrough = false;
              FontWeight fontWeight = FontWeight.normal;

              if (isSelected) {
                bgColor = AppColors.primary;
                borderColor = AppColors.primary;
                textColor = Colors.white;
                fontWeight = FontWeight.bold;
              } else if (isWaitlisted) {
                bgColor = AppColors.primary.withOpacity(0.08);
                borderColor = AppColors.primary.withOpacity(0.5);
                textColor = AppColors.primary;
                fontWeight = FontWeight.bold;
                showBell = true;
              } else if (isAvail) {
                // Còn trống, không bị giữ
                bgColor = Colors.white;
                borderColor = Colors.grey.shade300;
                textColor = Colors.black;
                fontWeight = FontWeight.bold;
              } else if (isPast) {
                bgColor = Colors.grey.shade50;
                borderColor = Colors.transparent;
                textColor = Colors.grey.shade300;
                lineThrough = true;
              } else {
                // isHeldOnly hoặc isFull → đều hiện mờ giống nhau
                bgColor = Colors.grey.shade100;
                borderColor = Colors.grey.shade200;
                textColor = Colors.grey.shade400;
              }

              return GestureDetector(
                onTap: () {
                  // Kiểm tra lại tại thời điểm tap (người dùng gửi request)
                  bool isCurrentlyPast = false;
                  if (widget.selectedDate != null) {
                    final currentNow = DateTime.now();
                    final currentTodayStart = DateTime(
                      currentNow.year,
                      currentNow.month,
                      currentNow.day,
                    );
                    final selDateStart = DateTime(
                      widget.selectedDate!.year,
                      widget.selectedDate!.month,
                      widget.selectedDate!.day,
                    );

                    if (selDateStart.isBefore(currentTodayStart)) {
                      isCurrentlyPast = true;
                    } else if (selDateStart.isAtSameMomentAs(
                      currentTodayStart,
                    )) {
                      final List<String> timeParts = time.split(':');
                      final int slotHour = int.tryParse(timeParts[0]) ?? 0;
                      final int slotMinute = int.tryParse(timeParts[1]) ?? 0;

                      if (slotHour < currentNow.hour ||
                          (slotHour == currentNow.hour &&
                              slotMinute <= currentNow.minute)) {
                        isCurrentlyPast = true;
                      }
                    }
                  }

                  if (isCurrentlyPast) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(S.of(context).bookingSlotPast),
                        backgroundColor: Colors.redAccent,
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                    return;
                  }

                  if (isAvail) {
                    // isHeld: false, isAvailable: true → tạo holdToken bình thường
                    widget.onTimeChanged(time);
                  } else if (isWaitlisted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Row(
                          children: [
                            const Icon(
                              Icons.notifications_active,
                              color: Colors.white,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              S.of(context).bookingWaitlistJoined(time.substring(0, 5)),
                            ),
                          ],
                        ),
                        backgroundColor: AppColors.primary,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                  } else if (isHeldOnly) {
                    // isHeld: true → hiện thông báo, reload slot, cho vào waitlist
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Khung giờ này đang được giữ chỗ tạm thời. Bạn có thể đăng ký hàng chờ.',
                        ),
                        backgroundColor: Colors.orange.shade700,
                        behavior: SnackBarBehavior.floating,
                        duration: const Duration(seconds: 3),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                    );
                    // Reload để cập nhật trạng thái mới nhất
                    widget.onRefreshSlots?.call();
                    _showWaitlistBottomSheet(time);
                  } else if (isFull) {
                    // isAvailable: false, isHeld: false → đã đặt hẳn → cho vào waitlist
                    _showWaitlistBottomSheet(time);
                  }
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  decoration: BoxDecoration(
                    color: bgColor,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: borderColor,
                      width: isWaitlisted ? 1.5 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        time.substring(0, 5), // "09:30"
                        style: TextStyle(
                          fontWeight: fontWeight,
                          color: textColor,
                          decoration: lineThrough
                              ? TextDecoration.lineThrough
                              : null,
                          decorationColor: Colors.grey.shade400,
                        ),
                      ),
                      if (showBell) ...[
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.notifications_active,
                          size: 13,
                          color: AppColors.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

// ────────────────────────────────────────────────
// SUB-WIDGET: BottomSheet mời tham gia Waitlist
// ────────────────────────────────────────────────
class _WaitlistJoinSheet extends StatefulWidget {
  final String time;
  final VoidCallback onJoin;
  final VoidCallback onPickOther;

  const _WaitlistJoinSheet({
    required this.time,
    required this.onJoin,
    required this.onPickOther,
  });

  @override
  State<_WaitlistJoinSheet> createState() => _WaitlistJoinSheetState();
}

class _WaitlistJoinSheetState extends State<_WaitlistJoinSheet> {
  bool _isSuccess = false;

  void _handleJoin() {
    widget.onJoin(); // Cập nhật UI (hiện chuông) ở trang booking phía dưới
    setState(() {
      _isSuccess = true; // Chuyển sang màn hình success
    });
  }

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

          if (_isSuccess) _buildSuccessView() else _buildJoinView(),
        ],
      ),
    );
  }

  Widget _buildJoinView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
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
          'Khung giờ ${widget.time} đã kín chỗ!',
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
            onPressed: _handleJoin,
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
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Nút phụ: Chọn giờ khác
        SizedBox(
          width: double.infinity,
          child: TextButton(
            onPressed: widget.onPickOther,
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
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Biểu tượng thành công
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.check_circle_outline,
            color: Colors.green.shade600,
            size: 36,
          ),
        ),
        const SizedBox(height: 16),

        // Tiêu đề
        Text(
          'Đã thêm khung giờ ${widget.time} vào hàng chờ thành công!',
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
          'Bạn sẽ nhận được thông báo ngay khi có chỗ trống.',
          style: TextStyle(
            color: Colors.grey.shade600,
            height: 1.55,
            fontSize: 14,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 28),

        // Nút 1: Đặt lịch tiếp
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onPickOther, // Đóng BottomSheet và ở lại
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'Đặt khung giờ khác',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // Nút 2: Trở về
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () {
              Navigator.pop(context); // Đóng BottomSheet
              context.go('/'); // Về màn hình chính
            },
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.grey.shade700,
              side: BorderSide(color: Colors.grey.shade300),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text(
              'Quay về màn hình chính',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ],
    );
  }
}
