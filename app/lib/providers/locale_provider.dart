import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Holds the app locale (EN default, DE available, or follow system).
/// Persisted so the choice survives restarts.
class LocaleProvider extends ChangeNotifier {
  static const _prefsKey = 'p2ptalk_locale';
  Locale? _locale; // null = follow system

  Locale? get locale => _locale;

  static const supportedLocales = [Locale('en'), Locale('de')];

  Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_prefsKey);
    if (code != null && code.isNotEmpty) {
      _locale = Locale(code);
    }
    notifyListeners();
  }

  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    if (locale == null) {
      await prefs.remove(_prefsKey);
    } else {
      await prefs.setString(_prefsKey, locale.languageCode);
    }
    notifyListeners();
  }
}
