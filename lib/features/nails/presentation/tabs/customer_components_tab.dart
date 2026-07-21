import 'package:flutter/material.dart';

import '../../../../core/utils/paginated_response.dart';
import '../../data/models/customer_nail_models.dart';
import '../../data/repositories/customer_component_repository.dart';
import '../widgets/customer_component_card.dart';
import '../widgets/customer_component_form_dialog.dart';

class CustomerComponentsTab extends StatefulWidget {
  final CustomerComponentRepository repository;
  final VoidCallback onDataChanged;

  const CustomerComponentsTab({
    super.key,
    required this.repository,
    required this.onDataChanged,
  });

  @override
  State<CustomerComponentsTab> createState() => _CustomerComponentsTabState();
}

class _CustomerComponentsTabState extends State<CustomerComponentsTab> {
  final _searchController = TextEditingController();
  int _page = 1;
  int? _componentTypeFilter;
  late Future<PaginatedResponse<CustomerComponentModel>> _future;

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
      _future = widget.repository.getCustomerComponents(
        page: _page,
        pageSize: 10,
        name: _searchController.text.isNotEmpty ? _searchController.text : null,
        componentType: _componentTypeFilter,
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
      builder: (context) => const CustomerComponentFormDialog(),
    );
    if (result == true) _reload();
  }

  Future<void> _edit(CustomerComponentModel component) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => CustomerComponentFormDialog(component: component),
    );
    if (result == true) _reload();
  }

  Future<void> _delete(CustomerComponentModel component) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Xóa thành phần'),
        content: Text('Bạn có chắc muốn xóa "${component.name}"?'),
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
      await widget.repository.deleteCustomerComponent(component.customerComponentId);
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Search and filter bar
        Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
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
              DropdownButton<int>(
                value: _componentTypeFilter,
                hint: const Text('Loại'),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Tất cả')),
                  DropdownMenuItem(value: 0, child: Text('💎 Gem')),
                  DropdownMenuItem(value: 1, child: Text('📝 Sticker')),
                  DropdownMenuItem(value: 2, child: Text('🔗 Charm')),
                  DropdownMenuItem(value: 3, child: Text('🎨 Art')),
                ],
                onChanged: (value) {
                  setState(() {
                    _componentTypeFilter = value;
                    _page = 1;
                  });
                  _load();
                },
              ),
              const SizedBox(width: 8),
              FloatingActionButton.small(
                onPressed: _create,
                child: const Icon(Icons.add),
              ),
            ],
          ),
        ),

        // List
        Expanded(
          child: FutureBuilder<PaginatedResponse<CustomerComponentModel>>(
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
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
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
                      const Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey),
                      const SizedBox(height: 16),
                      const Text('Chưa có thành phần nào'),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        onPressed: _create,
                        icon: const Icon(Icons.add),
                        label: const Text('Tạo thành phần mới'),
                      ),
                    ],
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.all(8),
                itemCount: response.items.length,
                itemBuilder: (context, index) {
                  final component = response.items[index];
                  return CustomerComponentCard(
                    component: component,
                    onEdit: () => _edit(component),
                    onDelete: () => _delete(component),
                  );
                },
              );
            },
          ),
        ),

        Padding(
          padding: const EdgeInsets.all(12),
          child: FutureBuilder<PaginatedResponse<CustomerComponentModel>>(
            future: _future,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final response = snapshot.data!;
              return Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: response.hasPrevious  // Direct property
                        ? () {
                      setState(() => _page--);
                      _load();
                    }
                        : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Text('Trang ${response.currentPage} / ${response.totalPages}'),  // Direct properties
                  IconButton(
                    onPressed: response.hasNext  // Direct property
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
