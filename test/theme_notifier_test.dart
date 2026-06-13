import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cyber_visualiser/theme/theme_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ThemeNotifier', () {
    test('setThemeMode changes mode and persists value', () async {
      SharedPreferences.setMockInitialValues({});
      final themeNotifier = ThemeNotifier();

      await themeNotifier.setThemeMode(ThemeMode.dark);
      expect(themeNotifier.themeMode, ThemeMode.dark);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('theme_mode'), ThemeMode.dark.name);
    });

    test('loadThemeMode restores persisted theme mode', () async {
      SharedPreferences.setMockInitialValues({'theme_mode': ThemeMode.light.name});
      final themeNotifier = ThemeNotifier();

      await themeNotifier.loadThemeMode();
      expect(themeNotifier.themeMode, ThemeMode.light);
    });
  });
}
