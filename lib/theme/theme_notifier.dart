import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeNotifier extends ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.system;

  ThemeMode get themeMode => _themeMode;

  Future<void> loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final storedValue = prefs.getString(_themeModeKey);
    _themeMode = _parseThemeMode(storedValue) ?? ThemeMode.system;
    notifyListeners();
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, _themeMode.name);
  }

  Future<void> toggleTheme() async {
    final nextMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    await setThemeMode(nextMode);
  }

  ThemeMode? _parseThemeMode(String? value) {
    if (value == null) {
      return null;
    }

    return ThemeMode.values.firstWhere(
      (mode) => mode.name == value,
      orElse: () => ThemeMode.system,
    );
  }
}
