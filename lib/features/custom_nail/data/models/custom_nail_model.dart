class FingerConfig {
  String color = 'Soft Pink';
  String pattern = 'French Tip';
  List<String> accessories = [];
}

class CustomNailModel {
  String selectedShape = 'Oval';
  double lengthValue = 2.0;

  // Trạng thái chế độ tùy chỉnh
  bool isApplyAll = true;

  // Cấu hình áp dụng cho cả bàn tay
  FingerConfig globalConfig = FingerConfig();

  // Cấu hình tùy chỉnh riêng cho 5 ngón tay
  Map<String, FingerConfig> fingerConfigs = {
    'Ngón cái': FingerConfig(),
    'Ngón trỏ': FingerConfig(),
    'Ngón giữa': FingerConfig(),
    'Ngón áp út': FingerConfig(),
    'Ngón út': FingerConfig(),
  };

  String get lengthText {
    const labels = ['Very Short', 'Short', 'Medium', 'Long', 'Very Long'];
    return labels[lengthValue.toInt()];
  }
}