// ====================================================================
// FILE: lib/features/my_booking/presentation/widgets/waitlist_card.dart
// Mô tả: Widget thẻ lịch chờ (Waitlist Card) với 2 trạng thái
// ====================================================================

import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../generated/l10n.dart';
import '../../data/models/waitlist_model.dart';

// ─────────────────────────────────────────────
// MAIN CARD: Phân loại trạng thái
// ─────────────────────────────────────────────
class WaitlistCard extends StatelessWidget {
  final WaitlistModel item;
  final VoidCallback onCancel;
  final VoidCallback onConfirmBook;
  final VoidCallback onDecline;

  const WaitlistCard({
    super.key,
    required this.item,
    required this.onCancel,
    required this.onConfirmBook,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    if (item.status == WaitlistStatus.opened) {
      return _WaitlistOpenedCard(
        item: item,
        onConfirmBook: onConfirmBook,
        onDecline: onDecline,
      );
    }
    return _WaitlistPendingCard(item: item, onCancel: onCancel);
  }
}

// ─────────────────────────────────────────────
// TRẠNG THÁI A: ĐANG XẾP HÀNG (Pending)
// ─────────────────────────────────────────────
class _WaitlistPendingCard extends StatelessWidget {
  final WaitlistModel item;
  final VoidCallback onCancel;

  const _WaitlistPendingCard({required this.item, required this.onCancel});

  String _timeSince(BuildContext context, DateTime from) {
    final diff = DateTime.now().difference(from);
    if (diff.inMinutes < 60) return S.of(context).waitlistMinutesAgo(diff.inMinutes.toString());
    if (diff.inHours < 24) return S.of(context).waitlistHoursAgo(diff.inHours.toString());
    return S.of(context).waitlistDaysAgo(diff.inDays.toString());
  }

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      badge: _StatusBadge(
        label: S.of(context).waitlistStatusPending,
        bgColor: Colors.blue.shade50,
        textColor: Colors.blue.shade700,
        icon: Icons.hourglass_top_rounded,
      ),
      item: item,
      extraBody: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text(
              '${S.of(context).waitlistRegisteredAt}${_timeSince(context, item.registeredAt)}',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade500,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
      ),
      actions: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _showCancelDialog(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red.shade400,
              side: BorderSide(color: Colors.red.shade200),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(vertical: 11),
            ),
            child: Text(
              S.of(context).waitlistCancelBtn,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ),
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          S.of(context).waitlistCancelDialogTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text(
          S.of(context).waitlistCancelDialogContent(item.time),
          style: TextStyle(color: Colors.grey.shade600, height: 1.5),
        ),
        actionsPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              S.of(context).waitlistKeepBtn,
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(ctx);
              onCancel();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: Text(S.of(context).waitlistCancelBtn),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────
// TRẠNG THÁI B: CÓ CHỖ TRỐNG (Opened) — Có Countdown Timer
// ─────────────────────────────────────────────
class _WaitlistOpenedCard extends StatefulWidget {
  final WaitlistModel item;
  final VoidCallback onConfirmBook;
  final VoidCallback onDecline;

  const _WaitlistOpenedCard({
    required this.item,
    required this.onConfirmBook,
    required this.onDecline,
  });

  @override
  State<_WaitlistOpenedCard> createState() => _WaitlistOpenedCardState();
}

class _WaitlistOpenedCardState extends State<_WaitlistOpenedCard> {
  Timer? _timer;
  late Duration _remaining;
  bool _expired = false;

