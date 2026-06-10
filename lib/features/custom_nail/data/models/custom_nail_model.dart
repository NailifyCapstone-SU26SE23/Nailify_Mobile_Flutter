class CustomNailModel {
  String selectedShape = 'Oval';
  double lengthValue = 2.0; // 0: Very Short, 1: Short, 2: Medium, 3: Long, 4: Very Long
  String selectedColor = '';
  String selectedPattern = '';
  List<String> accessories = [];

  String get lengthText {
    const labels = ['Very Short', 'Short', 'Medium', 'Long', 'Very Long'];
    return labels[lengthValue.toInt()];
  }
}