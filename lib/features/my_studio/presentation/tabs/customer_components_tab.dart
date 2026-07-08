import 'package:flutter/material.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../nails/data/models/customer_nail_models.dart';
import '../../../nails/data/repositories/customer_component_repository.dart';
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
  final _scrollController = ScrollController();
  
  List<CustomerComponentModel> _items = [];
  int _page = 1;
  bool _isLoading = false;
  bool _hasMore = true;
  String? _error;
  
  int? _componentTypeFilter;

  @override
  void initState() {
    super.initState();
    _loadData(reset: true);
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >= _scrollController.position.maxScrollExtent - 200) {
      _loadData();
    }
  }

  Future<void> _loadData({bool reset = false}) async {
    if (_isLoading) return;
    if (reset) {
      setState(() {
        _page = 1;
        _items.clear();
        _hasMore = true;
        _error = null;
      });
    }

    if (!_hasMore) return;

    setState(() => _isLoading = true);
    try {
      final response = await widget.repository.getCustomerComponents(
        page: _page,
        pageSize: 10,
        name: _searchController.text.isNotEmpty ? _searchController.text : null,
        componentType: _componentTypeFilter,
      );
      
      if (mounted) {
        setState(() {
          _items.addAll(response.items);
          _hasMore = response.hasNext;
          if (_hasMore) _page++;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _error = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _reload() {
    _loadData(reset: true);
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Xóa thành phần', style: TextStyle(fontWeight: FontWeight.bold)),
        content: Text('Bạn có chắc muốn xóa "${component.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Hủy', style: TextStyle(color: AppColors.textSecondary)),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
            ),
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
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton(
        onPressed: _create,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 4,
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: [
          // Thanh tìm kiếm và bộ lọc cải tiến
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Tìm theo tên...',
                      prefixIcon: const Icon(Icons.search, color: AppColors.textSecondary),
                      suffixIcon: _searchController.text.isNotEmpty ? IconButton(
                        icon: const Icon(Icons.clear, color: AppColors.textSecondary),
                        onPressed: () {
                          _searchController.clear();
                          _loadData(reset: true);
                        },
                      ) : null,
                      filled: true,
                      fillColor: Colors.grey.shade50,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
                    ),
                    onSubmitted: (_) => _loadData(reset: true),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 48,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _componentTypeFilter,
                        hint: const Text('Loại', overflow: TextOverflow.ellipsis),
                        icon: const Icon(Icons.filter_list, size: 20),
                        isExpanded: true,
                        items: const [
                          DropdownMenuItem(value: null, child: Text('Tất cả')),
                          DropdownMenuItem(value: 0, child: Text('💎 Gem')),
                          DropdownMenuItem(value: 1, child: Text('📝 Sticker')),
                          DropdownMenuItem(value: 2, child: Text('🔗 Charm')),
                          DropdownMenuItem(value: 3, child: Text('🎨 Art')),
                        ],
                        onChanged: (value) {
                          setState(() => _componentTypeFilter = value);
                          _loadData(reset: true);
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Danh sách với Infinite Scroll
        Expanded(
          child: _error != null && _items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: Colors.red),
                      const SizedBox(height: 16),
                      Text('Lỗi: $_error', style: const TextStyle(color: Colors.red)),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: () => _loadData(reset: true),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                )
              : _items.isEmpty && !_isLoading
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 64, color: Colors.grey.shade300),
                          const SizedBox(height: 16),
                          Text('Chưa có thành phần nào', style: TextStyle(color: Colors.grey.shade600, fontSize: 16)),
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            onPressed: _create,
                            icon: const Icon(Icons.add),
                            label: const Text('Tạo thành phần mới'),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: () async => _loadData(reset: true),
                      child: ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        physics: const AlwaysScrollableScrollPhysics(),
                        itemCount: _items.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _items.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16.0),
                              child: Center(child: CircularProgressIndicator()),
                            );
                          }
                          final component = _items[index];
                          return CustomerComponentCard(
                            component: component,
                            onEdit: () => _edit(component),
                            onDelete: () => _delete(component),
                          );
                        },
                      ),
                    ),
        ),
        ],
      ),
    );
  }
}
