import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/paginated_response.dart';
import '../../data/datasources/studio_api_service.dart';
import '../../data/models/customer_nail_model.dart' as request_models;
import '../../../nails/data/models/customer_nail_models.dart' as nail_models;
import '../../../nails/data/repositories/customer_nail_repository.dart';
import '../widgets/studio_nail_card.dart';

class CustomerNailRequestsTab extends StatefulWidget {
  const CustomerNailRequestsTab({super.key});

  @override
  State<CustomerNailRequestsTab> createState() =>
      _CustomerNailRequestsTabState();
}

class _CustomerNailRequestsTabState extends State<CustomerNailRequestsTab> {
  final StudioApiService _apiService = StudioApiService();
  final CustomerNailRepository _customerNailRepository =
      getIt<CustomerNailRepository>();
  late Future<List<request_models.CustomerNailModel>> _future;
  String? _statusFilter;

  static const Map<String, String> _statusLabels = {
    'Pending': 'Chờ duyệt',
    'PendingReview': 'Pending review',
    'Review': 'Đang thẩm định',
    'Assigned': 'Đã gán thợ',
    'Reviewed': 'Thợ đã đánh giá',
    'Quoted': 'Đã báo giá',
    'Approved': 'Sẵn sàng đặt lịch',
    'Rejected': 'Bị từ chối',
  };

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    setState(() {
      _future = _apiService.getMyNailRequests(pageSize: 100);
    });
  }

  List<request_models.CustomerNailModel> _filterRequests(
    List<request_models.CustomerNailModel> requests,
  ) {
    final status = _statusFilter;
    if (status == null) return requests;
    return requests.where((request) => request.status == status).toList();
  }

  // BottomSheet chọn mẫu móng có hình ảnh và thanh tìm kiếm cực kỳ trực quan
  Future<nail_models.CustomerNailModel?> _showNailSelectorBottomSheet(
    BuildContext context,
    List<nail_models.CustomerNailModel> nails,
  ) async {
    return showModalBottomSheet<nail_models.CustomerNailModel>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredNails = nails
                .where((nail) =>
                    nail.name.toLowerCase().contains(searchQuery.toLowerCase()))
                .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.65,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Chọn mẫu móng thiết kế',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Tìm mẫu móng...',
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 18, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (val) {
                          setSheetState(() => searchQuery = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: filteredNails.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.spa_outlined,
                                        size: 48, color: Colors.grey),
                                    const SizedBox(height: 8),
                                    Text('Không tìm thấy mẫu móng nào',
                                        style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: filteredNails.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(
                                        color: Color(0xFFFFF0F5), height: 1),
                                itemBuilder: (context, index) {
                                  final nail = filteredNails[index];
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 4, horizontal: 8),
                                    leading: ClipRRect(
                                      borderRadius: BorderRadius.circular(10),
                                      child: SizedBox(
                                        width: 48,
                                        height: 48,
                                        child: nail.imageUrl.isEmpty
                                            ? Container(
                                                color: AppColors.primary
                                                    .withValues(alpha: 0.08),
                                                child: const Icon(
                                                    Icons.spa_rounded,
                                                    color: AppColors.primary,
                                                    size: 22),
                                              )
                                            : Image.network(
                                                nail.imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) =>
                                                    Container(
                                                  color: const Color(0xFFF5F5F7),
                                                  child: const Icon(
                                                      Icons.broken_image_rounded,
                                                      color: Colors.grey,
                                                      size: 20),
                                                ),
                                              ),
                                      ),
                                    ),
                                    title: Text(
                                      nail.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    trailing: const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.textSecondary),
                                    onTap: () =>
                                        Navigator.of(context).pop(nail),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  // BottomSheet chọn salon trực quan có địa chỉ và tìm kiếm nhanh
  Future<Map<String, dynamic>?> _showSalonSelectorBottomSheet(
    BuildContext context,
    List<Map<String, dynamic>> salons,
  ) async {
    return showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder: (context) {
        String searchQuery = "";
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final filteredSalons = salons
                .where((salon) {
                  final name = (salon['name']?.toString() ??
                          salon['salonName']?.toString() ??
                          '')
                      .toLowerCase();
                  return name.contains(searchQuery.toLowerCase());
                })
                .toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.55,
              minChildSize: 0.3,
              maxChildSize: 0.8,
              expand: false,
              builder: (context, scrollController) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Chọn chi nhánh Salon',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                          letterSpacing: -0.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText: 'Tìm kiếm salon...',
                          prefixIcon: const Icon(Icons.search_rounded,
                              size: 18, color: AppColors.textSecondary),
                          filled: true,
                          fillColor: const Color(0xFFF5F5F7),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(vertical: 0),
                        ),
                        onChanged: (val) {
                          setSheetState(() => searchQuery = val);
                        },
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: filteredSalons.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(Icons.storefront_rounded,
                                        size: 48, color: Colors.grey),
                                    const SizedBox(height: 8),
                                    Text('Không tìm thấy salon nào',
                                        style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 13)),
                                  ],
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: filteredSalons.length,
                                separatorBuilder: (context, index) =>
                                    const Divider(
                                        color: Color(0xFFFFF0F5), height: 1),
                                itemBuilder: (context, index) {
                                  final salon = filteredSalons[index];
                                  final name = salon['name']?.toString() ??
                                      salon['salonName']?.toString() ??
                                      'Salon Nailify';
                                  final address = salon['address']?.toString() ??
                                      salon['salonAddress']?.toString() ??
                                      'Địa chỉ đang cập nhật';

                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(
                                        vertical: 4, horizontal: 8),
                                    leading: Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: AppColors.primary
                                            .withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: const Icon(
                                        Icons.storefront_rounded,
                                        color: AppColors.primary,
                                        size: 22,
                                      ),
                                    ),
                                    title: Text(
                                      name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: Text(
                                        address,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey.shade600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    trailing: const Icon(
                                        Icons.chevron_right_rounded,
                                        color: AppColors.textSecondary),
                                    onTap: () =>
                                        Navigator.of(context).pop(salon),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _openSubmitRequestDialog() async {
    try {
      final results = await Future.wait<dynamic>([
        _customerNailRepository.getCustomerNails(page: 1, pageSize: 100),
        _apiService.getSalons(),
      ]);

      final nails =
          (results[0] as PaginatedResponse<nail_models.CustomerNailModel>)
              .items;
      final salons = results[1] as List<dynamic>;

      if (!mounted) return;

      final submitted = await showDialog<bool>(
        context: context,
        builder: (context) {
          nail_models.CustomerNailModel? selectedNail;
          Map<String, dynamic>? selectedSalon;
          var isSubmitting = false;

          return StatefulBuilder(
            builder: (context, setDialogState) {
              final salonOptions = salons
                  .whereType<Map>()
                  .map((salon) => Map<String, dynamic>.from(salon))
                  .where(
                    (salon) => (salon['salonId']?.toString() ?? '').isNotEmpty,
                  )
                  .toList();

              Future<void> submit() async {
                if (selectedNail == null || selectedSalon == null) return;
                setDialogState(() => isSubmitting = true);
                try {
                  await _apiService.submitNailReview(
                    selectedNail!.customerNailId.toString(),
                    selectedSalon!['salonId']?.toString() ?? '',
                  );
                  if (context.mounted) Navigator.of(context).pop(true);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Gửi yêu cầu thất bại: $e')),
                    );
                  }
                } finally {
                  if (context.mounted) {
                    setDialogState(() => isSubmitting = false);
                  }
                }
              }

              return Dialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(24),
                ),
                backgroundColor: Colors.white,
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Gửi yêu cầu thiết kế',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        
                        // Bộ chọn mẫu móng trực quan thay thế DropdownButtonFormField
                        GestureDetector(
                          onTap: isSubmitting
                              ? null
                              : () async {
                                  final result = await _showNailSelectorBottomSheet(context, nails);
                                  if (result != null) {
                                    setDialogState(() => selectedNail = result);
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade100, width: 1),
                            ),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: SizedBox(
                                    width: 40,
                                    height: 40,
                                    child: selectedNail == null
                                        ? Container(
                                            color: Colors.grey.shade300,
                                            child: const Icon(Icons.spa_rounded, color: Colors.white, size: 20),
                                          )
                                        : (selectedNail!.imageUrl.isEmpty
                                            ? Container(
                                                color: AppColors.primary.withValues(alpha: 0.1),
                                                child: const Icon(Icons.spa_rounded, color: AppColors.primary, size: 20),
                                              )
                                            : Image.network(
                                                selectedNail!.imageUrl,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Container(
                                                  color: const Color(0xFFE0E0E0),
                                                  child: const Icon(Icons.broken_image_rounded, color: Colors.grey, size: 18),
                                                ),
                                              )),
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Mẫu móng *',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        selectedNail?.name ?? 'Chọn mẫu móng...',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: selectedNail != null ? FontWeight.bold : FontWeight.normal,
                                          color: selectedNail != null ? AppColors.textPrimary : AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_right_rounded,
                                  color: AppColors.textSecondary,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        
                        // Bộ chọn Salon trực quan thay thế DropdownButtonFormField
                        GestureDetector(
                          onTap: isSubmitting
                              ? null
                              : () async {
                                  final result = await _showSalonSelectorBottomSheet(context, salonOptions);
                                  if (result != null) {
                                    setDialogState(() => selectedSalon = result);
                                  }
                                },
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF5F5F7),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: Colors.grey.shade100, width: 1),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: selectedSalon == null
                                        ? Colors.grey.shade300
                                        : AppColors.primary.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Icon(
                                    Icons.location_on_rounded,
                                    color: selectedSalon == null ? Colors.white : AppColors.primary,
                                    size: 20,
                                  ),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      const Text(
                                        'Salon *',
                                        style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        selectedSalon != null
                                            ? (selectedSalon!['name']?.toString() ??
                                                selectedSalon!['salonName']?.toString() ??
                                                'Salon')
                                            : 'Chọn chi nhánh Salon...',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: selectedSalon != null ? FontWeight.bold : FontWeight.normal,
                                          color: selectedSalon != null ? AppColors.textPrimary : AppColors.textSecondary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(
                                  Icons.keyboard_arrow_right_rounded,
                                  color: AppColors.textSecondary,
                                  size: 22,
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        
                        // Hàng Nút Bấm
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  side: const BorderSide(color: Color(0xFFE0E0E0), width: 1.2),
                                ),
                                onPressed: isSubmitting
                                    ? null
                                    : () => Navigator.of(context).pop(false),
                                child: const Text(
                                  'Hủy',
                                  style: TextStyle(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primary,
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 0,
                                ),
                                onPressed:
                                    isSubmitting ||
                                        selectedNail == null ||
                                        selectedSalon == null
                                    ? null
                                    : submit,
                                child: isSubmitting
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text(
                                        'Gửi',
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          );
        },
      );

      if (submitted == true) {
        _load();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Đã gửi yêu cầu thành công.')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Không thể tải form: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openSubmitRequestDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.send_rounded, size: 18),
        label: const Text(
          'Gửi yêu cầu',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100, width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _statusFilter,
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        style: const TextStyle(
                          color: AppColors.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                        icon: const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          color: AppColors.textSecondary,
                          size: 22,
                        ),
                        hint: const Text(
                          'Tất cả trạng thái',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        isExpanded: true,
                        items: [
                          const DropdownMenuItem<String?>(
                            value: null,
                            child: Text('Tất cả trạng thái'),
                          ),
                          ..._statusLabels.entries.map(
                            (entry) => DropdownMenuItem<String?>(
                              value: entry.key,
                              child: Text(entry.value),
                            ),
                          ),
                        ],
                        onChanged: (value) =>
                            setState(() => _statusFilter = value),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: FutureBuilder<List<request_models.CustomerNailModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Lỗi: ${snapshot.error}',
                          style: const TextStyle(color: Colors.red),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  );
                }

                final requests = _filterRequests(snapshot.data ?? []);
                if (requests.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.assignment_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có yêu cầu nào.',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return RefreshIndicator(
                  onRefresh: () async => _load(),
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    physics: const AlwaysScrollableScrollPhysics(),
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final request = requests[index];
                      return StudioNailCard(
                        nail: request,
                        onTap: () => context.push(
                          '/my-studio/${request.customerNailRequestId}',
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
