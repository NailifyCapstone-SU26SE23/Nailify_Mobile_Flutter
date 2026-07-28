import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../../nails/data/models/shape_method_config_model.dart';
import '../cubit/studio_cubit.dart';
import '../../data/models/customer_nail_model.dart';
import '../../../../core/utils/duration_formatter.dart';

class CustomerNailDetailPage extends StatefulWidget {
  final String id; // customerNailRequestId

  const CustomerNailDetailPage({super.key, required this.id});

  @override
  State<CustomerNailDetailPage> createState() => _CustomerNailDetailPageState();
}

class _CustomerNailDetailPageState extends State<CustomerNailDetailPage> {
  ShapeMethodConfigModel? _selectedShapeMethod;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => StudioDetailCubit()..fetchDetail(widget.id),
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, size: 20),
            onPressed: () => context.pop(),
          ),
          title: const Text(
            'Chi tiết yêu cầu duyệt',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
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

                    // --- TRẠNG THÁI: ĐÃ DUYỆT ---
                    if (nail.status == 'Approved' || nail.status == 'Quoted')
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
                              'Báo giá dự kiến:',
                              PriceFormatter.format(nail.price),
                            ),
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
                          _buildRow('Phom móng', nail.shapeName),
                          _buildRow('Bề mặt', nail.surfaceName),
                          _buildRow(
                            'Phụ kiện',
                            nail.accessoryNames.isEmpty
                                ? 'Không'
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
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
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

  /// Footer action button:
  /// - Approved => "Đặt lịch ngay" -> forward data sang CustomNailBookingPage
  Widget? _buildFooterAction(BuildContext context, CustomerNailModel nail) {
    if (nail.status == 'Approved' || nail.status == 'Quoted') {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton.icon(
          onPressed: () {
            // Forward data cần thiết sang trang đặt lịch custom nail
            context.push(
              '/custom-nail-booking',
              extra: {
                'nail': nail,
                'shapeMethodConfigId':
                    _selectedShapeMethod?.shapeMethodConfigId,
                'shapeMethodName': _selectedShapeMethod?.name,
                'shapeMethodPrice': _selectedShapeMethod?.price,
                'shapeMethodDuration': _selectedShapeMethod?.duration,
              },
            );
          },
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
      );
    }
    return null;
  }
}
