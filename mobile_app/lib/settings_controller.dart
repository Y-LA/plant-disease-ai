import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsController with ChangeNotifier {
  SettingsController(this._prefs) {
    _loadSettings();
  }

  final SharedPreferences _prefs;

  late ThemeMode _themeMode;
  late Locale _locale;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;

  void _loadSettings() {
    // Load ThemeMode, default to system
    final themeIndex = _prefs.getInt('theme_mode') ?? ThemeMode.system.index;
    _themeMode = ThemeMode.values[themeIndex];

    // Load Locale, default to Arabic
    final languageCode = _prefs.getString('language_code') ?? 'ar';
    _locale = Locale(languageCode);
  }

  Future<void> updateThemeMode(ThemeMode? newThemeMode) async {
    if (newThemeMode == null) return;
    if (newThemeMode == _themeMode) return;
    
    _themeMode = newThemeMode;
    notifyListeners();
    await _prefs.setInt('theme_mode', newThemeMode.index);
  }

  Future<void> updateLocale(Locale? newLocale) async {
    if (newLocale == null) return;
    if (newLocale == _locale) return;

    _locale = newLocale;
    notifyListeners();
    await _prefs.setString('language_code', newLocale.languageCode);
  }
}
