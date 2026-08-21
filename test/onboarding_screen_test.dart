import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cyber_visualiser/screens/onboarding_screen.dart';
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

import 'package:cyber_visualiser/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Onboarding Screen slider flow validation', (
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
        child: MaterialApp(
          theme: AppTheme.light,
          home: const OnboardingScreen(autoInitializeConnectionOnFinish: false),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Slide 1: Welcome page verification
    expect(find.text('Immersive Threat Intel'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);

    // Tap Next to navigate to Slide 2
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Slide 2: Liquid Galaxy setup verification
    expect(find.text('Liquid Galaxy Rig Connection'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'IP Address'), findsOneWidget);

    // Tap Next to navigate to Slide 3
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Slide 3: API keys page verification
    expect(find.text('API Integrations'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'HoneyLabs API Key'), findsOneWidget);

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

    // Tap Next to navigate to Slide 4
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // Slide 4: Features overview verification
    expect(find.text('Explore Cyber Visualiser Features'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
    expect(find.text('Threat Intel Dashboard'), findsOneWidget);

    // Tap Get Started to finish onboarding
    await tester.tap(find.text('Get Started'));
    await tester.pumpAndSettle();

    // Verify SharedPreferences is updated
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('completed_onboarding'), true);
  });
}

class MockHistoricalRepository extends HistoricalRepository {
  @override
  Future<List<HistoricalAttack>> getHistoricalAttacks() async {
    return [];
  }
}