  @override
  void initState() {
    super.initState();
    _remaining = widget.item.holdUntil.difference(DateTime.now());
    if (_remaining.isNegative) {
      _remaining = Duration.zero;
      _expired = true;
    } else {
      _startTimer();
    }
  }

  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final remaining = widget.item.holdUntil.difference(DateTime.now());
      if (remaining.isNegative || remaining == Duration.zero) {
        setState(() {
          _remaining = Duration.zero;
          _expired = true;
        });
        _timer?.cancel();
        // Tự xóa thẻ sau khi timer hết
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) widget.onDecline();
        });
      } else {
        setState(() => _remaining = remaining);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      badge: _StatusBadge(
        label: S.of(context).waitlistStatusOpened,
        bgColor: AppColors.primary.withOpacity(0.12),
        textColor: AppColors.primary,
        icon: Icons.celebration_rounded,
        pulse: true,
      ),
      item: widget.item,
      highlightBorder: true,
      extraBody: Padding(
        padding: const EdgeInsets.only(top: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: _expired
                ? Colors.grey.shade100
                : AppColors.primary.withOpacity(0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _expired
                  ? Colors.grey.shade300
                  : AppColors.primary.withOpacity(0.3),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.timer_outlined,
                size: 18,
                color: _expired ? Colors.grey : AppColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _expired
                    ? Text(
                        S.of(context).waitlistHoldExpired,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                      )
                    : RichText(
                        text: TextSpan(
                          style: const TextStyle(fontSize: 13),
                          children: [
                            TextSpan(
                              text: S.of(context).waitlistHoldEndsIn,
                              style: TextStyle(color: Colors.grey.shade700),
                            ),
                            TextSpan(
                              text: _formatDuration(_remaining),
                              style: TextStyle(
                                color: _remaining.inSeconds <= 60
                                    ? Colors.red
                                    : AppColors.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
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
      actions: Padding(
        padding: const EdgeInsets.only(top: 14),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: widget.onDecline,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.grey.shade600,
                  side: BorderSide(color: Colors.grey.shade300),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                ),
                child: Text(
                  S.of(context).waitlistDeclineBtn,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _expired ? null : widget.onConfirmBook,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  elevation: 0,
                ),
                child: Text(
                  S.of(context).waitlistConfirmBookBtn,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED: Vỏ thẻ chung (Card Shell)
// ─────────────────────────────────────────────
class _CardShell extends StatelessWidget {
  final _StatusBadge badge;
  final WaitlistModel item;
  final Widget? extraBody;
  final Widget? actions;
  final bool highlightBorder;

  const _CardShell({
    required this.badge,
    required this.item,
    this.extraBody,
    this.actions,
    this.highlightBorder = false,
  });

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlightBorder
              ? AppColors.primary.withOpacity(0.4)
              : Colors.grey.shade200,
          width: highlightBorder ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: highlightBorder
                ? AppColors.primary.withOpacity(0.08)
                : Colors.black.withOpacity(0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Badge trạng thái góc phải
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                badge,
                Text(
                  _formatDate(item.date),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade500,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            const Divider(height: 1, color: Color(0xFFF0F0F0)),
            const SizedBox(height: 12),

            // Tên chi nhánh & địa chỉ
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.storefront_outlined,
                  size: 16,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.salonName,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item.address,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Khung giờ (in đậm)
            Row(
              children: [
                Icon(
                  Icons.access_time_filled,
                  size: 15,
                  color: AppColors.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  item.time,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '• ${_formatDate(item.date)}',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Kỹ thuật viên
            Row(
              children: [
                Icon(
                  Icons.person_outline,
                  size: 15,
                  color: Colors.grey.shade500,
                ),
                const SizedBox(width: 6),
                Text(
                  item.staffName,
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Dịch vụ — Wrap + Chip
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: item.services
                  .map(
                    (svc) => Chip(
                      label: Text(svc, style: const TextStyle(fontSize: 11)),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      visualDensity: VisualDensity.compact,
                      backgroundColor: Colors.grey.shade100,
                      side: BorderSide(color: Colors.grey.shade200),
                      padding: EdgeInsets.zero,
                    ),
                  )
                  .toList(),
            ),

            // Extra body (thời gian đăng ký / countdown)
            ?extraBody,

            // Action buttons
            ?actions,
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// SHARED: Badge trạng thái
// ─────────────────────────────────────────────
class _StatusBadge extends StatefulWidget {
  final String label;
  final Color bgColor;
  final Color textColor;
  final IconData icon;
  final bool pulse;

  const _StatusBadge({
    required this.label,
    required this.bgColor,
    required this.textColor,
    required this.icon,
    this.pulse = false,
  });

  @override
  State<_StatusBadge> createState() => _StatusBadgeState();
}

class _StatusBadgeState extends State<_StatusBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _anim = Tween<double>(
      begin: 1.0,
      end: 1.12,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
    if (widget.pulse) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Widget badge = Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: widget.bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(widget.icon, size: 12, color: widget.textColor),
          const SizedBox(width: 4),
          Text(
            widget.label,
            style: TextStyle(
              color: widget.textColor,
              fontSize: 11,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
    );

    if (widget.pulse) {
      return ScaleTransition(scale: _anim, child: badge);
    }
    return badge;
  }
}
