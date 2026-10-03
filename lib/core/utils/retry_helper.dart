/// Helper retry cho các API call dễ bị lỗi thoáng qua (timeout, 5xx,
/// network). Khi hết retry mà vẫn lỗi, ném lại exception để caller xử
/// lý (vd: hiển thị nút "Thử lại" cho user).
///
/// Lưu ý: KHÔNG retry cho lỗi 4xx (client error, validation) — chỉ
/// retry cho network/timeout/5xx.
library;

class RetryHelper {
  /// Tối đa 2 retry (tổng 3 lần thử). Backoff cố định 400ms/lần.
  static const int defaultMaxRetries = 2;
  static const Duration defaultBackoff = Duration(milliseconds: 400);

  /// Chạy [action] tối đa `maxRetries + 1` lần, với backoff giữa các lần
  /// retry. Nếu [shouldRetry] trả về `false` thì dừng retry ngay (dùng để
  /// bỏ qua lỗi client 4xx).
  ///
  /// Trả về kết quả của lần thử cuối (nếu throw thì rethrow).
  static Future<T> run<T>(
    Future<T> Function() action, {
    int maxRetries = defaultMaxRetries,
    Duration backoff = defaultBackoff,
    bool Function(Object error)? shouldRetry,
  }) async {
    Object? lastError;
    for (var attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        return await action();
      } catch (e) {
        lastError = e;
        if (shouldRetry != null && !shouldRetry(e)) rethrow;
        if (attempt >= maxRetries) rethrow;
        await Future<void>.delayed(backoff * (attempt + 1));
      }
    }
    // Không bao giờ vào đây, nhưng Dart yêu cầu return.
    throw lastError ?? 'RetryHelper: unknown error';
  }

  /// Default `shouldRetry`: chỉ retry nếu không phải lỗi validation/
  /// authorization (4xx).
  static bool defaultShouldRetry(Object error) {
    final s = error.toString();
    if (s.contains('400') ||
        s.contains('401') ||
        s.contains('403') ||
        s.contains('404') ||
        s.contains('validation') ||
        s.contains('VALIDATION')) {
      return false;
    }
    return true;
  }
}
