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

class _TransactionListPageState extends State<TransactionListPage>
    with SingleTickerProviderStateMixin {
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

  late AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _loadTransactions(refresh: true);
  }

  @override
  void dispose() {
    _shimmerController.dispose();
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: AppColors.primary,
              onPrimary: Colors.white,
              onSurface: AppColors.textPrimary,
            ),
          ),
          child: child!,
        );
      },
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

  bool get _hasActiveFilters =>
      _startDate != null || _endDate != null || _status != null;

  @override
  Widget build(BuildContext context) {
    final title = widget.bookingId == null
        ? 'Giao dịch của tôi'
        : 'Giao dịch lịch hẹn';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        backgroundColor: Colors.white,
        centerTitle: true,
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Material(
            color: const Color(0xFFF1F5F9),
            shape: const CircleBorder(),
            clipBehavior: Clip.antiAlias,
            child: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: AppColors.textPrimary,
                size: 18,
              ),
              onPressed: () => context.pop(),
            ),
          ),
        ),
        title: Text(
          title,
          style: const TextStyle(
            color: AppColors.textPrimary,
            fontWeight: FontWeight.w700,
            fontSize: 18,
            letterSpacing: -0.3,
          ),
        ),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: () => _loadTransactions(refresh: true),
        child: ListView(
          controller: _scrollController,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            if (widget.bookingId == null) _buildFilterSection(),
            if (!_isLoading &&
                _errorMessage == null &&
                _transactions.isNotEmpty) ...[
              _buildSummaryHeader(),
              if (_buildRefundPolicyBanner() != null)
                _buildRefundPolicyBanner()!,
            ],
            if (_isLoading)
              _buildSkeletonLoader()
            else if (_errorMessage != null)
              _MessageState(
                icon: Icons.error_outline_rounded,
                message: _errorMessage!,
                actionLabel: 'Thử lại',
                onAction: () => _loadTransactions(refresh: true),
              )
            else if (_transactions.isEmpty)
              _MessageState(
                icon: Icons.receipt_long_outlined,
                message: 'Chưa có giao dịch nào phù hợp.',
                actionLabel: _hasActiveFilters ? 'Xóa bộ lọc' : null,
                onAction: _hasActiveFilters ? _clearFilters : null,
              )
            else ...[
              ..._transactions.asMap().entries.map((entry) {
                final index = entry.key;
                final tx = entry.value;
                return TweenAnimationBuilder<double>(
                  key: ValueKey(tx['transactionId'] ?? index),
                  duration: Duration(milliseconds: 300 + (index % 5) * 80),
                  tween: Tween(begin: 0.0, end: 1.0),
                  builder: (context, value, child) {
                    return Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: Opacity(opacity: value, child: child),
                    );
                  },
                  child: _buildTransactionCard(tx),
                );
              }),
              if (_isLoadingMore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: CircularProgressIndicator(
                      color: AppColors.primary,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row 1: Header title & reset button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(
                      Icons.filter_list_rounded,
                      size: 16,
                      color: AppColors.primary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Bộ lọc giao dịch',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              if (_hasActiveFilters)
                InkWell(
                  onTap: _clearFilters,
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Row(
                      children: [
                        Icon(
                          Icons.restart_alt_rounded,
                          size: 14,
                          color: AppColors.primaryDark,
                        ),
                        SizedBox(width: 4),
                        Text(
                          'Đặt lại',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Row 2: Status horizontal chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: [
                _buildStatusChipItem(
                  label: 'Tất cả',
                  statusValue: null,
                  color: AppColors.primary,
                ),
                ...transactionStatusOptions.map((st) {
                  final stView = transactionStatusView(st);
                  return _buildStatusChipItem(
                    label: stView.label,
                    statusValue: st,
                    color: stView.color,
                  );
                }),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Row 3: Date Selectors
          Row(
            children: [
              Expanded(
                child: _DateSelectorTile(
                  label: 'Từ ngày',
                  value: _formatDate(_startDate),
                  isSelected: _startDate != null,
                  onTap: () => _pickDate(isStart: true),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _DateSelectorTile(
                  label: 'Đến ngày',
                  value: _formatDate(_endDate),
                  isSelected: _endDate != null,
                  onTap: () => _pickDate(isStart: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatusChipItem({
    required String label,
    required String? statusValue,
    required Color color,
  }) {
    final isSelected = _status == statusValue;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              setState(() => _status = statusValue);
              _loadTransactions(refresh: true);
            },
            borderRadius: BorderRadius.circular(20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : const Color(0xFFE2E8F0),
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 3),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.white : color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight:
                          isSelected ? FontWeight.bold : FontWeight.w500,
                      color: isSelected
                          ? Colors.white
                          : AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
          ),
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
        gradient: const LinearGradient(
          colors: [
            Color(0xFFFFF0F5),
            Colors.white,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.primaryLight.withValues(alpha: 0.8),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: AppColors.quizGradient,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(
              Icons.account_balance_wallet_rounded,
              color: Colors.white,
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
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  PriceFormatter.format(totalAmount),
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.primaryDark,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withValues(alpha: 0.2),
              ),
            ),
            child: Text(
              '${_transactions.length} giao dịch',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryDark,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget? _buildRefundPolicyBanner() {
    Map<String, dynamic>? depositTx;
    Map<String, dynamic>? refundTx;

    for (final tx in _transactions) {
      final code = (tx['orderCode'] ?? tx['description'] ?? '').toString().toLowerCase();
      final status = (tx['status'] ?? '').toString().toLowerCase();

      if (code.contains('hoàn') || code.contains('refund') || status == 'refunded') {
        refundTx = tx;
      } else if (code.contains('cọc') ||
          code.contains('thanh toán') ||
          status == 'paid' ||
          status == 'completed' ||
          status == 'success') {
        depositTx ??= tx;
      }
    }

    if (refundTx == null) return null;

    bool isFullRefund = true;

    if (depositTx != null && depositTx['amount'] != null && refundTx['amount'] != null) {
      final depAmt = (depositTx['amount'] as num).toDouble();
      final refAmt = (refundTx['amount'] as num).toDouble();
      if (depAmt > 0) {
        final ratio = refAmt / depAmt;
        if (ratio <= 0.88) {
          isFullRefund = false;
        } else if (ratio >= 0.95) {
          isFullRefund = true;
        }
      }
    } else {
      DateTime? bookingTime;
      if (widget.bookingData != null) {
        final bDateRaw = widget.bookingData!['bookingDate'] ??
            widget.bookingData!['startTime'] ??
            widget.bookingData!['appointmentTime'];
        if (bDateRaw != null) {
          bookingTime = DateTime.tryParse(bDateRaw.toString());
        }
      }

      DateTime? depositTime;
      if (depositTx != null) {
        final dTimeRaw = depositTx['createdAt'] ?? depositTx['transactionDate'];
        if (dTimeRaw != null) {
          depositTime = DateTime.tryParse(dTimeRaw.toString());
        }
      }

      DateTime? refundTime;
      final rTimeRaw = refundTx['createdAt'] ?? refundTx['transactionDate'];
      if (rTimeRaw != null) {
        refundTime = DateTime.tryParse(rTimeRaw.toString());
      }

      if (refundTime != null) {
        final targetTime = bookingTime ?? depositTime;
        if (targetTime != null) {
          final diffInHours = targetTime.difference(refundTime).inHours.abs();
          if (diffInHours < 24) {
            isFullRefund = false;
          }
        }
      }
    }

    final refundAmountStr = refundTx['amount'] != null
        ? PriceFormatter.format(refundTx['amount'])
        : '';

    final primaryColor = isFullRefund ? const Color(0xFF059669) : const Color(0xFFD97706);
    final bgColor = isFullRefund ? const Color(0xFFECFDF5) : const Color(0xFFFFFBEB);
    final borderColor = isFullRefund ? const Color(0xFFA7F3D0) : const Color(0xFFFDE68A);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 4,
              color: primaryColor,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: primaryColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        isFullRefund ? Icons.verified_rounded : Icons.info_rounded,
                        color: primaryColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isFullRefund
                                ? 'Thông báo: Hoàn tiền 100% cọc'
                                : 'Thông báo: Hoàn tiền 80% cọc',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              color: isFullRefund
                                  ? const Color(0xFF065F46)
                                  : const Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isFullRefund
                                ? 'Hủy lịch trước thời gian đặt lịch 24 tiếng. Hệ thống đã hoàn trả 100% tiền cọc ($refundAmountStr) vào ví của bạn.'
                                : 'Hủy lịch trong thời gian đặt lịch 24 tiếng. Theo chính sách quy định, bạn được hoàn trả 80% tiền cọc ($refundAmountStr) vào ví.',
                            style: TextStyle(
                              fontSize: 12.5,
                              color: isFullRefund
                                  ? const Color(0xFF047857)
                                  : const Color(0xFFB45309),
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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

    final rawDesc = orderCode ?? transaction['description'];
    final cleanDesc = formatTransactionDescription(rawDesc);
    final isPureNumber = RegExp(r'^\d+$').hasMatch(cleanDesc);
    final invoiceText = cleanDesc.isNotEmpty
        ? (isPureNumber ? 'Mã HĐ: #$cleanDesc' : cleanDesc)
        : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFF1F5F9), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: transactionId == null && (orderCode == null || orderCode.isEmpty)
              ? null
              : () => context.push('/transaction-detail', extra: transaction),
          child: Padding(
            padding: const EdgeInsets.all(15),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row: Icon + Salon Name + Status Pill
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: statusView.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
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
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.2,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (invoiceText != null) ...[
                            const SizedBox(height: 3),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF8FAFC),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                invoiceText,
                                style: const TextStyle(
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w500,
                                  color: Color(0xFF64748B),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
                Container(
                  height: 1,
                  color: const Color(0xFFF1F5F9),
                ),
                const SizedBox(height: 12),

                // Bottom row: Date/Time + Amount + Arrow
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.access_time_rounded,
                          size: 14,
                          color: Color(0xFF94A3B8),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          createdAt,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF64748B),
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
                            color: AppColors.primaryDark,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: const BoxDecoration(
                            color: Color(0xFFF8FAFC),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 11,
                            color: Color(0xFF94A3B8),
                          ),
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

  Widget _buildSkeletonLoader() {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final opacity = 0.3 + (_shimmerController.value * 0.4);
        return Column(
          children: List.generate(
            3,
            (index) => Container(
              margin: const EdgeInsets.only(bottom: 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: opacity),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFF1F5F9)),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              width: 140,
                              height: 14,
                              color: Colors.grey.shade300,
                            ),
                            const SizedBox(height: 8),
                            Container(
                              width: 90,
                              height: 10,
                              color: Colors.grey.shade300,
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 70,
                        height: 22,
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        width: 100,
                        height: 12,
                        color: Colors.grey.shade300,
                      ),
                      Container(
                        width: 80,
                        height: 16,
                        color: Colors.grey.shade300,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Chọn ngày';
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

class _DateSelectorTile extends StatelessWidget {
  final String label;
  final String value;
  final bool isSelected;
  final VoidCallback onTap;

  const _DateSelectorTile({
    required this.label,
    required this.value,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary.withValues(alpha: 0.06)
                : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.5)
                  : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today_rounded,
                size: 16,
                color: isSelected ? AppColors.primary : const Color(0xFF94A3B8),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        fontSize: 10.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      value,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            isSelected ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? AppColors.primaryDark
                            : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
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
          color: statusView.color.withValues(alpha: 0.25),
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
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
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
      padding: const EdgeInsets.symmetric(vertical: 60, horizontal: 24),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 44, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
                height: 1.4,
              ),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                  elevation: 2,
                ),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(
                  actionLabel!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}






