import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cyber_visualiser/pages/settings_page.dart';
import 'package:cyber_visualiser/services/lg_service.dart';
import 'package:cyber_visualiser/theme/theme_notifier.dart';

class MockLgService extends LgService {
  MockLgService() : super.internal();

  bool connectToLGCalled = false;

  @override
  Future<bool?> connectToLG() async {
    connectToLGCalled = true;
    return true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'SettingsPage Connect to LG button saves connection settings without clicking Save Settings',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});
      const secureChannel = MethodChannel(
        'plugins.it_nomads.com/flutter_secure_storage',
      );
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        secureChannel,
        (MethodCall methodCall) async {
          return null;
        },
      );

      final mockLgService = MockLgService();

      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<ThemeNotifier>(
              create: (_) => ThemeNotifier(),
            ),
            ChangeNotifierProvider<LgService>.value(value: mockLgService),
          ],
          child: const MaterialApp(home: Scaffold(body: SettingsPage())),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Settings page has rendered
      expect(find.text('SETTINGS'), findsOneWidget);

      // Enter new details in the input text fields
      final ipField = find.widgetWithText(TextField, 'IP address');
      final portField = find.widgetWithText(TextField, 'Port');
      final usernameField = find.widgetWithText(TextField, 'Username');
      final passwordField = find.widgetWithText(TextField, 'Password');
      final screensField = find.widgetWithText(TextField, 'Screens');

      expect(ipField, findsOneWidget);
      expect(portField, findsOneWidget);
      expect(usernameField, findsOneWidget);
      expect(passwordField, findsOneWidget);
      expect(screensField, findsOneWidget);

      await tester.enterText(ipField, '192.168.1.50');
      await tester.enterText(portField, '2222');
      await tester.enterText(usernameField, 'lg-test');
      await tester.enterText(passwordField, 'lg-pass');
      await tester.enterText(screensField, '5');
      await tester.enterText(
        find.widgetWithText(TextField, 'HoneyLabs API Key'),
        'mock-hl-key',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'AbuseIPDB API Key'),
        'mock-abuse-key',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Gemini API Key'),
        'mock-gemini-key',
      );

      await tester.pumpAndSettle();

      // Tap on "Connect to LG" button directly
      final connectButton = find.widgetWithText(
        ElevatedButton,
        'Connect to LG',
      );
      expect(connectButton, findsOneWidget);

      // Ensure the button is scrolled into view before tapping
      await tester.ensureVisible(connectButton);
      await tester.pumpAndSettle();

      await tester.tap(connectButton);
      await tester.pumpAndSettle();

      // Verify connectToLG was called
      expect(mockLgService.connectToLGCalled, true);

      // Verify settings were saved in the connection model
      expect(mockLgService.connectionModel.ip, '192.168.1.50');
      expect(mockLgService.connectionModel.port, 2222);
      expect(mockLgService.connectionModel.username, 'lg-test');
      expect(mockLgService.connectionModel.password, 'lg-pass');
      expect(mockLgService.connectionModel.screens, 5);

      // Verify settings were persisted to SharedPreferences
      final loaded = await LgConnectionModel.loadFromPreferences();
      expect(loaded.ip, '192.168.1.50');
      expect(loaded.port, 2222);
      expect(loaded.username, 'lg-test');
      expect(loaded.password, 'lg-pass');
      expect(loaded.screens, 5);
    },
  );
}
