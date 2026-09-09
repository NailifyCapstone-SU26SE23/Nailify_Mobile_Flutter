import 'dart:async';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/network/api_client.dart';
import '../../../../core/utils/paginated_response.dart';
import '../datasources/wallet_api_service.dart';
import '../models/loyalty_model.dart';
import '../models/loyalty_transaction_model.dart';
import '../models/redeem_outcome.dart';
import '../models/redeemable_promotion_model.dart';
import '../models/wallet_overview_model.dart';
import '../models/wallet_voucher_model.dart';

/// Repository cho Wallet feature.
/// Delegate xuống [WalletApiService] cho network, đồng thời cache local
/// để có thể hiển thị ngay khi mở màn hình (warm-start).
class WalletRepository {
  final WalletApiService _apiService;
  final SharedPreferences? _prefs;

  WalletRepository(
    ApiClient apiClient, {
    WalletApiService? apiService,
    SharedPreferences? prefs,
  }) : _apiService = apiService ?? WalletApiService(apiClient),
       _prefs = prefs;

  // ─── Cache keys ──────────────────────────────────────────────────
  static const _kCacheOverview = 'wallet_overview_cache_v1';
  static const _kCacheVouchers = 'wallet_vouchers_cache_v1';
  static const _kCacheLoyalty = 'wallet_loyalty_cache_v1';

  // TTLs
  static const Duration overviewTtl = Duration(minutes: 5);
  static const Duration vouchersTtl = Duration(minutes: 1);

  // ─── Cache helpers ────────────────────────────────────────────────
  DateTime? _cachedAt(String key) {
    final ts = _prefs?.getString('${key}_ts');
    if (ts == null) return null;
    return DateTime.tryParse(ts);
  }

