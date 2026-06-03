import 'package:flutter/material.dart';
class AppLocalizations {
  static const delegate = _AppLocalizationsDelegate();
  static const supportedLocales = [Locale('vi'), Locale('en')];
}
class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();
  @override bool isSupported(Locale locale) => ['vi', 'en'].contains(locale.languageCode);
  @override Future<AppLocalizations> load(Locale locale) async => AppLocalizations();
  @override bool shouldReload(LocalizationsDelegate<AppLocalizations> old) => false;
}

// chuyển đổi ngôn ngữ, chưa cần đụng tới