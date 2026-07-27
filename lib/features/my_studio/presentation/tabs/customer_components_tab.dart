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

  final List<CustomerComponentModel> _items = [];
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
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
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
        title: const Text(
          'Xóa thành phần',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: Text('Bạn có chắc muốn xóa "${component.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Hủy',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Xóa'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await widget.repository.deleteCustomerComponent(
        component.customerComponentId,
      );
      _reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _create,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 6,
        icon: const Icon(Icons.add_rounded, size: 20),
        label: const Text(
          'Tạo mới',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
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
                    style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
                    decoration: InputDecoration(
                      hintText: 'Tìm thành phần...',
                      prefixIcon: const Icon(
                        Icons.search_rounded,
                        color: AppColors.textSecondary,
                        size: 20,
                      ),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(
                                Icons.clear_rounded,
                                color: AppColors.textSecondary,
                                size: 18,
                              ),
                              onPressed: () {
                                _searchController.clear();
                                _loadData(reset: true);
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: const Color(0xFFF5F5F7),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        vertical: 0,
                        horizontal: 16,
                      ),
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
                      color: const Color(0xFFF5F5F7),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.grey.shade100, width: 1),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<int>(
                        value: _componentTypeFilter,
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
                          'Loại',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
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
                        const Icon(
                          Icons.error_outline,
                          size: 48,
                          color: Colors.red,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Lỗi: $_error',
                          style: const TextStyle(color: Colors.red),
                        ),
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
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 64,
                          color: Colors.grey.shade300,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Chưa có thành phần nào',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 16),
                        const SizedBox(height: 0),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async => _loadData(reset: true),
                    child: ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
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
