import 'loyalty_tier_model.dart';

class LoyaltyModel {
  final int loyaltyPoint;
  final int lifetimePoints;
  final LoyaltyTierModel? loyaltyTier;

  const LoyaltyModel({
    required this.loyaltyPoint,
    required this.lifetimePoints,
    this.loyaltyTier,
  });

  factory LoyaltyModel.fromJson(Map<String, dynamic> json) {
    final tierJson = json['loyaltyTier'];
    return LoyaltyModel(
      loyaltyPoint: (json['loyaltyPoint'] as num?)?.toInt() ?? 0,
      lifetimePoints: (json['lifetimePoints'] as num?)?.toInt() ?? 0,
      loyaltyTier: tierJson is Map
          ? LoyaltyTierModel.fromJson(Map<String, dynamic>.from(tierJson))
          : null,
    );
  }

  /// Phần trăm tiến trình tới mốc kế tiếp dựa trên min/maxLifetimePoints của tier hiện tại.
  /// Trả về 1.0 nếu không xác định được tier kế tiếp (đã ở tier cao nhất).
  double get progressPercent {
    final tier = loyaltyTier;
    if (tier == null) return 0.0;
    final max = tier.maxLifetimePoints;
    if (max == null) {
      // Không rõ tier tiếp theo, hiển thị đầy nếu lifetimePoints > min.
      if (lifetimePoints <= tier.minLifetimePoints) return 0.0;
      return 1.0;
    }
    final span = max - tier.minLifetimePoints;
    if (span <= 0) return 1.0;
    final progress = (lifetimePoints - tier.minLifetimePoints) / span;
    return progress.clamp(0.0, 1.0);
  }

  int? get pointsToNextTier {
    final tier = loyaltyTier;
    if (tier == null) return null;
    final max = tier.maxLifetimePoints;
    if (max == null) return null;
    final remaining = max - lifetimePoints;
    return remaining < 0 ? 0 : remaining;
  }

  bool get hasNextTier => loyaltyTier?.maxLifetimePoints != null;

  Map<String, dynamic> toJson() => {
        'loyaltyPoint': loyaltyPoint,
        'lifetimePoints': lifetimePoints,
        'loyaltyTier': loyaltyTier?.toJson(),
      };

  factory LoyaltyModel.empty() =>
      const LoyaltyModel(loyaltyPoint: 0, lifetimePoints: 0);
}
