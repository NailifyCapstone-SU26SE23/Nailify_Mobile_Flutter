import 'package:flutter/widgets.dart';

import 'l10n.dart';

/// Tiện ích giúp gọi `S.of(context)` qua `context.l10n.foo` với cú pháp gọn.
/// Hữu ích cho code mới; code cũ vẫn dùng `S.of(context)`.
extension L10nContextX on BuildContext {
  S get l10n => S.of(this);
}
