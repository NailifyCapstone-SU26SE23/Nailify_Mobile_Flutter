import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

class DepositSheet extends StatefulWidget {
  final Future<void> Function(double amount) onConfirmDeposit;

  const DepositSheet({super.key, required this.onConfirmDeposit});

  static Future<void> show(
    BuildContext context, {
    required Future<void> Function(double amount) onConfirmDeposit,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DepositSheet(onConfirmDeposit: onConfirmDeposit),
    );
  }

  @override
  State<DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends State<DepositSheet> {
  final TextEditingController _amountController = TextEditingController();
  final List<double> _presetAmounts = [
    50000,
    100000,
    200000,
    500000,
    1000000,
  ];
  double _selectedAmount = 100000;
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _amountController.text = _formatNumber(_selectedAmount);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _formatNumber(double amount) {
    return NumberFormat('#,###', 'vi_VN').format(amount);
  }

  void _selectPreset(double amount) {
    setState(() {
      _selectedAmount = amount;
      _amountController.text = _formatNumber(amount);
      _errorMessage = null;
    });
  }

  void _onInputChanged(String text) {
    final cleanText = text.replaceAll('.', '').replaceAll(',', '').trim();
    final parsed = double.tryParse(cleanText);
    if (parsed != null) {
      setState(() {
        _selectedAmount = parsed;
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleConfirm() async {
    if (_selectedAmount < 10000) {
      setState(() {
        _errorMessage = 'Số tiền nạp tối thiểu là 10,000 VNĐ';
      });
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await widget.onConfirmDeposit(_selectedAmount);
      if (mounted) Navigator.pop(context);
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle bar
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.qr_code_scanner_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nạp tiền vào ví cá nhân',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Thanh toán tiện lợi qua cổng PayOS',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Presets
          const Text(
            'Chọn nhanh số tiền nạp',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _presetAmounts.map((amt) {
              final isSelected = _selectedAmount == amt;
              return ChoiceChip(
                label: Text(
                  '${_formatNumber(amt)}đ',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: isSelected ? Colors.white : AppColors.textPrimary,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppColors.primary,
                backgroundColor: Colors.grey.shade100,
                onSelected: (_) => _selectPreset(amt),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isSelected ? AppColors.primary : Colors.grey.shade200,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Input field
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            onChanged: _onInputChanged,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Hoặc nhập số tiền khác (VNĐ)',
              suffixText: 'VNĐ',
              suffixStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.primary,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppColors.primary, width: 2),
              ),
            ),
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

          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleConfirm,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
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
                  : Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.qr_code_2_rounded, color: Colors.white),
                        const SizedBox(width: 8),
                        Text(
                          'Tạo mã QR Nạp ${_formatNumber(_selectedAmount)}đ',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
