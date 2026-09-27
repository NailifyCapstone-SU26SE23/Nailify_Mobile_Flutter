class CustomerWalletSummaryModel {
  final String walletId;
  final String customerId;
  final double balance;
  final double frozenBalance;
  final double availableBalance;
  final int loyaltyPoints;
  final int lifetimePoints;
  final String? loyaltyTierName;
  final String status;
  final DateTime createdAt;

  const CustomerWalletSummaryModel({
    required this.walletId,
    required this.customerId,
    required this.balance,
    required this.frozenBalance,
    required this.availableBalance,
    required this.loyaltyPoints,
    required this.lifetimePoints,
    this.loyaltyTierName,
    required this.status,
    required this.createdAt,
  });

  factory CustomerWalletSummaryModel.fromJson(Map<String, dynamic> json) {
    return CustomerWalletSummaryModel(
      walletId: json['walletId']?.toString() ?? '',
      customerId: json['customerId']?.toString() ?? '',
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      frozenBalance: (json['frozenBalance'] as num?)?.toDouble() ?? 0.0,
      availableBalance: (json['availableBalance'] as num?)?.toDouble() ?? 0.0,
      loyaltyPoints:
          json['loyaltyPoints'] as int? ?? json['loyaltyPoint'] as int? ?? 0,
      lifetimePoints: json['lifetimePoints'] as int? ?? 0,
      loyaltyTierName: json['loyaltyTierName']?.toString(),
      status: json['status']?.toString() ?? 'Active',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'walletId': walletId,
      'customerId': customerId,
      'balance': balance,
      'frozenBalance': frozenBalance,
      'availableBalance': availableBalance,
      'loyaltyPoints': loyaltyPoints,
      'lifetimePoints': lifetimePoints,
      'loyaltyTierName': loyaltyTierName,
      'status': status,
      'createdAt': createdAt.toIso8601String(),
    };
  }
}
