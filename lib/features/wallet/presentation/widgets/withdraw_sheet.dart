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
    {'name': 'Agribank', 'code': 'VBA'},
    {'name': 'Sacombank', 'code': 'STB'},
    {'name': 'HD Bank', 'code': 'HDB'},
    {'name': 'SHB', 'code': 'SHB'},
    {'name': 'MSB', 'code': 'MSB'},
    {'name': 'VIB', 'code': 'VIB'},
    {'name': 'OCB', 'code': 'OCB'},
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

  String _formatNumber(double amount) {
    return NumberFormat('#,###', 'vi_VN').format(amount);
  }

  double _parseAmount(String text) {
    final cleanText = text
        .replaceAll('.', '')
        .replaceAll(',', '')
        .replaceAll('đ', '')
        .replaceAll('VNĐ', '')
        .trim();
    return double.tryParse(cleanText) ?? 0;
  }

  void _addQuickAmount(double amountToAdd) {
    final current = _parseAmount(_amountController.text);
    final newAmount = current + amountToAdd;
    if (newAmount > widget.availableBalance) {
      setState(() {
        _amountController.text = _formatNumber(widget.availableBalance);
        _errorMessage = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Đã chọn số dư khả dụng tối đa!'),
          duration: Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else {
      setState(() {
        _amountController.text = _formatNumber(newAmount);
        _errorMessage = null;
      });
    }
  }

  void _setMaxAmount() {
    setState(() {
      _amountController.text = _formatNumber(widget.availableBalance);
      _errorMessage = null;
    });
  }

  void _clearAmount() {
    setState(() {
      _amountController.clear();
      _errorMessage = null;
    });
  }

  void _onAmountChanged(String val) {
    final cleanText = val.replaceAll('.', '').replaceAll(',', '').trim();
    if (cleanText.isEmpty) {
      setState(() => _errorMessage = null);
      return;
    }
    final parsed = double.tryParse(cleanText);
    if (parsed != null) {
      final formatted = _formatNumber(parsed);
      if (formatted != val) {
        _amountController.value = TextEditingValue(
          text: formatted,
          selection: TextSelection.collapsed(offset: formatted.length),
        );
      }
    }
    setState(() => _errorMessage = null);
  }

  Future<void> _handleConfirm() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = _parseAmount(_amountController.text);
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
              behavior: SnackBarBehavior.floating,
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

  InputDecoration _buildInputDecoration({
    required String labelText,
    required IconData prefixIcon,
    Widget? suffixIcon,
    String? suffixText,
  }) {
    return InputDecoration(
      labelText: labelText,
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w500,
        color: Colors.grey.shade700,
      ),
      prefixIcon: Icon(prefixIcon, color: AppColors.primary, size: 20),
      suffixIcon: suffixIcon,
      suffixText: suffixText,
      suffixStyle: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.primary,
      ),
      filled: true,
      fillColor: const Color(0xFFF9FAFB),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: AppColors.primary, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent, width: 1.5),
      ),
    );
  }

  Widget _buildQuickChip(String label, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: AppColors.primary.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.add_circle_outline_rounded,
                size: 15,
                color: AppColors.primary,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMaxChip() {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: _setMaxAmount,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFFF66C4), Color(0xFFFF4D4D)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withValues(alpha: 0.3),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.flash_on_rounded,
                size: 15,
                color: Colors.white,
              ),
              SizedBox(width: 4),
              Text(
                'Rút tối đa',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
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
              // Handle bar
              Center(
                child: Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Banner / Header Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFFF66C4), Color(0xFFFF94D2)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.25),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.25),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.account_balance_wallet_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Rút tiền về Ngân hàng',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Số dư khả dụng: ${_formatVnd(widget.availableBalance)}',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withValues(alpha: 0.95),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Notice alert box
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFFFE082)),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.info_outline_rounded,
                      size: 20,
                      color: Color(0xFFF57F17),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Số tiền rút sẽ được tạm đóng băng và chuyển vào tài khoản ngân hàng sau khi Admin phê duyệt đối soát.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.brown.shade800,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Section Title: Ngân hàng
              const Text(
                'Thông tin tài khoản nhận',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),

              // Bank Dropdown
              DropdownButtonFormField<Map<String, String>>(
                initialValue: _selectedBank,
                decoration: _buildInputDecoration(
                  labelText: 'Ngân hàng nhận',
                  prefixIcon: Icons.account_balance_rounded,
                ),
                dropdownColor: Colors.white,
                borderRadius: BorderRadius.circular(16),
                items: _supportedBanks.map((bank) {
                  return DropdownMenuItem(
                    value: bank,
                    child: Text(
                      '${bank['name']} (${bank['code']})',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: _buildInputDecoration(
                  labelText: 'Số tài khoản ngân hàng',
                  prefixIcon: Icons.credit_card_rounded,
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
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
                decoration: _buildInputDecoration(
                  labelText: 'Tên chủ tài khoản (Viết hoa không dấu)',
                  prefixIcon: Icons.person_rounded,
                ),
                validator: (val) => (val == null || val.isEmpty)
                    ? 'Vui lòng nhập tên chủ tài khoản'
                    : null,
              ),
              const SizedBox(height: 16),

              // Amount input field
              TextFormField(
                controller: _amountController,
                keyboardType: TextInputType.number,
                onChanged: _onAmountChanged,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
                decoration: _buildInputDecoration(
                  labelText: 'Số tiền muốn rút (VNĐ)',
                  prefixIcon: Icons.payments_rounded,
                  suffixIcon: Container(
                    padding: const EdgeInsets.only(right: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_amountController.text.isNotEmpty)
                          IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: _clearAmount,
                            tooltip: 'Xóa nhập lại',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        const SizedBox(width: 4),
                        TextButton(
                          onPressed: _setMaxAmount,
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Rút tối đa',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.isEmpty) {
                    return 'Vui lòng nhập số tiền rút';
                  }
                  final parsed = _parseAmount(val);
                  if (parsed <= 0) {
                    return 'Số tiền không hợp lệ';
                  }
                  if (parsed > widget.availableBalance) {
                    return 'Vượt quá số dư khả dụng';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 10),

              // Quick Chips Row (50.000đ, 100.000đ, 200.000đ) - Centered & Evenly Spaced
              Row(
                children: [
                  Expanded(
                    child: _buildQuickChip('50.000đ', () => _addQuickAmount(50000)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickChip('100.000đ', () => _addQuickAmount(100000)),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _buildQuickChip('200.000đ', () => _addQuickAmount(200000)),
                  ),
                ],
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.error_outline_rounded,
                        size: 16,
                        color: Colors.red,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.red,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 24),

              // Confirm button
              Container(
                width: double.infinity,
                height: 54,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  gradient: const LinearGradient(
                    colors: [AppColors.primary, Color(0xFFFF4D4D)],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleConfirm,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
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
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                            SizedBox(width: 10),
                            Text(
                              'Gửi yêu cầu rút tiền',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w800,
                                color: Colors.white,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
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
