// ====================================================================
// FILE: lib/features/my_booking/presentation/widgets/waitlist_card.dart
// Mô tả: Widget thẻ lịch chờ (Waitlist Card) với 2 trạng thái
// ====================================================================

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../../../generated/l10n.dart';
import '../../data/datasources/waitlist_api_service.dart';
import '../../data/models/waitlist_model.dart';
import 'waitlist_checkout_sheet.dart';

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
class _WaitlistPendingCard extends StatefulWidget {
  final WaitlistModel item;
  final VoidCallback onCancel;

  const _WaitlistPendingCard({required this.item, required this.onCancel});

  @override
  State<_WaitlistPendingCard> createState() => _WaitlistPendingCardState();
}

class _WaitlistPendingCardState extends State<_WaitlistPendingCard> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    // Tự động cập nhật giao diện mỗi 1 giây để thời gian chờ tăng liên tục theo thời gian thực khi treo máy
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _timeSince(BuildContext context, DateTime from) {
    final diff = DateTime.now().difference(from);
    return DurationFormatter.formatDiff(diff, context: context);
  }

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      onTap: () => _openDetailSheet(context),
      badge: _StatusBadge(
        label: S.of(context).waitlistStatusPending,
        bgColor: Colors.blue.shade50,
        textColor: Colors.blue.shade700,
        icon: Icons.hourglass_top_rounded,
      ),
      item: widget.item,
      extraBody: Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          children: [
            Icon(Icons.schedule, size: 14, color: Colors.grey.shade400),
            const SizedBox(width: 4),
            Text(
              '${S.of(context).waitlistRegisteredAt}${_timeSince(context, widget.item.registeredAt)}',
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

  void _openDetailSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          WaitlistCheckoutSheet(waitlist: widget.item, onSuccess: () {}),
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
          S.of(context).waitlistCancelDialogContent(widget.item.time),
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
              widget.onCancel();
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
        bgColor: AppColors.primary.withValues(alpha: 0.12),
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
                : AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _expired
                  ? Colors.grey.shade300
                  : AppColors.primary.withValues(alpha: 0.3),
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
                child: Text(S.of(context).waitlistDeclineBtn),
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
  final VoidCallback? onTap;

  const _CardShell({
    required this.badge,
    required this.item,
    this.extraBody,
    this.actions,
    this.highlightBorder = false,
    this.onTap,
  });

  String _formatDate(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  String _clean(String? s) {
    if (s == null) return '';
    final trimmed = s.trim();
    if (trimmed.toLowerCase() == 'string') return '';
    return trimmed;
  }

  String _getCleanTitle(WaitlistItemModel it) {
    final vName = _clean(it.nailVariantName);
    if (vName.isNotEmpty) return vName;

    final cName = _clean(it.customerNailName);
    if (cName.isNotEmpty) return cName;

    final sName = _clean(it.serviceName);
    if (sName.isNotEmpty) return sName;

    final shapeName = _clean(it.shapeMethodConfigName);
    if (shapeName.isNotEmpty) return 'Làm dáng móng: $shapeName';

    if (item.services.isNotEmpty) {
      return item.services.first;
    }

    return 'Dịch vụ làm móng';
  }

  String? _getCleanImgUrl(WaitlistItemModel it) {
    final vUrl = _clean(it.nailVariantImageUrl);
    if (vUrl.startsWith('http')) return vUrl;
    final cUrl = _clean(it.customerNailImageUrl);
    if (cUrl.startsWith('http')) return cUrl;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: highlightBorder
              ? AppColors.primary.withValues(alpha: 0.4)
              : Colors.grey.shade200,
          width: highlightBorder ? 1.5 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: highlightBorder
                ? AppColors.primary.withValues(alpha: 0.08)
                : Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
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
                    Row(
                      children: [
                        Text(
                          _formatDate(item.date),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade500,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        if (onTap != null) ...[
                          const SizedBox(width: 4),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 18,
                            color: Colors.grey.shade400,
                          ),
                        ],
                      ],
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
                          if (item.address.isNotEmpty) ...[
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
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Khung giờ (in đậm)
                Row(
                  children: [
                    const Icon(
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
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 12,
                      ),
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
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Dịch vụ / Mẫu móng — Chi tiết
                if (item.waitlistItems.isNotEmpty) ...[
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF7F9),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: const Color(0xFFFCE3EC)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ...item.waitlistItems.map((it) {
                          final imgUrl = _getCleanImgUrl(it);
                          final title = _getCleanTitle(it);
                          final shapeName = _clean(it.shapeMethodConfigName);

                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 3),
                            child: Row(
                              children: [
                                if (imgUrl != null && imgUrl.isNotEmpty)
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(6),
                                    child: Image.network(
                                      imgUrl,
                                      width: 24,
                                      height: 24,
                                      fit: BoxFit.cover,
                                      errorBuilder: (_, __, ___) => const Icon(
                                        Icons.spa_rounded,
                                        size: 16,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  )
                                else
                                  const Icon(
                                    Icons.check_circle_outline_rounded,
                                    size: 16,
                                    color: AppColors.primary,
                                  ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    title +
                                        (shapeName.isNotEmpty
                                            ? ' ($shapeName)'
                                            : ''),
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.textPrimary,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (it.quantity != null && it.quantity! > 1)
                                  Text(
                                    'x${it.quantity}',
                                    style: const TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.primary,
                                    ),
                                  ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                ] else if (item.services.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: item.services
                        .map(
                          (svc) => Chip(
                            label: Text(
                              svc,
                              style: const TextStyle(fontSize: 11),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                            backgroundColor: Colors.grey.shade100,
                            side: BorderSide(color: Colors.grey.shade200),
                            padding: EdgeInsets.zero,
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 8),
                ],

                // Nút Thay đổi dịch vụ
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () => _handleChangeServices(context),
                    borderRadius: BorderRadius.circular(8),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.edit_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            'Thay đổi dịch vụ',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                // Extra body (thời gian đăng ký / countdown)
                ?extraBody,

                // Action buttons
                ?actions,
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleChangeServices(BuildContext context) async {
    final String waitlistId = item.id;
    if (waitlistId.isNotEmpty) {
      try {
        await WaitlistApiService().cancelWaitlist(waitlistId);
      } catch (e) {
        debugPrint('[WaitlistCard] cancelWaitlist error before re-booking: $e');
      }
    }

    if (!context.mounted) return;

    final items = item.waitlistItems;
    final String? salonId = item.salonId;
    final String salonName = item.salonName;
    final String? artistId = item.staffId;
    final String artistName = item.staffName;

    final List<String> serviceIds = items
        .map((e) => e.serviceId)
        .whereType<String>()
        .where((s) => s.trim().isNotEmpty)
        .toList();

    int? nailVariantId;
    String? nailVariantName;
    String? nailVariantImageUrl;
    for (final it in items) {
      if (it.nailVariantId != null && it.nailVariantId! > 0) {
        nailVariantId = it.nailVariantId;
        nailVariantName = it.nailVariantName;
        nailVariantImageUrl = it.nailVariantImageUrl;
        break;
      }
    }

    int? customerNailId;
    String? customerNailName;
    String? customerNailImageUrl;
    for (final it in items) {
      if (it.customerNailId != null && it.customerNailId! > 0) {
        customerNailId = it.customerNailId;
        customerNailName = it.customerNailName;
        customerNailImageUrl = it.customerNailImageUrl;
        break;
      }
    }

    String? customerNailRequestId;
    for (final it in items) {
      if (it.customerNailRequestId != null &&
          it.customerNailRequestId!.trim().isNotEmpty) {
        customerNailRequestId = it.customerNailRequestId;
        break;
      }
    }

    int? shapeConfigId;
    String? shapeConfigName;
    for (final it in items) {
      if (it.shapeMethodConfigId != null && it.shapeMethodConfigId! > 0) {
        shapeConfigId = it.shapeMethodConfigId;
        shapeConfigName = it.shapeMethodConfigName;
        break;
      }
    }

    final Map<String, dynamic> bookingExtra = {
      if (salonId != null && salonId.isNotEmpty)
        'salon': {'salonId': salonId, 'name': salonName},
      if (artistId != null && artistId.isNotEmpty)
        'artist': {
          'nailArtistId': artistId,
          'fullName': artistName,
          'salonId': salonId ?? '',
        },
      'date': item.date,
      'time': item.time,
      'serviceIds': serviceIds,
      if (nailVariantId != null) 'nailVariantId': nailVariantId,
      if (nailVariantName != null) 'nailVariantName': nailVariantName,
      if (nailVariantImageUrl != null)
        'nailVariantImageUrl': nailVariantImageUrl,
      if (customerNailId != null) 'customerNailId': customerNailId,
      if (customerNailName != null) 'customerNailName': customerNailName,
      if (customerNailImageUrl != null)
        'customerNailImageUrl': customerNailImageUrl,
      if (customerNailRequestId != null)
        'customerNailRequestId': customerNailRequestId,
      if (shapeConfigId != null) 'shapeMethodConfigId': shapeConfigId,
      if (shapeConfigName != null) 'shapeMethodName': shapeConfigName,
      'waitlistItems': items.map((e) => e.toJson()).toList(),
    };

    context.push('/home-booking', extra: bookingExtra);
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
