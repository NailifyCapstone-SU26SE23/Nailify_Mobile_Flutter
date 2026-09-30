import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/network/signalr_service.dart';
import '../../../../core/utils/price_formatter.dart';
import '../cubit/studio_cubit.dart';
import '../../data/models/customer_nail_model.dart';
import '../../../../core/utils/duration_formatter.dart';
import '../../data/datasources/studio_api_service.dart';
import '../../../../generated/l10n.dart';

class CustomerNailDetailPage extends StatefulWidget {
  final String id; // customerNailRequestId

  const CustomerNailDetailPage({super.key, required this.id});

  @override
  State<CustomerNailDetailPage> createState() => _CustomerNailDetailPageState();
}

class _CustomerNailDetailPageState extends State<CustomerNailDetailPage> {
  late final StudioDetailCubit _cubit;
  StreamSubscription? _quotedSub;
  StreamSubscription? _rejectedSub;

  @override
  void initState() {
    super.initState();
    _cubit = StudioDetailCubit()..fetchDetail(widget.id);
    final signalR = getIt<SignalRService>();
    _quotedSub = signalR.onCustomNailQuoted.listen((event) {
      if (mounted &&
          (event.customerNailRequestId == widget.id ||
              event.customerNailId == widget.id)) {
        _cubit.fetchDetail(widget.id);
      }
    });
    _rejectedSub = signalR.onCustomNailRejected.listen((event) {
      if (mounted && event.customerNailRequestId == widget.id) {
        _cubit.fetchDetail(widget.id);
      }
    });
  }

