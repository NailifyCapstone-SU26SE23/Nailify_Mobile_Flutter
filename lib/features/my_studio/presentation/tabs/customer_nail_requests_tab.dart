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
                  borderRadius: BorderRadius.circular(20),
                ),
                backgroundColor: Colors.white,
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
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      DropdownButtonFormField<nail_models.CustomerNailModel>(
                        initialValue: selectedNail,
                        decoration: InputDecoration(
                          labelText: 'Mẫu móng *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        items: nails
                            .map(
                              (nail) => DropdownMenuItem(
                                value: nail,
                                child: Text(nail.name),
                              ),
                            )
                            .toList(),
                        onChanged: isSubmitting
                            ? null
                            : (value) =>
                                  setDialogState(() => selectedNail = value),
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSalon?['salonId']?.toString(),
                        decoration: InputDecoration(
                          labelText: 'Salon *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: Colors.grey.shade300),
                          ),
                        ),
                        items: salonOptions
                            .map(
                              (salon) => DropdownMenuItem(
                                value: salon['salonId']?.toString(),
                                child: Text(
                                  salon['name']?.toString() ??
                                      salon['salonName']?.toString() ??
                                      salon['salonId']?.toString() ??
                                      'Salon',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: isSubmitting
                            ? null
                            : (value) => setDialogState(() {
                                selectedSalon = null;
                                for (final salon in salonOptions) {
                                  if (salon['salonId']?.toString() == value) {
                                    selectedSalon = salon;
                                    break;
                                  }
                                }
                              }),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              style: OutlinedButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 14,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                side: BorderSide(color: Colors.grey.shade300),
                              ),
                              onPressed: isSubmitting
                                  ? null
                                  : () => Navigator.of(context).pop(false),
                              child: const Text(
                                'Hủy',
                                style: TextStyle(
                                  color: AppColors.textSecondary,
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
                                  borderRadius: BorderRadius.circular(12),
                                ),
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
                                      ),
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
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
      floatingActionButton: FloatingActionButton(
        onPressed: _openSubmitRequestDialog,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        tooltip: 'Gửi yêu cầu mới',
        child: const Icon(Icons.add),
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
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String?>(
                        value: _statusFilter,
                        hint: const Text(
                          'Tất cả trạng thái',
                          overflow: TextOverflow.ellipsis,
                        ),
                        icon: const Icon(
                          Icons.filter_list,
                          size: 20,
                          color: AppColors.textSecondary,
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
