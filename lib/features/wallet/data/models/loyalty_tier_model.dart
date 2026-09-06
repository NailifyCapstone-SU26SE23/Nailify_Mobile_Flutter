import 'package:flutter/material.dart';

class LoyaltyTierModel {
  final int loyaltyTierId;
  final String name;
  final String? description;
  final int minLifetimePoints;
  final int? maxLifetimePoints;
  final double discountRate;
  final String? imageUrl;
  final String? backgroundColor;
  final String? textColor;
  final String? colorJson;
  final String status;
  final int sortOrder;

  const LoyaltyTierModel({
    required this.loyaltyTierId,
    required this.name,
    this.description,
    required this.minLifetimePoints,
    this.maxLifetimePoints,
    required this.discountRate,
    this.imageUrl,
    this.backgroundColor,
    this.textColor,
    this.colorJson,
    required this.status,
    required this.sortOrder,
  });

  factory LoyaltyTierModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyTierModel(
      loyaltyTierId: (json['loyaltyTierId'] as num?)?.toInt() ?? 0,
      name: json['name']?.toString() ?? '',
      description: json['description']?.toString(),
      minLifetimePoints: (json['minLifetimePoints'] as num?)?.toInt() ?? 0,
      maxLifetimePoints: (json['maxLifetimePoints'] as num?)?.toInt(),
      discountRate: (json['discountRate'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['imageUrl']?.toString(),
      backgroundColor: json['backgroundColor']?.toString(),
      textColor: json['textColor']?.toString(),
      colorJson: json['colorJson']?.toString(),
      status: json['status']?.toString() ?? '',
      sortOrder: (json['sortOrder'] as num?)?.toInt() ?? 0,
    );
  }

  /// Parse `backgroundColor` (e.g. "#9B7BB8") sang Color, fallback null nếu lỗi.
  Color? get parsedBackgroundColor {
    final raw = backgroundColor?.trim();
    if (raw == null || raw.isEmpty) return null;
    try {
      final cleaned = raw.replaceFirst('#', '').replaceAll(' ', '');
      final value = int.parse('FF$cleaned', radix: 16);
      return Color(value);
    } catch (_) {
      return null;
    }
  }

  Color? get parsedTextColor {
    final raw = textColor?.trim();
    if (raw == null || raw.isEmpty) return null;
    try {
      final cleaned = raw.replaceFirst('#', '').replaceAll(' ', '');
      final value = int.parse('FF$cleaned', radix: 16);
      return Color(value);
    } catch (_) {
      return null;
    }
  }

  /// Discount rate dạng text, ví dụ: 0.01 -> "1% off".
  String get discountLabel {
    final percent = (discountRate * 100);
    if (percent % 1 == 0) {
      return '${percent.toInt()}%';
    }
    return '${percent.toStringAsFixed(2)}%';
  }

  Map<String, dynamic> toJson() => {
        'loyaltyTierId': loyaltyTierId,
        'name': name,
        'description': description,
        'minLifetimePoints': minLifetimePoints,
        'maxLifetimePoints': maxLifetimePoints,
        'discountRate': discountRate,
        'imageUrl': imageUrl,
        'backgroundColor': backgroundColor,
        'textColor': textColor,
        'colorJson': colorJson,
        'status': status,
        'sortOrder': sortOrder,
      };
}
