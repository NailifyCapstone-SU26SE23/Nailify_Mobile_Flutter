import 'dart:convert';
import 'dart:typed_data';

class Base64ImageConverter {
  /// Giải mã chuỗi Base64 thành danh sách byte hình ảnh.
  static Uint8List? decode(String? base64String) {
    if (base64String == null || base64String.trim().isEmpty) {
      return null;
    }

    try {
      String cleanBase64 = base64String;

      // 1. Loại bỏ tiền tố data URI nếu có (VD: data:image/png;base64,)
      if (cleanBase64.contains(',')) {
        cleanBase64 = cleanBase64.split(',').last;
      }

      // 2. Lọc sạch: Xóa TẤT CẢ các ký tự không thuộc bảng mã Base64
      // Chỉ giữ lại chữ cái, chữ số, dấu cộng (+), gạch chéo (/), gạch dưới (_), gạch ngang (-) và dấu bằng (=)
      cleanBase64 = cleanBase64.replaceAll(RegExp(r'[^A-Za-z0-9+/=_-]'), '');

      //  Khôi phục Padding: Độ dài chuỗi Base64 bắt buộc phải chia hết cho 4
      int padding = cleanBase64.length % 4;
      if (padding != 0) {
        cleanBase64 += '=' * (4 - padding);
      }

      return base64Decode(cleanBase64);

    } catch (e) {
      return null;
    }
  }
}