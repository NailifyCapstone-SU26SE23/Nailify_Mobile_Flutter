class PriceFormatter {
  /// Định dạng giá tiền từ số thô (ví dụ: 222000.0) thành chuỗi chuẩn dạng "222,000 VNĐ"
  static String format(dynamic price) {
    if (price == null) return '0 VNĐ';

    num? numericPrice;
    if (price is num) {
      numericPrice = price;
    } else if (price is String) {
      // Dọn dẹp chuỗi nếu có ký tự lạ trước khi parse
      final cleanString = price.replaceAll(RegExp(r'[^0-9.]'), '');
      numericPrice = num.tryParse(cleanString);
    }

    if (numericPrice == null) return '0 VNĐ';

    // Đơn vị tiền tệ VNĐ không sử dụng phần thập phân lẻ, chuyển đổi hẳn về số nguyên (int)
    int intPrice = numericPrice.toInt();

    // Sử dụng biểu thức chính quy (RegExp) để thêm dấu phẩy ngăn cách mỗi 3 chữ số
    String formattedNumber = intPrice.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (Match m) => '${m[1]},',
    );

    return '$formattedNumber VNĐ';
  }

  /// Calculates deposit rate/text and amount based on configuration and total price
  static Map<String, dynamic> getDepositInfo(dynamic config, num totalAmount) {
    if (config == null) {
      final amount = (totalAmount * 0.2).round();
      return {'displayText': '20%', 'amount': amount};
    }

    // If it's a Map
    if (config is Map) {
      final val =
          config['percentage'] ??
          config['value'] ??
          config['amount'] ??
          config['depositConfig'];
      return getDepositInfo(val, totalAmount);
    }

    // If it's a String
    if (config is String) {
      final clean = config.replaceAll(RegExp(r'[^\d\.]'), '').trim();
      final parsed = double.tryParse(clean);
      if (parsed != null) {
        if (config.contains('%')) {
          final amount = (totalAmount * parsed / 100).round();
          return {
            'displayText':
                '${parsed.toStringAsFixed(parsed % 1 == 0 ? 0 : 1)}%',
            'amount': amount,
          };
        }
        if (parsed > 0.0 && parsed <= 1.0) {
          final pct = parsed * 100.0;
          final amount = (totalAmount * parsed).round();
          return {
            'displayText': '${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%',
            'amount': amount,
          };
        } else if (parsed > 1.0 && parsed <= 100) {
          final amount = (totalAmount * parsed / 100).round();
          return {
            'displayText':
                '${parsed.toStringAsFixed(parsed % 1 == 0 ? 0 : 1)}%',
            'amount': amount,
          };
        } else {
          return {
            'displayText': format(parsed.round()),
            'amount': parsed.round(),
          };
        }
      }
      final amount = (totalAmount * 0.2).round();
      return {'displayText': config, 'amount': amount};
    }

    // If it's a number
    if (config is num) {
      final val = config.toDouble();
      if (val > 0.0 && val <= 1.0) {
        final pct = val * 100.0;
        final amount = (totalAmount * val).round();
        return {
          'displayText': '${pct.toStringAsFixed(pct % 1 == 0 ? 0 : 1)}%',
          'amount': amount,
        };
      } else if (val > 1.0 && val <= 100) {
        final amount = (totalAmount * val / 100).round();
        return {
          'displayText': '${val.toStringAsFixed(val % 1 == 0 ? 0 : 1)}%',
          'amount': amount,
        };
      } else {
        return {'displayText': format(val.round()), 'amount': val.round()};
      }
    }

    final amount = (totalAmount * 0.2).round();
    return {'displayText': '20%', 'amount': amount};
  }
}
