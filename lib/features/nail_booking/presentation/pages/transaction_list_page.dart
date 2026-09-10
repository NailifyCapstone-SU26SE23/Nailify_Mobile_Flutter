import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../data/repositories/transaction_repository.dart';
import '../utils/transaction_status_utils.dart';

class TransactionListPage extends StatefulWidget {
  final String? bookingId;

  const TransactionListPage({super.key, this.bookingId});

  @override
  State<TransactionListPage> createState() => _TransactionListPageState();
}

class _TransactionListPageState extends State<TransactionListPage> {
  final TransactionRepository _repository = getIt<TransactionRepository>();
  final ScrollController _scrollController = ScrollController();
  final List<Map<String, dynamic>> _transactions = [];

  bool _isLoading = true;
  bool _isLoadingMore = false;
  String? _errorMessage;
  int _page = 1;
  bool _hasNextPage = false;
  DateTime? _startDate;
  DateTime? _endDate;
  String? _status;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _loadTransactions(refresh: true);
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (widget.bookingId != null) return;
    if (_scrollController.position.extentAfter < 400) {
      _loadMore();
    }
  }

  Future<void> _loadMore() async {
    if (!_hasNextPage || _isLoadingMore || _isLoading) return;
    await _loadTransactions(refresh: false);
  }

  Future<void> _loadTransactions({required bool refresh}) async {
    if (refresh) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
        _page = 1;
        _hasNextPage = false;
        _transactions.clear();
      });
    } else {
      setState(() => _isLoadingMore = true);
    }

    try {
      if (widget.bookingId != null && widget.bookingId!.isNotEmpty) {
        final items = await _repository.getTransactionsByBooking(
          widget.bookingId!,
        );
        if (!mounted) return;
        setState(() {
          _transactions
            ..clear()
            ..addAll(items);
          _isLoading = false;
          _isLoadingMore = false;
          _hasNextPage = false;
        });
        return;
      }

      final result = await _repository.getMyTransactions(
        page: refresh ? 1 : _page + 1,
        pageSize: 5,
        startDate: _startDate,
        endDate: _endDate,
        status: _status,
      );
      if (!mounted) return;
      setState(() {
        _transactions.addAll(result.items);
        _page = result.page;
        _hasNextPage = result.hasNextPage;
        _isLoading = false;
        _isLoadingMore = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = error.toString();
        _isLoading = false;
        _isLoadingMore = false;
      });
    }
  }

  Future<void> _pickDate({required bool isStart}) async {
    final initialDate = isStart
        ? _startDate ?? DateTime.now()
        : _endDate ?? _startDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) {
          _endDate = picked;
        }
      } else {
        _endDate = picked;
      }
    });
    await _loadTransactions(refresh: true);
  }

  void _clearFilters() {
    setState(() {
      _startDate = null;
      _endDate = null;
      _status = null;
    });
    _loadTransactions(refresh: true);
  }

  @override
  Widget build(BuildContext context) {
    final title = widget.bookingId == null
        ? 'Giao dịch của tôi'
        : 'Giao dịch lịch hẹn';
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.pop(),
        ),
        title: Text(title),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () => _loadTransactions(refresh: true),
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (widget.bookingId == null) _buildFilters(),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _MessageState(
                icon: Icons.error_outline,
                message: _errorMessage!,
                actionLabel: 'Thử lại',
                onAction: () => _loadTransactions(refresh: true),
              )
            else if (_transactions.isEmpty)
              const _MessageState(
                icon: Icons.receipt_long_outlined,
                message: 'Chưa có giao dịch nào.',
              )
            else ...[
              ..._transactions.map(_buildTransactionCard),
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilters() {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderLight),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _FilterButton(
                  label: 'Từ ngày',
                  value: _formatDate(_startDate),
                  onTap: () => _pickDate(isStart: true),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _FilterButton(
                  label: 'Đến ngày',
                  value: _formatDate(_endDate),
                  onTap: () => _pickDate(isStart: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _status,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: 'Trạng thái',
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem<String>(
                      value: null,
                      child: Text('Tất cả'),
                    ),
                    ...transactionStatusOptions.map(
                      (status) => DropdownMenuItem<String>(
                        value: status,
                        child: Text(transactionStatusView(status).label),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    setState(() => _status = value);
                    _loadTransactions(refresh: true);
                  },
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Xóa lọc',
                onPressed: _clearFilters,
                icon: const Icon(Icons.filter_alt_off_outlined),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTransactionCard(Map<String, dynamic> transaction) {
    final status = transaction['status']?.toString() ?? '';
    final statusView = transactionStatusView(status);
    final createdAt = _formatDateTime(transaction['createdAt']);
    final salonName = transaction['salonName']?.toString() ?? '';
    final transactionId = _readInt(transaction['transactionId']);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.borderLight),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: transactionId == null
            ? null
            : () => context.push('/transaction-detail', extra: transaction),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    PriceFormatter.format(transaction['amount'] ?? 0),
                    style: const TextStyle(
                      color: AppColors.primary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  _StatusChip(statusView: statusView),
                ],
              ),

              if (salonName.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(salonName, style: const TextStyle(color: Colors.grey)),
              ],
              if (createdAt.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(createdAt, style: const TextStyle(color: Colors.grey)),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Không chọn';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
  }

  String _formatDateTime(dynamic value) {
    final date = DateTime.tryParse(value?.toString() ?? '');
    if (date == null) return value?.toString() ?? '';
    return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year} ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }
}

class _FilterButton extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback onTap;

  const _FilterButton({
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11)),
          const SizedBox(height: 2),
          Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final TransactionStatusView statusView;

  const _StatusChip({required this.statusView});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: statusView.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        statusView.label,
        style: TextStyle(
          color: statusView.color,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  const _MessageState({
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 120),
      child: Center(
        child: Column(
          children: [
            Icon(icon, size: 42, color: Colors.grey),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 12),
              FilledButton(onPressed: onAction, child: Text(actionLabel!)),
            ],
          ],
        ),
      ),
    );
  }
}
