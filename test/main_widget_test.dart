import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cyber_visualiser/main.dart';
import 'package:cyber_visualiser/services/lg_service.dart';
import 'package:cyber_visualiser/services/lg_adapter.dart';
import 'package:cyber_visualiser/services/track_ip_lg_service.dart';
import 'package:cyber_visualiser/services/abuseipdb_service.dart';
import 'package:cyber_visualiser/services/honeylabs_service.dart';
import 'package:cyber_visualiser/repositories/attack_repository.dart';
import 'package:cyber_visualiser/repositories/track_ip_repository.dart';
import 'package:cyber_visualiser/providers/attack_provider.dart';
import 'package:cyber_visualiser/providers/track_ip_provider.dart';
import 'package:cyber_visualiser/theme/theme_notifier.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App renders home and settings navigation', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final apiService = HoneyLabsService();
    final repository = AttackRepository(apiService);

    final abuseDbService = AbuseIpDbService();
    final trackRepository = TrackIpRepository(abuseDbService);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),
          ChangeNotifierProvider<LgService>(create: (_) => LgService()),
          ProxyProvider<LgService, LgAdapter>(
            update: (_, lgService, __) => LgAdapter(lgService),
          ),
          ProxyProvider<LgService, TrackIpLgService>(
            update: (_, lgService, __) => TrackIpLgService(lgService),
          ),
          ChangeNotifierProvider<AttackProvider>(
            create: (_) => AttackProvider(repository)..stopPolling(), // Stop periodic timers in tests
          ),
          ChangeNotifierProvider<TrackIpProvider>(
            create: (_) => TrackIpProvider(trackRepository),
          ),
        ],
        child: const MaterialApp(home: AppShell(autoInitializeConnection: false)),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Dashboard signature
    expect(find.text('Liquid Galaxy Dashboard'), findsOneWidget);
    expect(find.byIcon(Icons.dashboard_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);

    // Tap on Connection Settings tab
    await tester.tap(find.text('Connection Settings'));
    await tester.pumpAndSettle();

    // Verify it navigates to settings screen
    expect(find.text('Liquid Galaxy Settings'), findsOneWidget);
  });
}
