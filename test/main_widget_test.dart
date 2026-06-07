import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cyber_visualiser/main.dart';
import 'package:cyber_visualiser/services/lg_service.dart';
import 'package:cyber_visualiser/theme/theme_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App renders home and settings navigation', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),
          ChangeNotifierProvider<LgService>(create: (_) => LgService()),
        ],
        child: const MaterialApp(home: AppShell(autoInitializeConnection: false)),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Liquid Galaxy Dashboard'), findsOneWidget);
    expect(find.byIcon(Icons.home), findsOneWidget);
    expect(find.byIcon(Icons.settings), findsOneWidget);

    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.text('Liquid Galaxy Settings'), findsOneWidget);
  });
}
