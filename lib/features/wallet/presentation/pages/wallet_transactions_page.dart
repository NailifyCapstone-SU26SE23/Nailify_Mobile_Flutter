import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/di/injection.dart';
import '../../data/models/wallet_transaction_model.dart';
import '../../data/repositories/wallet_repository.dart';

class WalletTransactionsPage extends StatefulWidget {
  const WalletTransactionsPage({super.key});

  @override
  State<WalletTransactionsPage> createState() => _WalletTransactionsPageState();
}

class _WalletTransactionsPageState extends State<WalletTransactionsPage> {
  final WalletRepository _repository = getIt<WalletRepository>();
  bool _isLoading = true;
  String? _errorMessage;
  List<WalletTransactionModel> _allTransactions = [];
  WalletTxType? _selectedFilter;

  @override
  void initState() {
    super.initState();
    _loadTransactions();
  }

  Future<void> _loadTransactions() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final res = await _repository.getWalletTransactions(
        pageNumber: 1,
        pageSize: 50,
      );
      if (mounted) {
        setState(() {
          _allTransactions = res.items;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    }
  }

  List<WalletTransactionModel> get _filteredTransactions {
    if (_selectedFilter == null) return _allTransactions;
    return _allTransactions.where((t) => t.type == _selectedFilter).toList();
  }

  String _formatVnd(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(amount.abs());
  }

  String _formatDateTime(DateTime date) {
    return DateFormat('HH:mm - dd/MM/yyyy').format(date);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Lịch sử ví tiền mặt',
          style: TextStyle(
            color: AppColors.primaryDark,
            fontWeight: FontWeight.w800,
            fontFamily: 'Georgia',
          ),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(
              Icons.refresh_rounded,
              color: AppColors.primaryDark,
            ),
            onPressed: _loadTransactions,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  _buildFilterChip('Tất cả', null),
                  _buildFilterChip('Nạp tiền', WalletTxType.deposit),
                  _buildFilterChip('Rút tiền', WalletTxType.withdraw),
                  _buildFilterChip(
                    'Thanh toán cọc',
                    WalletTxType.bookingPayment,
                  ),
                  _buildFilterChip('Đổi điểm', WalletTxType.convertToPoints),
                  _buildFilterChip('Hoàn tiền', WalletTxType.refund),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // Content List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _errorMessage != null
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.error_outline_rounded,
                          size: 48,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 12),
                        Text(_errorMessage!),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _loadTransactions,
                          child: const Text('Thử lại'),
                        ),
                      ],
                    ),
                  )
                : _filteredTransactions.isEmpty
                ? const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.receipt_long_rounded,
                          size: 48,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Chưa có giao dịch nào',
                          style: TextStyle(
                            color: Colors.grey,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _loadTransactions,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: _filteredTransactions.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 10),
                      itemBuilder: (context, index) {
                        final tx = _filteredTransactions[index];
                        return _buildTransactionTile(tx);
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, WalletTxType? type) {
    final isSelected = _selectedFilter == type;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: isSelected ? Colors.white : AppColors.textPrimary,
          ),
        ),
        selected: isSelected,
        selectedColor: AppColors.primary,
        backgroundColor: Colors.grey.shade100,
        onSelected: (_) => setState(() => _selectedFilter = type),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? AppColors.primary : Colors.grey.shade300,
          ),
        ),
      ),
    );
  }

  Widget _buildTransactionTile(WalletTransactionModel tx) {
    IconData iconData;
    Color iconColor;
    Color iconBg;
    String prefix = '-';

    switch (tx.type) {
      case WalletTxType.deposit:
        iconData = Icons.add_card_rounded;
        iconColor = const Color(0xFF4CAF50);
        iconBg = const Color(0xFF4CAF50).withValues(alpha: 0.1);
        prefix = '+';
        break;
      case WalletTxType.withdraw:
        iconData = Icons.outbox_rounded;
        iconColor = const Color(0xFFFF9800);
        iconBg = const Color(0xFFFF9800).withValues(alpha: 0.1);
        prefix = '-';
        break;
      case WalletTxType.bookingPayment:
        iconData = Icons.shopping_bag_rounded;
        iconColor = AppColors.primary;
        iconBg = AppColors.primary.withValues(alpha: 0.1);
        prefix = '-';
        break;
      case WalletTxType.convertToPoints:
        iconData = Icons.published_with_changes_rounded;
        iconColor = Colors.purple;
        iconBg = Colors.purple.withValues(alpha: 0.1);
        prefix = '-';
        break;
      case WalletTxType.refund:
        iconData = Icons.replay_rounded;
        iconColor = const Color(0xFF2196F3);
        iconBg = const Color(0xFF2196F3).withValues(alpha: 0.1);
        prefix = '+';
        break;
      default:
        iconData = Icons.account_balance_wallet_rounded;
        iconColor = Colors.grey;
        iconBg = Colors.grey.withValues(alpha: 0.1);
        prefix = '';
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade100),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
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
              color: iconBg,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(iconData, color: iconColor, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tx.description.isNotEmpty ? tx.description : 'Giao dịch ví',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  _formatDateTime(tx.createdAt),
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '$prefix${_formatVnd(tx.amount)}',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  color: prefix == '+'
                      ? const Color(0xFF4CAF50)
                      : AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              _buildStatusBadge(tx.status),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBadge(WalletTxStatus status) {
    Color bg;
    Color fg;
    String label;

    switch (status) {
      case WalletTxStatus.completed:
        bg = Colors.green.shade50;
        fg = Colors.green.shade800;
        label = 'Thành công';
        break;
      case WalletTxStatus.pending:
        bg = Colors.amber.shade50;
        fg = Colors.amber.shade900;
        label = 'Đang xử lý';
        break;
      case WalletTxStatus.failed:
        bg = Colors.red.shade50;
        fg = Colors.red.shade800;
        label = 'Thất bại';
        break;
      case WalletTxStatus.cancelled:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        label = 'Đã hủy';
        break;
      default:
        bg = Colors.grey.shade100;
        fg = Colors.grey.shade700;
        label = 'Hoàn tất';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: fg),
      ),
    );
  }
}
