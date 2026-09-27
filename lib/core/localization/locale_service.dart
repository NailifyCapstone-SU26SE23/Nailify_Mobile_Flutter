import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocaleService extends ChangeNotifier {
  final SharedPreferences _prefs;
  Locale _currentLocale = const Locale('vi');

  LocaleService(this._prefs) {
    _currentLocale = Locale(_prefs.getString('lang_code') ?? 'vi');
  }

  Locale get currentLocale => _currentLocale;

  Future<void> toggleLocale() async {
    final newCode = _currentLocale.languageCode == 'vi' ? 'en' : 'vi';
    _currentLocale = Locale(newCode);
    await _prefs.setString('lang_code', newCode);
    notifyListeners();
  }

  Future<void> setLocale(Locale locale) async {
    _currentLocale = locale;
    await _prefs.setString('lang_code', locale.languageCode);
    notifyListeners();
  }
}