  Future<void> _writeCache(String key, Map<String, dynamic> payload) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(key, jsonEncode(payload));
    await prefs.setString('${key}_ts', DateTime.now().toIso8601String());
  }

  Future<void> _writeListCache(
    String key,
    List<Map<String, dynamic>> items,
  ) async {
    final prefs = _prefs;
    if (prefs == null) return;
    await prefs.setString(key, jsonEncode(items));
    await prefs.setString('${key}_ts', DateTime.now().toIso8601String());
  }

  Map<String, dynamic>? _readCache(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return null;
    } catch (_) {
      return null;
    }
  }

  List<Map<String, dynamic>>? _readListCache(String key) {
    final raw = _prefs?.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  bool _isFresh(String key, Duration ttl) {
    final ts = _cachedAt(key);
    if (ts == null) return false;
    return DateTime.now().difference(ts) < ttl;
  }

  /// Xóa toàn bộ cache. Gọi khi logout.
  Future<void> clearCache() async {
    final prefs = _prefs;
    if (prefs == null) return;
    await Future.wait([
      prefs.remove(_kCacheOverview),
      prefs.remove('${_kCacheOverview}_ts'),
      prefs.remove(_kCacheVouchers),
      prefs.remove('${_kCacheVouchers}_ts'),
      prefs.remove(_kCacheLoyalty),
      prefs.remove('${_kCacheLoyalty}_ts'),
    ]);
  }

  // ─── Loyalty ──────────────────────────────────────────────────────
  Future<LoyaltyModel> getLoyalty({bool forceRefresh = false}) async {
    if (!forceRefresh && _isFresh(_kCacheLoyalty, overviewTtl)) {
      final cached = _readCache(_kCacheLoyalty);
      if (cached != null) {
        try {
          return LoyaltyModel.fromJson(cached);
        } catch (_) {
          // Fallback xuống API nếu cache lỗi
        }
      }
    }
    final fresh = await _apiService.getLoyalty();
    await _writeCache(_kCacheLoyalty, fresh.toJson());
    return fresh;
  }

  // ─── Wallet Vouchers ──────────────────────────────────────────────
  Future<List<WalletVoucherModel>> getMyWalletVouchers({
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && _isFresh(_kCacheVouchers, vouchersTtl)) {
      final cached = _readListCache(_kCacheVouchers);
      if (cached != null) {
        return cached.map(WalletVoucherModel.fromJson).toList();
      }
    }
    final fresh = await _apiService.getMyWalletVouchers();
    await _writeListCache(
      _kCacheVouchers,
      fresh.map((e) {
        // Build minimal cache payload (WalletVoucherModel.fromJson đọc lại đúng).
        return <String, dynamic>{
          'userPromotionUsageId': e.userPromotionUsageId,
          'promotionId': e.promotionId,
          'promotionName': e.promotionName,
          'description': e.description,
          'discountType': e.discountType,
          'discountValue': e.discountValue,
          'receivedCount': e.receivedCount,
          'usageCount': e.usageCount,
          'remainingCount': e.remainingCount,
          'startDate': e.startDate?.toIso8601String(),
          'endDate': e.endDate?.toIso8601String(),
          'imageUrl': e.imageUrl,
          'isValidForUse': e.isValidForUse,
        };
      }).toList(),
    );
    return fresh;
  }

  // ─── Overview snapshot ────────────────────────────────────────────
  Future<WalletOverviewSnapshot> getOverview({
    bool forceRefresh = false,
  }) async {
    // Thử cache overview trước (nếu còn hạn).
    if (!forceRefresh && _isFresh(_kCacheOverview, overviewTtl)) {
      final cached = _readCache(_kCacheOverview);
      if (cached != null) {
        try {
          final loyaltyJson = cached['loyalty'] as Map<String, dynamic>?;
          final vouchersJson =
              (cached['vouchers'] as List?)
                  ?.whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList() ??
              const [];
          if (loyaltyJson != null) {
            return WalletOverviewSnapshot(
              loyalty: LoyaltyModel.fromJson(loyaltyJson),
              vouchers: vouchersJson.map(WalletVoucherModel.fromJson).toList(),
            );
          }
        } catch (_) {
          // Fallthrough xuống gọi API
        }
      }
    }

    // Gọi song song 2 endpoint; nếu 1 fail vẫn trả data còn lại.
    final results = await Future.wait([
      _apiService.getLoyalty(),
      _apiService.getMyWalletVouchers(),
    ]);

    final loyalty = results[0] as LoyaltyModel;
    final vouchers = results[1] as List<WalletVoucherModel>;

    await _writeCache(_kCacheOverview, {
      'loyalty': loyalty.toJson(),
      'vouchers': vouchers
          .map(
            (e) => <String, dynamic>{
              'userPromotionUsageId': e.userPromotionUsageId,
              'promotionId': e.promotionId,
              'promotionName': e.promotionName,
              'description': e.description,
              'discountType': e.discountType,
              'discountValue': e.discountValue,
              'receivedCount': e.receivedCount,
              'usageCount': e.usageCount,
              'remainingCount': e.remainingCount,
              'startDate': e.startDate?.toIso8601String(),
              'endDate': e.endDate?.toIso8601String(),
              'imageUrl': e.imageUrl,
              'isValidForUse': e.isValidForUse,
            },
          )
          .toList(),
    });

    return WalletOverviewSnapshot(loyalty: loyalty, vouchers: vouchers);
  }

  // ─── Redeemable ──────────────────────────────────────────────────
  Future<PaginatedResponse<RedeemablePromotionModel>> getRedeemable({
    int page = 1,
    int pageSize = 10,
  }) {
    return _apiService.getRedeemable(page: page, pageSize: pageSize);
  }

  // ─── Redeem ──────────────────────────────────────────────────────
  Future<RedeemOutcome> redeem(int promotionId) async {
    final outcome = await _apiService.redeem(promotionId);
    // Invalidate cache liên quan để refresh sau khi redeem.
    await clearCache();
    return outcome;
  }

  // ─── Loyalty Transactions History ────────────────────────────────
  // Cache key + TTL riêng để tránh chung TTL với overview.
  static const _kCacheTransactions = 'wallet_loyalty_transactions_cache_v1';
  static const Duration transactionsTtl = Duration(minutes: 2);

  Future<PaginatedLoyaltyTransactions> getMyLoyaltyTransactions({
    int pageNumber = 1,
    int pageSize = 20,
    bool forceRefresh = false,
  }) async {
    final isFirstPage = pageNumber == 1;
    final cacheKey = '${_kCacheTransactions}_p$pageNumber';

    if (isFirstPage && !forceRefresh && _isFresh(cacheKey, transactionsTtl)) {
      final cached = _readCache(cacheKey);
      if (cached != null) {
        try {
          return PaginatedLoyaltyTransactions.fromJson(cached);
        } catch (_) {
          // Fallback xuống API
        }
      }
    }

    final fresh = await _apiService.getMyLoyaltyTransactions(
      pageNumber: pageNumber,
      pageSize: pageSize,
    );

    if (isFirstPage) {
      await _writeCache(cacheKey, <String, dynamic>{
        'data': <String, dynamic>{
          'items': fresh.items
              .map(
                (t) => <String, dynamic>{
                  'loyaltyTransactionId': t.loyaltyTransactionId,
                  'customerId': t.customerId,
                  'bookingId': t.bookingId,
                  'points': t.points,
                  'transactionType': t.transactionType.name,
                  'loyaltyTierIdAtTime': t.loyaltyTierIdAtTime,
                  'createdAt': t.createdAt.toIso8601String(),
                },
              )
              .toList(),
          'metaData': <String, dynamic>{
            'currentPage': fresh.page,
            'hasNext': fresh.hasNextPage,
            'totalItems': fresh.totalItems,
          },
        },
      });
    }

    return fresh;
  }
}
