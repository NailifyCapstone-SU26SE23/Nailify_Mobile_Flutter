import 'package:flutter/material.dart';

import '../../../../core/utils/paginated_response.dart';
import '../../../nails/data/models/customer_nail_models.dart';
import '../../../nails/data/repositories/customer_nail_repository.dart';
import '../../../try-on/presentation/try_on_setup_screen.dart';
import '../widgets/customer_nail_card.dart';
import '../widgets/customer_nail_form_dialog.dart';

class CustomerNailsTab extends StatefulWidget {
  final CustomerNailRepository repository;
  final VoidCallback onDataChanged;

  const CustomerNailsTab({
    super.key,
    required this.repository,
    required this.onDataChanged,
  });

  @override
  State<CustomerNailsTab> createState() => _CustomerNailsTabState();
}

class _CustomerNailsTabState extends State<CustomerNailsTab> {
  final _searchController = TextEditingController();
  int _page = 1;
  bool? _isPublicFilter;
  late Future<PaginatedResponse<CustomerNailModel>> _future;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _load() {
    setState(() {
      _future = widget.repository.getCustomerNails(
        page: _page,
        pageSize: 10,
        name: _searchController.text.isNotEmpty ? _searchController.text : null,
        isPublic: _isPublicFilter,
      );
    });
  }

  void _reload() {
    _load();
    widget.onDataChanged();
  }

  Future<void> _create() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => const CustomerNailFormDialog(),
    );
    if (result == true) _reload();
  }

  Future<void> _edit(CustomerNailModel nail) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CustomerNailFormDialog(nail: nail),
    );
    if (result == true) _reload();
  }

  Future<void> _delete(CustomerNailModel nail) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa mẫu móng'),
        content: Text('Bạn có chắc muốn xóa "${nail.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteCustomerNail(nail.customerNailId);
      _reload();
    }
  }

  Future<void> _toggleFavorite(CustomerNailModel nail) async {
    await widget.repository.updateCustomerNail(
      customerNailId: nail.customerNailId,
      name: nail.name,
      isPublic: nail.isPublic,
      imagePath: null,
    );
    _reload();
  }

  Future<void> _togglePublic(CustomerNailModel nail) async {
    await widget.repository.updateCustomerNail(
      customerNailId: nail.customerNailId,
      name: nail.name,
      isPublic: !nail.isPublic,
      imagePath: null,
    );
    _reload();
  }

  Future<void> _setupTryOn(CustomerNailModel nail) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (context) => TryOnSetupScreen(customerNail: nail),
      ),
    );
    if (result == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and filter bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Tìm theo tên...',
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _page = 1;
                            _load();
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        isDense: true,
                      ),
                      onSubmitted: (_) {
                        _page = 1;
                        _load();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  FloatingActionButton.small(
                    onPressed: _create,
                    child: const Icon(Icons.add),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Công khai'),
                    selected: _isPublicFilter == true,
                    onSelected: (selected) {
                      setState(() {
                        _isPublicFilter = selected ? true : null;
                        _page = 1;
                      });
                      _load();
                    },
                  ),
                ],
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: FutureBuilder<PaginatedResponse<CustomerNailModel>>(
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
                      Text('Lỗi: ${snapshot.error}'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: _load,
                        child: const Text('Thử lại'),
                      ),
                    ],
                  ),
                );
              }

              final response = snapshot.data!;
              if (response.items.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.spa_outlined,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      const Text('Chưa có mẫu móng nào'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _create,
                        icon: const Icon(Icons.add),
                        label: const Text('Tạo mẫu móng mới'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: response.items.length,
                itemBuilder: (context, index) {
                  final nail = response.items[index];
                  return CustomerNailCard(
                    nail: nail,
                    onEdit: () => _edit(nail),
                    onDelete: () => _delete(nail),
                    onToggleFavorite: () => _toggleFavorite(nail),
                    onTogglePublic: () => _togglePublic(nail),
                    onSetupTryOn: () => _setupTryOn(nail),
                  );
                },
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: FutureBuilder<PaginatedResponse<CustomerNailModel>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final response = snapshot.data!;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: response.hasPrevious
                        ? () {
                            setState(() => _page--);
                            _load();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text(
                    'Trang ${response.currentPage} / ${response.totalPages}',
                  ),
                  IconButton(
                    onPressed: response.hasNext
                        ? () {
                            setState(() => _page++);
                            _load();
                          }
                        : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
