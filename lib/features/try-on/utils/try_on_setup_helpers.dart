import 'dart:convert';

import 'package:flutter/material.dart';

Map<String, dynamic> decodeTryOnConfig(String value) {
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map<String, dynamic>) return decoded;
    if (decoded is Map) return Map<String, dynamic>.from(decoded);
  } catch (_) {}
  return const {};
}

double asTryOnDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? fallback;
}

int asTryOnInt(dynamic value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? fallback;
}

Color parseTryOnHexColor(String hex) {
  var hexColor = hex.replaceAll('#', '');
  if (hexColor.length == 6) {
    hexColor = 'FF$hexColor';
  }
  final val = int.tryParse(hexColor, radix: 16);
  if (val != null) {
    return Color(val);
  }
  return const Color(0xFFFF4081);
}

/// UI / AR convention: 1=thumb .. 5=pinky. API often stores 0=thumb .. 4=pinky.
int normalizeFingerIndexFromApi(int stored) {
  if (stored == -1) return -1;
  if (stored >= 0 && stored <= 4) return stored + 1;
  return stored.clamp(1, 5);
}

int fingerIndexToApi(int uiIndex) {
  if (uiIndex == -1) return -1;
  if (uiIndex >= 1 && uiIndex <= 5) return uiIndex - 1;
  return uiIndex;
}

bool placementMatchesFinger(int placementFinger, int selectedFinger) {
  if (selectedFinger == -1) return true;
  if (placementFinger == -1) return false;
  return placementFinger == selectedFinger;
}

extension TryOnIterableExtensions<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T item) test) {
    for (final item in this) {
      if (test(item)) return item;
    }
    return null;
  }

  T? get firstOrNull => isEmpty ? null : first;
}
