import 'package:flutter/material.dart';

class AppColors {
  // ─── Brand Colors ───────────────────────────────────────────
  static const Color primary = Color(0xFFFF66C4);
  static const Color primaryDark = Color(0xFFC44569);
  static const Color primaryLight = Color(0xFFFFE0EC);
  static const Color primarySurface = Color(0xFFFFF0F5);
  static const Color secondary = Color(0xFFFFDE59);

  // ─── System Backgrounds ─────────────────────────────────────
  static const Color background = Colors.white;
  static const Color surfaceLight = Color(0xFFF5F5F5);
  static const Color surface = Colors.white;
  static const Color cardBackground = Colors.white;

  // ─── Text & Border ──────────────────────────────────────────
  static const Color textPrimary = Color(0xFF212121);
  static const Color textSecondary = Color(0xFF757575);
  static const Color borderLight = Color(0xFFE0E0E0);
  static const Color border = Color(0xFFE0E0E0);

  // ─── Status Colors ──────────────────────────────────────────
  static const Color error = Color(0xFFD32F2F);
  static const Color success = Color(0xFF388E3C);

  // ─── Gradients (cũ — giữ nguyên để không break chỗ khác) ───
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient bannerGradient = LinearGradient(
    colors: [primary, secondary],
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
  );

  // ─── Gradients (mới — dùng cho Quiz) ────────────────────────

  /// Dùng cho button, option selected, progress bar — hồng đồng màu
  static const LinearGradient quizGradient = LinearGradient(
    colors: [primary, primaryDark],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Dùng cho nền toàn màn hình QuizPage
  static const LinearGradient quizBgGradient = LinearGradient(
    colors: [
      Color(0xFFFFB3C6),
      Color(0xFFFF66C4),
      Color(0xFFC44569),
    ],
    stops: [0.0, 0.5, 1.0],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
}