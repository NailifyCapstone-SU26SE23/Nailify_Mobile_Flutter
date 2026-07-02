import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

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
    'Pending': 'Pending',
    'PendingReview': 'Pending review',
    'Review': 'Review',
    'Assigned': 'Assigned',
    'Reviewed': 'Reviewed',
    'Quoted': 'Quoted',
    'Approved': 'Approved',
    'Rejected': 'Rejected',
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
                      SnackBar(content: Text('Submit request failed: $e')),
                    );
                  }
                } finally {
                  if (context.mounted) {
                    setDialogState(() => isSubmitting = false);
                  }
                }
              }

              return AlertDialog(
                title: const Text('Submit nail request'),
                content: SizedBox(
                  width: MediaQuery.of(context).size.width * 0.9,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      DropdownButtonFormField<nail_models.CustomerNailModel>(
                        initialValue: selectedNail,
                        decoration: const InputDecoration(
                          labelText: 'Customer nail',
                          border: OutlineInputBorder(),
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
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: selectedSalon?['salonId']?.toString(),
                        decoration: const InputDecoration(
                          labelText: 'Salon',
                          border: OutlineInputBorder(),
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
                    ],
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: isSubmitting
                        ? null
                        : () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed:
                        isSubmitting ||
                            selectedNail == null ||
                            selectedSalon == null
                        ? null
                        : submit,
                    child: isSubmitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Submit'),
                  ),
                ],
              );
            },
          );
        },
      );

      if (submitted == true) {
        _load();
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Request submitted.')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to load submit form: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String?>(
                  initialValue: _statusFilter,
                  decoration: InputDecoration(
                    labelText: 'Filter by status',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    isDense: true,
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('All statuses'),
                    ),
                    ..._statusLabels.entries.map(
                      (entry) => DropdownMenuItem<String?>(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => _statusFilter = value),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _openSubmitRequestDialog,
                icon: const Icon(Icons.add),
                tooltip: 'Submit nail request',
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh requests',
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
                      const SizedBox(height: 8),
                      Text('Error: ${snapshot.error}'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Retry'),
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
                      const Text(
                        'No customer nail requests found.',
                        style: TextStyle(color: Colors.grey, fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async => _load(),
                child: ListView.builder(
                  padding: const EdgeInsets.all(12),
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
    );
  }
}
