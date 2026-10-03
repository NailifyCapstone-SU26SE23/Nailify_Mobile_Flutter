import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData get lightTheme =>
      ThemeData(brightness: Brightness.light, useMaterial3: true);
  static ThemeData get darkTheme =>
      ThemeData(brightness: Brightness.dark, useMaterial3: true);
}
