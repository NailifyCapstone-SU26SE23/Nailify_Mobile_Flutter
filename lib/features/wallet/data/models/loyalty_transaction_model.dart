/// Loại giao dịch điểm thưởng trả về từ BE.
enum LoyaltyTransactionType {
  earned,
  redeemed,
  expired,
  adjusted,
  unknown,
}

/// Lịch sử biến động điểm của khách hàng (GET /LoyaltyTransactions/me).
class LoyaltyTransactionModel {
  final int loyaltyTransactionId;
  final String? customerId;

  /// Có thể null khi giao dịch không gắn với booking cụ thể
  /// (ví dụ đổi điểm lấy voucher, hoặc điều chỉnh thủ công).
  final String? bookingId;

  /// Số điểm cộng (dương) hoặc trừ (âm).
  final int points;
  final LoyaltyTransactionType transactionType;
  final String? loyaltyTierIdAtTime;
  final DateTime createdAt;

  const LoyaltyTransactionModel({
    required this.loyaltyTransactionId,
    required this.customerId,
    required this.bookingId,
    required this.points,
    required this.transactionType,
    required this.loyaltyTierIdAtTime,
    required this.createdAt,
  });

  bool get isCredit => points > 0;
  bool get isDebit => points < 0;

  /// Label tiếng Việt cho loại giao dịch (dùng khi hiển thị).
  String get typeLabelVi {
    switch (transactionType) {
      case LoyaltyTransactionType.earned:
        return 'Tích điểm';
      case LoyaltyTransactionType.redeemed:
        return 'Đã đổi điểm';
      case LoyaltyTransactionType.expired:
        return 'Điểm hết hạn';
      case LoyaltyTransactionType.adjusted:
        return 'Điều chỉnh điểm';
      case LoyaltyTransactionType.unknown:
        return 'Giao dịch điểm';
    }
  }

  factory LoyaltyTransactionModel.fromJson(Map<String, dynamic> json) {
    return LoyaltyTransactionModel(
      loyaltyTransactionId:
          (json['loyaltyTransactionId'] as num?)?.toInt() ?? 0,
      customerId: json['customerId']?.toString(),
      bookingId: json['bookingId']?.toString(),
      points: (json['points'] as num?)?.toInt() ?? 0,
      transactionType: _parseType(json['transactionType']?.toString()),
      loyaltyTierIdAtTime: json['loyaltyTierIdAtTime']?.toString(),
      createdAt: _parseDate(json['createdAt']) ?? DateTime.now(),
    );
  }

  static LoyaltyTransactionType _parseType(String? raw) {
    switch (raw?.toLowerCase()) {
      case 'earned':
      case 'gain':
      case 'credit':
        return LoyaltyTransactionType.earned;
      case 'redeemed':
      case 'redeem':
      case 'spend':
      case 'debit':
        return LoyaltyTransactionType.redeemed;
      case 'expired':
      case 'expiry':
        return LoyaltyTransactionType.expired;
      case 'adjusted':
      case 'adjust':
      case 'adjustment':
        return LoyaltyTransactionType.adjusted;
      default:
        return LoyaltyTransactionType.unknown;
    }
  }

  static DateTime? _parseDate(dynamic raw) {
    if (raw == null) return null;
    return DateTime.tryParse(raw.toString());
  }
}

/// Paginated wrapper cho GET /LoyaltyTransactions/me.
///
/// BE trả về:
/// ```
/// { isSucceeded, message, data: { items: [...], metaData: {...} } }
/// ```
/// nhưng cũng fallback được cho dạng `items` ở root hoặc `data` là `List`.
class PaginatedLoyaltyTransactions {
  final List<LoyaltyTransactionModel> items;
  final int page;
  final bool hasNextPage;
  final int totalItems;

  const PaginatedLoyaltyTransactions({
    required this.items,
    required this.page,
    required this.hasNextPage,
    required this.totalItems,
  });

  factory PaginatedLoyaltyTransactions.fromJson(Map<String, dynamic> json) {
    List<LoyaltyTransactionModel> parsedItems = const [];
    int page = 1;
    bool hasNext = false;
    int totalItems = 0;

    final data = json['data'];

    if (data is Map) {
      final dataMap = Map<String, dynamic>.from(data);
      final rawItems = dataMap['items'];
      if (rawItems is List) {
        parsedItems = rawItems
            .whereType<Map>()
            .map(
              (e) => LoyaltyTransactionModel.fromJson(
                Map<String, dynamic>.from(e),
              ),
            )
            .toList();
      }
      final meta = dataMap['metaData'];
      if (meta is Map) {
        page = _readInt(meta['currentPage'], 1);
        final rawHasNext = meta['hasNext'];
        hasNext = rawHasNext == true ||
            (rawHasNext is String &&
                (rawHasNext.toLowerCase() == 'true' || rawHasNext == '1'));
        totalItems = _readInt(meta['totalItems'], parsedItems.length);
      } else {
        totalItems = parsedItems.length;
      }
    } else if (data is List) {
      parsedItems = data
          .whereType<Map>()
          .map(
            (e) => LoyaltyTransactionModel.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
      totalItems = parsedItems.length;
    } else if (json['items'] is List) {
      // Fallback: items ngay ở root.
      parsedItems = (json['items'] as List)
          .whereType<Map>()
          .map(
            (e) => LoyaltyTransactionModel.fromJson(
              Map<String, dynamic>.from(e),
            ),
          )
          .toList();
      totalItems = parsedItems.length;
    }

    return PaginatedLoyaltyTransactions(
      items: parsedItems,
      page: page,
      hasNextPage: hasNext,
      totalItems: totalItems,
    );
  }

  static int _readInt(dynamic value, int fallback) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }
}
