import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../my_studio/data/datasources/studio_api_service.dart';
import '../../../my_studio/data/models/customer_nail_model.dart';
import '../../../my_studio/presentation/widgets/studio_nail_card.dart';

class CustomerNailRequestsTab extends StatefulWidget {
  const CustomerNailRequestsTab({super.key});

  @override
  State<CustomerNailRequestsTab> createState() => _CustomerNailRequestsTabState();
}

class _CustomerNailRequestsTabState extends State<CustomerNailRequestsTab> {
  final StudioApiService _apiService = StudioApiService();
  late Future<List<CustomerNailModel>> _future;
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

  List<CustomerNailModel> _filterRequests(List<CustomerNailModel> requests) {
    final status = _statusFilter;
    if (status == null) return requests;
    return requests.where((request) => request.status == status).toList();
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
                  value: _statusFilter,
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
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh requests',
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<CustomerNailModel>>(
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
