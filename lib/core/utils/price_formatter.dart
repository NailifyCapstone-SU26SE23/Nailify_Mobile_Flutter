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
}