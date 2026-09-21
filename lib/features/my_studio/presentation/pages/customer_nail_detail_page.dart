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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back_ios,
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
          backgroundColor: Colors.white,
          elevation: 0,
        ),
        body: BlocBuilder<StudioDetailCubit, StudioDetailState>(
          builder: (context, state) {
            if (state is StudioDetailLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state is StudioDetailError) {
              return Center(child: Text('Lỗi: ${state.message}'));
            }
            if (state is StudioDetailLoaded) {
              final nail = state.nail;
              return SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Ảnh mẫu nail
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: nail.imageUrl != null
                          ? Image.network(
                              nail.imageUrl!,
                              width: double.infinity,
                              height: 250,
                              fit: BoxFit.cover,
                              errorBuilder: (_, _, _) => _fallbackImage(),
                            )
                          : _fallbackImage(),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      nail.name,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Tên salon
                    if (nail.salonName != null && nail.salonName!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.storefront,
                              size: 18,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              nail.salonName!,
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),

                    // --- TRẠNG THÁI: TỪ CHỐI ---
                    if (nail.status == 'Rejected' && nail.rejectReason != null)
                      _buildAlertBox(
                        Colors.red,
                        Icons.error_outline,
                        'Lý do từ chối:',
                        nail.rejectReason!,
                      ),

                    // --- TRẠNG THÁI: ĐANG XỬ LÝ ---
                    if ([
                      'Pending',
                      'PendingReview',
                      'Review',
                      'Assigned',
                      'Reviewed',
                    ].contains(nail.status))
                      _buildAlertBox(
                        Colors.orange,
                        Icons.hourglass_top,
                        'Đang xử lý:',
                        'Mẫu móng của bạn đang được chuyên viên tại tiệm đánh giá tính khả thi và báo giá.',
                      ),

                    // --- TRẠNG THÁI: CHỜ XÁC NHẬN BÁO GIÁ (QUOTED) ---
                    if (nail.status == 'Quoted')
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade50,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.amber.shade300),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.monetization_on_rounded,
                                  color: Colors.amber.shade800,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Salon đã gửi Báo Giá!',
                                  style: TextStyle(
                                    color: Colors.amber.shade900,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.amber),
                            const SizedBox(height: 8),
                            _buildPriceDurationRow(
                              'Giá mẫu:',
                              PriceFormatter.format(nail.customerNailPrice),
                            ),
                            if (nail.price > 0) ...[
                              const SizedBox(height: 8),
                              _buildPriceDurationRow(
                                'Phí custom:',
                                PriceFormatter.format(nail.price),
                              ),
                            ],
                            const SizedBox(height: 8),
                            _buildPriceDurationRow(
                              'Thời gian dự kiến:',
                              DurationFormatter.format(nail.duration),
                            ),
                            if (nail.stylistName.isNotEmpty) ...[
                              const SizedBox(height: 8),
                              _buildPriceDurationRow(
                                'Thợ chỉ định:',
                                nail.stylistName,
                              ),
                            ],
                          ],
                        ),
                      ),

                    // --- TRẠNG THÁI: ĐÃ DUYỆT (APPROVED) ---
                    if (nail.status == 'Approved')
                      Container(
                        margin: const EdgeInsets.only(bottom: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.check_circle, color: Colors.green),
                                SizedBox(width: 8),
                                Text(
                                  'Đã duyệt khả thi!',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const Divider(color: Colors.green),
                            const SizedBox(height: 8),
                            _buildPriceDurationRow(
                              'Giá:',
                              PriceFormatter.format(nail.customerNailPrice),
                            ),
                            if (nail.price > 0) ...[
                              const SizedBox(height: 8),
                              _buildPriceDurationRow(
                                'Phí custom:',
                                PriceFormatter.format(nail.price),
                              ),
                            ],
                            const SizedBox(height: 8),
                            _buildPriceDurationRow(
                              'Thời gian dự kiến:',
                              DurationFormatter.format(nail.duration),
                            ),
                            const SizedBox(height: 8),
                            _buildPriceDurationRow(
                              'Thợ chỉ định:',
                              nail.stylistName,
                            ),
                          ],
                        ),
                      ),

                    // --- CHI TIẾT KỸ THUẬT ---
                    const Text(
                      'Chi tiết kỹ thuật',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.borderLight),
                      ),
                      child: Column(
                        children: [
                          _buildRow(
                            S.of(context).nailShapeLabel,
                            nail.shapeName,
                          ),
                          _buildRow(
                            S.of(context).nailSurfaceLabel,
                            nail.surfaceName,
                          ),
                          _buildRow(
                            S.of(context).accessoriesTab,
                            nail.accessoryNames.isEmpty
                                ? S.of(context).noneLabel
                                : nail.accessoryNames.join(', '),
                            isLast: true,
                          ),
                        ],
                      ),
                    ),
                    if (nail.status == 'Approved' ||
                        nail.status == 'Quoted') ...[
                      const SizedBox(height: 20),
                    ],
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

  Widget _fallbackImage() => Container(
    height: 250,
    width: double.infinity,
    color: Colors.pink.shade50,
    child: const Icon(Icons.image, size: 50, color: Colors.grey),
  );

  Widget _buildAlertBox(
    Color color,
    IconData icon,
    String title,
    String content,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color),
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(color: color, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(content, style: TextStyle(color: color)),
        ],
      ),
    );
  }

  Widget _buildPriceDurationRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(color: Colors.green)),
        Text(
          value,
          style: const TextStyle(
            color: Colors.green,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildRow(String label, String value, {bool isLast = false}) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: Colors.grey)),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
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
        padding: const EdgeInsets.all(20),
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
          child: ElevatedButton.icon(
            onPressed: () => _openCustomNailBooking(context, nail),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.calendar_month, color: Colors.white),
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
