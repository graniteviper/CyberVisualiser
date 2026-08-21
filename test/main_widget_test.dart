import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:cyber_visualiser/services/text_to_speech_service.dart';
import 'package:cyber_visualiser/services/gemini_service.dart';
import 'package:cyber_visualiser/features/historical/repository/historical_repository.dart';
import 'package:cyber_visualiser/features/historical/providers/historical_provider.dart';
import 'package:cyber_visualiser/features/historical/models/historical_attack.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App renders home and settings navigation', (
    WidgetTester tester,
  ) async {
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

    final apiService = HoneyLabsService();
    final repository = AttackRepository(apiService);

    final abuseDbService = AbuseIpDbService();
    final trackRepository = TrackIpRepository(abuseDbService);
    final historicalRepository = MockHistoricalRepository();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()),
          ChangeNotifierProvider<LgService>(create: (_) => LgService()),
          ChangeNotifierProvider<TextToSpeechService>(
            create: (_) => TextToSpeechService(),
          ),
          ProxyProvider<LgService, LgAdapter>(
            update: (_, lgService, __) => LgAdapter(lgService),
          ),
          ProxyProvider<LgService, TrackIpLgService>(
            update: (_, lgService, __) => TrackIpLgService(lgService),
          ),
          Provider<GeminiService>(create: (_) => GeminiService()),
          ChangeNotifierProvider<AttackProvider>(
            create: (_) =>
                AttackProvider(repository)
                  ..stopPolling(), // Stop periodic timers in tests
          ),
          ChangeNotifierProvider<TrackIpProvider>(
            create: (_) => TrackIpProvider(trackRepository),
          ),
          ChangeNotifierProvider<HistoricalProvider>(
            create: (_) => HistoricalProvider(historicalRepository),
          ),
        ],
        child: const MaterialApp(
          home: AppShell(autoInitializeConnection: false),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Dashboard signature
    expect(find.text('Liquid Galaxy Dashboard'), findsOneWidget);

    // Verify Settings tab is accessible in the bottom navigation bar
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);

    // Tap on the Settings icon/text in the bottom navigation bar
    await tester.tap(find.byIcon(Icons.settings_rounded));
    await tester.pumpAndSettle();

    // Verify it navigates to settings screen
    expect(find.text('SETTINGS'), findsOneWidget);

    // Tap on the Track IP icon/text in the bottom navigation bar
    await tester.tap(find.byIcon(Icons.location_on_rounded));
    await tester.pumpAndSettle();

    // Verify it navigates to the Track IP screen
    expect(find.text('IP TRACKER'), findsOneWidget);
  });
}

class MockHistoricalRepository extends HistoricalRepository {
  @override
  Future<List<HistoricalAttack>> getHistoricalAttacks() async {
    return [];
  }
}
