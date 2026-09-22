import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

class WithdrawSheet extends StatefulWidget {
  final double availableBalance;
  final Future<bool> Function({
    required double amount,
    required String bankName,
    required String bankCode,
    required String accountNumber,
    required String accountHolderName,
  })
  onConfirmWithdraw;

  const WithdrawSheet({
    super.key,
    required this.availableBalance,
    required this.onConfirmWithdraw,
  });

  static Future<void> show(
    BuildContext context, {
    required double availableBalance,
    required Future<bool> Function({
      required double amount,
      required String bankName,
      required String bankCode,
      required String accountNumber,
      required String accountHolderName,
    })
    onConfirmWithdraw,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WithdrawSheet(
        availableBalance: availableBalance,
        onConfirmWithdraw: onConfirmWithdraw,
      ),
    );
  }

  @override
  State<WithdrawSheet> createState() => _WithdrawSheetState();
}

class _WithdrawSheetState extends State<WithdrawSheet> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _accountNumberController =
      TextEditingController();
  final TextEditingController _accountHolderController =
      TextEditingController();

  final List<Map<String, String>> _supportedBanks = const [
    {'name': 'Vietcombank', 'code': 'VCB'},
    {'name': 'VietinBank', 'code': 'CTG'},
    {'name': 'MB Bank', 'code': 'MB'},
    {'name': 'Techcombank', 'code': 'TCB'},
    {'name': 'BIDV', 'code': 'BIDV'},
    {'name': 'ACB', 'code': 'ACB'},
    {'name': 'TPBank', 'code': 'TPB'},
    {'name': 'VPBank', 'code': 'VPB'},
  ];

  late Map<String, String> _selectedBank;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _selectedBank = _supportedBanks.first;
  }

  @override
  void dispose() {
    _amountController.dispose();
    _accountNumberController.dispose();
    _accountHolderController.dispose();
    super.dispose();
  }

  String _formatVnd(double amount) {
    return NumberFormat.currency(locale: 'vi_VN', symbol: 'đ').format(amount);
  }

  void _setMaxAmount() {
    setState(() {
      _amountController.text = widget.availableBalance.toInt().toString();
    });
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.tryParse(_amountController.text.trim()) ?? 0;
    if (amount <= 0) {
      setState(() => _errorMessage = 'Vui lòng nhập số tiền rút hợp lệ');
      return;
    }
    if (amount > widget.availableBalance) {
      setState(() => _errorMessage = 'Số tiền rút vượt quá số dư khả dụng');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await widget.onConfirmWithdraw(
        amount: amount,
        bankName: _selectedBank['name']!,
        bankCode: _selectedBank['code']!,
        accountNumber: _accountNumberController.text.trim(),
        accountHolderName: _accountHolderController.text.trim().toUpperCase(),
      );

      if (mounted) {
        if (success) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Tạo yêu cầu rút tiền thành công. Vui lòng chờ BQL duyệt!',
              ),
              backgroundColor: Colors.green,
            ),
          );
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = 'Tạo yêu cầu rút tiền thất bại. Vui lòng thử lại.';
          });
        }
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.outbox_rounded,
                      color: Colors.orange,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Rút tiền về Ngân hàng',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      Text(
                        'Số dư khả dụng: ${_formatVnd(widget.availableBalance)}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Warning box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline_rounded,
                      size: 18,
                      color: Colors.amber.shade900,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Số tiền rút sẽ được tạm đóng băng và chuyển vào tài khoản ngân hàng sau khi Admin phê duyệt đối soát.',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.amber.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Bank Dropdown
              DropdownButtonFormField<Map<String, String>>(
                initialValue: _selectedBank,
                decoration: InputDecoration(
                  labelText: 'Ngân hàng nhận',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: _supportedBanks.map((bank) {
                  return DropdownMenuItem(
                    value: bank,
                    child: Text('${bank['name']} (${bank['code']})'),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedBank = val);
                },
              ),
              const SizedBox(height: 12),

              // Account Number
              TextFormField(
                controller: _accountNumberController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Số tài khoản ngân hàng',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (val) => (val == null || val.isEmpty)
                    ? 'Vui lòng nhập số tài khoản'
                    : null,
              ),
              const SizedBox(height: 12),

              // Account Holder Name
              TextFormField(
                controller: _accountHolderController,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  labelText: 'Tên chủ tài khoản (Viết hoa không dấu)',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (val) => (val == null || val.isEmpty)
                    ? 'Vui lòng nhập tên chủ tài khoản'
                    : null,
              ),
              const SizedBox(height: 12),

              // Amount input
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Số tiền muốn rút (VNĐ)',
                  suffixIcon: TextButton(
                    onPressed: _setMaxAmount,
                    child: const Text(
                      'Rút tối đa',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Vui lòng nhập số tiền rút';
                  }
                  final parsed = double.tryParse(val);
                  if (parsed == null || parsed <= 0) {
                    return 'Số tiền không hợp lệ';
                  }
                  if (parsed > widget.availableBalance) {
                    return 'Vượt quá số dư khả dụng';
                  }
                  return null;
                },
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 8),
                Text(
                  _errorMessage!,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Colors.red,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Confirm button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.shade800,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Gửi yêu cầu rút tiền',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
