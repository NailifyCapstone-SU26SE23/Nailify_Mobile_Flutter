import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../../../core/utils/price_formatter.dart';
import '../../data/repositories/transaction_repository.dart';
import '../utils/transaction_status_utils.dart';

class TransactionListPage extends StatefulWidget {
  final String? bookingId;
  final Map<String, dynamic>? bookingData;

  const TransactionListPage({super.key, this.bookingId, this.bookingData});

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

        var resultList = List<Map<String, dynamic>>.from(items);

        if (resultList.isEmpty && widget.bookingData != null) {
          final bData = widget.bookingData!;
          final bTransactions =
              bData['transactions'] ?? bData['paymentTransactions'];
          if (bTransactions is List && bTransactions.isNotEmpty) {
            resultList = bTransactions
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          } else {
            final amountPaid = bData['amountPaid'];
            if (amountPaid != null) {
              final numAmount = amountPaid is num
                  ? amountPaid
                  : (double.tryParse(amountPaid.toString()) ?? 0);
              if (numAmount > 0) {
                final salonName =
                    bData['salonName']?.toString() ??
                    (bData['salon'] is Map
                        ? bData['salon']['name']?.toString()
                        : null) ??
                    '';
                resultList = [
                  {
                    'transactionId': bData['bookingId'] ?? widget.bookingId,
                    'amount': numAmount,
                    'status': 'Paid',
                    'salonName': salonName,
                    'createdAt':
                        bData['updatedAt'] ??
                        bData['createdAt'] ??
                        bData['bookingDate'],
                    'orderCode':
                        bData['orderCode'] ?? bData['paymentOrderCode'],
                    'customerName':
                        bData['customerName'] ?? bData['user']?['fullName'],
                    'bookingId': widget.bookingId,
                  },
                ];
              }
            }
          }
        }

        if (!mounted) return;
        setState(() {
          _transactions
            ..clear()
            ..addAll(resultList);
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
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.primaryDark,
            size: 20,
          ),
          onPressed: () => context.pop(),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
          ),
        ),
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
            if (!_isLoading &&
                _errorMessage == null &&
                _transactions.isNotEmpty)
              _buildSummaryHeader(),
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.only(top: 120),
                child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              )
            else if (_errorMessage != null)
              _MessageState(
                icon: Icons.error_outline_rounded,
                message: _errorMessage!,
                actionLabel: 'Thử lại',
                onAction: () => _loadTransactions(refresh: true),
              )
            else if (_transactions.isEmpty)
              const _MessageState(
                icon: Icons.receipt_long_outlined,
                message: 'Chưa có giao dịch nào cho lịch hẹn này.',
              )
            else ...[
              ..._transactions.map(_buildTransactionCard),
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

    Widget _buildSummaryHeader() {
    num totalAmount = 0;
    if (widget.bookingData != null && widget.bookingData!['amountPaid'] != null) {
      final amt = widget.bookingData!['amountPaid'];
      totalAmount = amt is num ? amt : (double.tryParse(amt.toString()) ?? 0);
    }
    if (totalAmount == 0) {
      for (final tx in _transactions) {
        final orderCode = tx['orderCode']?.toString().toLowerCase() ?? '';
        if (orderCode.contains('hoàn')) continue;
        final status = tx['status']?.toString().toLowerCase();
        if (status == 'paid' || status == 'success' || status == 'completed') {
          totalAmount += (tx['amount'] as num? ?? 0);
        }
      }
    }
  
      return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0EAE1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Tổng tiền giao dịch',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  PriceFormatter.format(totalAmount),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${_transactions.length} giao dịch',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
              ),
            ),
          ),
        ],
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
    final orderCode = transaction['orderCode']?.toString();
    final amount = transaction['amount'] ?? 0;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFF0EAE1), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap:
              transactionId == null && (orderCode == null || orderCode.isEmpty)
              ? null
              : () => context.push('/transaction-detail', extra: transaction),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Icon + Salon Name + Status Pill
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: statusView.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        statusView.icon,
                        color: statusView.color,
                        size: 22,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            salonName.isNotEmpty ? salonName : 'Nailify Salon',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (orderCode != null && orderCode.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              'Mã HĐ: #$orderCode',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    _StatusChip(statusView: statusView),
                  ],
                ),

                const SizedBox(height: 12),
                Divider(height: 1, color: Colors.grey.shade200),
                const SizedBox(height: 12),

                // Bottom row: Date/Time + Amount + Chevron
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Colors.grey.shade500,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          createdAt,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        Text(
                          PriceFormatter.format(amount),
                          style: const TextStyle(
                            color: AppColors.primary,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: Colors.grey.shade400,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
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
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusView.color.withValues(alpha: 0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: statusView.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            statusView.label,
            style: TextStyle(
              color: statusView.color,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
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
      padding: const EdgeInsets.only(top: 80),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 40, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}






