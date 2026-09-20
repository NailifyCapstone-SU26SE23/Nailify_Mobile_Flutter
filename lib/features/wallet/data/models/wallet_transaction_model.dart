enum WalletTxType {
  deposit,
  withdraw,
  bookingPayment,
  convertToPoints,
  refund,
  unknown;

  static WalletTxType fromString(String? val) {
    if (val == null) return WalletTxType.unknown;
    final lower = val.toLowerCase();
    if (lower.contains('deposit')) return WalletTxType.deposit;
    if (lower.contains('withdraw')) return WalletTxType.withdraw;
    if (lower.contains('booking') || lower.contains('payment')) return WalletTxType.bookingPayment;
    if (lower.contains('convert')) return WalletTxType.convertToPoints;
    if (lower.contains('refund')) return WalletTxType.refund;
    return WalletTxType.unknown;
  }
}

enum WalletTxStatus {
  completed,
  pending,
  failed,
  cancelled,
  unknown;

  static WalletTxStatus fromString(String? val) {
    if (val == null) return WalletTxStatus.unknown;
    final lower = val.toLowerCase();
    if (lower.contains('completed') || lower.contains('success')) return WalletTxStatus.completed;
    if (lower.contains('pending')) return WalletTxStatus.pending;
    if (lower.contains('failed')) return WalletTxStatus.failed;
    if (lower.contains('cancel')) return WalletTxStatus.cancelled;
    return WalletTxStatus.unknown;
  }
}

class WalletTransactionModel {
  final String walletTransactionId;
  final String walletId;
  final double amount;
  final double balanceBefore;
  final double balanceAfter;
  final WalletTxType type;
  final WalletTxStatus status;
  final String? referenceId;
  final String? referenceType;
  final String description;
  final DateTime createdAt;

  const WalletTransactionModel({
    required this.walletTransactionId,
    required this.walletId,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.type,
    required this.status,
    this.referenceId,
    this.referenceType,
    required this.description,
    required this.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      walletTransactionId: json['walletTransactionId']?.toString() ?? '',
      walletId: json['walletId']?.toString() ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      balanceBefore: (json['balanceBefore'] as num?)?.toDouble() ?? 0.0,
      balanceAfter: (json['balanceAfter'] as num?)?.toDouble() ?? 0.0,
      type: WalletTxType.fromString(json['type']?.toString()),
      status: WalletTxStatus.fromString(json['status']?.toString()),
      referenceId: json['referenceId']?.toString(),
      referenceType: json['referenceType']?.toString(),
      description: json['description']?.toString() ?? '',
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'].toString())
          : DateTime.now(),
    );
  }

  bool get isPositive =>
      type == WalletTxType.deposit || type == WalletTxType.refund;
}

class PaginatedWalletTransactions {
  final List<WalletTransactionModel> items;
  final int page;
  final bool hasNextPage;
  final int totalItems;

  const PaginatedWalletTransactions({
    required this.items,
    required this.page,
    required this.hasNextPage,
    required this.totalItems,
  });

  factory PaginatedWalletTransactions.fromJson(Map<String, dynamic> json) {
    final data = json['data'] is Map ? json['data'] as Map : json;
    final itemsList = (data['items'] as List?)
            ?.whereType<Map>()
            .map((e) => WalletTransactionModel.fromJson(Map<String, dynamic>.from(e)))
            .toList() ??
        const [];
    final meta = data['metaData'] as Map? ?? {};
    return PaginatedWalletTransactions(
      items: itemsList,
      page: meta['currentPage'] as int? ?? 1,
      hasNextPage: meta['hasNext'] as bool? ?? false,
      totalItems: meta['totalItems'] as int? ?? itemsList.length,
    );
  }
}