  @override
  void dispose() {
    _quotedSub?.cancel();
    _rejectedSub?.cancel();
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: const Color(0xFFFDFBF7),
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios_new_rounded,
              color: AppColors.primaryDark,
              size: 20,
            ),
            onPressed: () => context.pop(),
          ),
          title: Text(
            S.of(context).requestDetailTitle,
            style: const TextStyle(
              color: AppColors.primaryDark,
              fontWeight: FontWeight.w800,
              fontFamily: 'Georgia',
            ),
          ),
          centerTitle: true,
          backgroundColor: const Color(0xFFFDFBF7),
          elevation: 0,
          scrolledUnderElevation: 0,
        ),
        body: BlocBuilder<StudioDetailCubit, StudioDetailState>(
          builder: (context, state) {
            if (state is StudioDetailLoading) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }
            if (state is StudioDetailError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded, size: 48, color: Colors.grey),
                      const SizedBox(height: 12),
                      Text(
                        'Lỗi: ${state.message}',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                    ],
                  ),
                ),
              );
            }
            if (state is StudioDetailLoaded) {
              final nail = state.nail;
              final hasActionFooter = nail.status == 'Approved' || nail.status == 'Quoted';

              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ── Hero Header Image & Title Card ────────────────
                    _buildHeroHeader(nail),
                    const SizedBox(height: 18),

                    // ── Status Alerts & Pricing Cards ─────────────────
                    if (nail.status == 'Rejected' && nail.rejectReason != null)
                      _buildAlertBox(
                        Colors.red.shade600,
                        Icons.error_outline_rounded,
                        'Lý do từ chối:',
                        nail.rejectReason!,
                      ),

                    if ([
                      'Pending',
                      'PendingReview',
                      'Review',
                      'Assigned',
                      'Reviewed',
                    ].contains(nail.status))
                      _buildAlertBox(
                        Colors.orange.shade800,
                        Icons.hourglass_top_rounded,
                        'Đang xử lý:',
                        'Mẫu móng của bạn đang được chuyên viên tại tiệm đánh giá tính khả thi và báo giá.',
                      ),

                    if (nail.status == 'Quoted')
                      _buildQuotedStatusCard(nail),

                    if (nail.status == 'Approved')
                      _buildApprovedStatusCard(nail),

                    // ── Technical Details Card ────────────────────────
                    _buildTechnicalDetailsCard(nail),

                    // Extra bottom space so fixed footer never obscures list content
                    if (hasActionFooter) const SizedBox(height: 80),
                  ],
                ),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        bottomNavigationBar: BlocBuilder<StudioDetailCubit, StudioDetailState>(
          builder: (context, state) {
            if (state is StudioDetailLoaded) {
              return _buildFooterAction(context, state.nail) ??
                  const SizedBox.shrink();
            }
            return const SizedBox.shrink();
          },
        ),
      ),
    );
  }

  Widget _buildHeroHeader(CustomerNailModel nail) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EAE1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(19)),
            child: nail.imageUrl != null
                ? Image.network(
                    nail.imageUrl!,
                    width: double.infinity,
                    height: 260,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => _fallbackImage(),
                  )
                : _fallbackImage(),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nail.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    fontFamily: 'Georgia',
                    color: AppColors.primaryDark,
                  ),
                ),
                if (nail.salonName != null && nail.salonName!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(
                          color: Color(0xFFFFF0F5),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.storefront_rounded,
                          size: 16,
                          color: Color(0xFFE02B6D),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        nail.salonName!,
                        style: TextStyle(
                          color: Colors.grey.shade700,
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildApprovedStatusCard(CustomerNailModel nail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFECFDF5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFA7F3D0), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF10B981).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF10B981),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Đã duyệt khả thi!',
                style: TextStyle(
                  color: Color(0xFF065F46),
                  fontWeight: FontWeight.w900,
                  fontSize: 16.5,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFA7F3D0)),
          ),
          _buildStatusInfoRow(
            icon: Icons.sell_rounded,
            label: 'Giá mẫu:',
            value: PriceFormatter.format(nail.customerNailPrice),
            color: const Color(0xFF047857),
          ),
          if (nail.price > 0) ...[
            const SizedBox(height: 10),
            _buildStatusInfoRow(
              icon: Icons.auto_awesome_rounded,
              label: 'Phí custom:',
              value: PriceFormatter.format(nail.price),
              color: const Color(0xFF047857),
            ),
          ],
          const SizedBox(height: 10),
          _buildStatusInfoRow(
            icon: Icons.schedule_rounded,
            label: 'Thời gian dự kiến:',
            value: nail.estimatedDuration != null
                ? DurationFormatter.format(nail.estimatedDuration!)
                : '—',
            color: const Color(0xFF047857),
          ),
          if (nail.stylistName.isNotEmpty && nail.stylistName != 'Chưa gán') ...[
            const SizedBox(height: 10),
            _buildStatusInfoRow(
              icon: Icons.person_pin_rounded,
              label: 'Thợ chỉ định:',
              value: nail.stylistName,
              color: const Color(0xFF047857),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildQuotedStatusCard(CustomerNailModel nail) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFDE68A), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD97706).withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFD97706).withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.monetization_on_rounded,
                  color: Color(0xFFD97706),
                  size: 22,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Salon đã gửi Báo Giá!',
                style: TextStyle(
                  color: Color(0xFF92400E),
                  fontWeight: FontWeight.w900,
                  fontSize: 16.5,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(height: 1, color: Color(0xFFFDE68A)),
          ),
          _buildStatusInfoRow(
            icon: Icons.sell_rounded,
            label: 'Giá mẫu:',
            value: PriceFormatter.format(nail.customerNailPrice),
            color: const Color(0xFFB45309),
          ),
          if (nail.price > 0) ...[
            const SizedBox(height: 10),
            _buildStatusInfoRow(
              icon: Icons.auto_awesome_rounded,
              label: 'Phí custom:',
              value: PriceFormatter.format(nail.price),
              color: const Color(0xFFB45309),
            ),
          ],
          const SizedBox(height: 10),
          _buildStatusInfoRow(
            icon: Icons.schedule_rounded,
            label: 'Thời gian dự kiến:',
            value: nail.estimatedDuration != null
                ? DurationFormatter.format(nail.estimatedDuration!)
                : '—',
            color: const Color(0xFFB45309),
          ),
          if (nail.stylistName.isNotEmpty && nail.stylistName != 'Chưa gán') ...[
            const SizedBox(height: 10),
            _buildStatusInfoRow(
              icon: Icons.person_pin_rounded,
              label: 'Thợ chỉ định:',
              value: nail.stylistName,
              color: const Color(0xFFB45309),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildStatusInfoRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: color.withValues(alpha: 0.85),
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontWeight: FontWeight.bold,
            fontSize: 15,
          ),
        ),
      ],
    );
  }

  Widget _buildTechnicalDetailsCard(CustomerNailModel nail) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EAE1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(
                Icons.palette_rounded,
                size: 18,
                color: Color(0xFFE02B6D),
              ),
              SizedBox(width: 8),
              Text(
                'Chi tiết kỹ thuật',
                style: TextStyle(
                  fontSize: 15.5,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(height: 1, color: Color(0xFFF5F5F5)),
          const SizedBox(height: 12),
          _buildTechDetailRow(
            icon: Icons.category_rounded,
            label: S.of(context).nailShapeLabel,
            value: nail.shapeName,
          ),
          _buildTechDetailRow(
            icon: Icons.layers_rounded,
            label: S.of(context).nailSurfaceLabel,
            value: nail.surfaceName,
          ),
          _buildTechDetailRow(
            icon: Icons.extension_rounded,
            label: S.of(context).accessoriesTab,
            value: nail.accessoryNames.isEmpty
                ? S.of(context).noneLabel
                : nail.accessoryNames.join(', '),
            isLast: true,
          ),
        ],
      ),
    );
  }

  Widget _buildTechDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isLast = false,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF0F5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: const Color(0xFFE02B6D)),
              ),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 13.5,
                  color: Colors.grey.shade600,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  value,
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.bold,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Divider(height: 1, color: Color(0xFFF5F5F5)),
          ),
      ],
    );
  }

  Widget _fallbackImage() => Container(
        height: 260,
        width: double.infinity,
        color: const Color(0xFFFFF0F5),
        child: const Center(
          child: Icon(Icons.image_not_supported_rounded, size: 48, color: Color(0xFFFFD1DC)),
        ),
      );

  Widget _buildAlertBox(
    Color color,
    IconData icon,
    String title,
    String content,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            content,
            style: TextStyle(color: color, fontSize: 13.5, height: 1.4),
          ),
        ],
      ),
    );
  }

  bool _isRespondingQuote = false;

  Future<void> _handleRespondQuote(
    bool isAccepted, {
    String? rejectReason,
  }) async {
    setState(() => _isRespondingQuote = true);
    final api = StudioApiService();
    final res = await api.respondToQuote(
      widget.id,
      isAccepted: isAccepted,
      rejectReason: rejectReason,
    );
    if (!mounted) return;
    setState(() => _isRespondingQuote = false);

    final isOk = res['success'] == true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(res['message']?.toString() ?? ''),
        backgroundColor: isOk ? Colors.green.shade600 : Colors.red.shade400,
      ),
    );

    if (isOk) {
      _cubit.fetchDetail(widget.id);
    }
  }

  Future<void> _showRejectReasonDialog(BuildContext context) async {
    final controller = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogCtx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: const Text(
            'Từ chối báo giá',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          content: TextField(
            controller: controller,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Nhập lý do từ chối (không bắt buộc)...',
              border: OutlineInputBorder(),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('Hủy'),
            ),
            ElevatedButton(
              onPressed: () =>
                  Navigator.of(dialogCtx).pop(controller.text.trim()),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
              child: const Text('Từ chối'),
            ),
          ],
        );
      },
    );

    if (result != null && mounted) {
      await _handleRespondQuote(false, rejectReason: result);
    }
  }

  /// Footer action button:
  /// - Approved => "Đặt lịch ngay" -> forward data sang CustomNailBookingPage
  /// - Quoted => "Từ chối báo giá" & "Đồng ý báo giá"
  Widget? _buildFooterAction(BuildContext context, CustomerNailModel nail) {
    if (nail.status == 'Approved') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Container(
            height: 50,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(25),
              gradient: const LinearGradient(
                colors: [Color(0xFFFF4081), Color(0xFFD81B60)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFD81B60).withValues(alpha: 0.35),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () => _openCustomNailBooking(context, nail),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                foregroundColor: Colors.white,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(25),
                ),
                elevation: 0,
              ),
              icon: const Icon(Icons.calendar_month_rounded, color: Colors.white, size: 20),
              label: const Text(
                'Đặt lịch ngay',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ),
      );
    }

    if (nail.status == 'Quoted') {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: _isRespondingQuote
              ? const SizedBox(
                  height: 48,
                  child: Center(child: CircularProgressIndicator()),
                )
              : Row(
                  children: [
                    Expanded(
                      flex: 4,
                      child: OutlinedButton(
                        onPressed: () => _showRejectReasonDialog(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red.shade600,
                          side: BorderSide(color: Colors.red.shade300),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Từ chối',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 6,
                      child: ElevatedButton.icon(
                        onPressed: () => _handleRespondQuote(true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        icon: const Icon(
                          Icons.check_circle_outline_rounded,
                          size: 20,
                        ),
                        label: const Text(
                          'Đồng ý báo giá',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      );
    }

    return null;
  }

  void _openCustomNailBooking(BuildContext context, CustomerNailModel nail) {
    context.push(
      '/custom-nail-booking',
      extra: {
        'nail': nail,
        'shapeMethodConfigId': nail.shapeMethodConfigId,
        'shapeMethodName': nail.shapeMethodName,
        'shapeMethodPrice': nail.shapeMethodPrice,
        'shapeMethodDuration': nail.shapeMethodDuration,
      },
    );
  }
}
