import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';

class ConvertPointsSheet extends StatefulWidget {
  final double availableBalance;
  final Future<String> Function(double moneyAmount) onConfirmConvert;

  const ConvertPointsSheet({
    super.key,
    required this.availableBalance,
    required this.onConfirmConvert,
  });

  static Future<void> show(
    BuildContext context, {
    required double availableBalance,
    required Future<String> Function(double moneyAmount) onConfirmConvert,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => ConvertPointsSheet(
        availableBalance: availableBalance,
        onConfirmConvert: onConfirmConvert,
      ),
    );
  }

  @override
  State<ConvertPointsSheet> createState() => _ConvertPointsSheetState();
}

class _ConvertPointsSheetState extends State<ConvertPointsSheet> {
  final TextEditingController _amountController = TextEditingController();
  double _selectedMoney = 50000;
  bool _isLoading = false;
  String? _errorMessage;

  final List<double> _presetMoney = const [
    20000,
    50000,
    100000,
    200000,
    500000,
  ];

  @override
  void initState() {
    super.initState();
    _amountController.text = _formatNumber(_selectedMoney);
  }

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  String _formatNumber(double amount) {
    return NumberFormat('#,###', 'vi_VN').format(amount);
  }

  int get _pointsEarned => (_selectedMoney / 100).floor();

  void _selectPreset(double amt) {
    setState(() {
      _selectedMoney = amt;
      _amountController.text = _formatNumber(amt);
      _errorMessage = null;
    });
  }

  void _onInputChanged(String text) {
    final cleanText = text.replaceAll('.', '').replaceAll(',', '').trim();
    final parsed = double.tryParse(cleanText);
    if (parsed != null) {
      setState(() {
        _selectedMoney = parsed;
        _errorMessage = null;
      });
    }
  }

  Future<void> _handleConfirm() async {
    if (_selectedMoney < 10000) {
      setState(() => _errorMessage = 'Số tiền đổi tối thiểu là 10,000 VNĐ');
      return;
    }
    if (_selectedMoney % 10000 != 0) {
      setState(() => _errorMessage = 'Số tiền đổi phải là bội số của 10,000 VNĐ');
      return;
    }
    if (_selectedMoney > widget.availableBalance) {
      setState(() => _errorMessage = 'Số tiền vượt quá số dư ví khả dụng');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final msg = await widget.onConfirmConvert(_selectedMoney);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(msg.isNotEmpty ? msg : 'Đã đổi thành công $_pointsEarned điểm tích lũy!'),
            backgroundColor: Colors.green,
          ),
        );
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
                  color: AppColors.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.published_with_changes_rounded,
                  color: AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Đổi tiền mặt sang Điểm thưởng',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  Text(
                    'Tăng điểm để nâng hạng thành viên nhanh chóng',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 18),

          // Conversion Rate Preview Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFFFD54F)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Tỷ lệ quy đổi 1 chiều',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${_formatNumber(_selectedMoney)} VNĐ',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const Icon(Icons.arrow_forward_rounded, color: AppColors.primary),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text(
                      'Điểm thưởng nhận được',
                      style: TextStyle(fontSize: 11, color: Colors.black54),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '+$_pointsEarned điểm',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Presets
          const Text(
            'Mốc tiền quy đổi',
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
            children: _presetMoney.map((amt) {
              final isSelected = _selectedMoney == amt;
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
          const SizedBox(height: 16),

          // Custom Input
          TextField(
            controller: _amountController,
            keyboardType: TextInputType.number,
            onChanged: _onInputChanged,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
            decoration: InputDecoration(
              labelText: 'Hoặc nhập số tiền khác (Bội số 10,000đ)',
              suffixText: 'VNĐ',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
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

          const SizedBox(height: 22),

          // Confirm button
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
                  : Text(
                      'Xác nhận quy đổi +$_pointsEarned điểm',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
