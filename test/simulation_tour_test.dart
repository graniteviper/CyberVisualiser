import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cyber_visualiser/pages/simulate_attack_page.dart';
import 'package:cyber_visualiser/services/lg_service.dart';
import 'package:cyber_visualiser/services/text_to_speech_service.dart';
import 'package:cyber_visualiser/services/gemini_service.dart';
import 'package:cyber_visualiser/templates/gemini_prompt_template.dart';

class DummyTextToSpeechService extends ChangeNotifier
    implements TextToSpeechService {
  @override
  VoidCallback? onCompletion;

  @override
  String? get currentUtterance => null;

  bool isSpeakingStatus = false;
  String lastSpokenText = '';

  @override
  bool get isSpeaking => isSpeakingStatus;

  @override
  Future<void> speak(String text, {String? utteranceId}) async {
    lastSpokenText = text;
    isSpeakingStatus = true;
    notifyListeners();
  }

  @override
  Future<void> stop() async {
    isSpeakingStatus = false;
    notifyListeners();
  }
}

class DummyGeminiService extends GeminiService {
  @override
  Future<String> generateThreatSummary(String prompt) async {
    return '''
{
  "overview": "Overview test script.",
  "attackers": [
    {
      "nodeName": "Attacker 1",
      "narration": "Attacker 1 details."
    }
  ],
  "conclusion": "Conclusion details."
}
''';
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Simulation 3D Tour Prompt Template Tests', () {
    test('Should generate valid prompt from simulation data', () {
      final simData = {
        'scenarioName': 'SQL Injection Simulation',
        'summary': 'Test scenario details.',
        'target': {
          'name': 'US Database',
          'locationName': 'USA',
          'latitude': 37.0902,
          'longitude': -95.7129,
          'ip': '1.1.1.1',
          'description': 'Target details',
        },
        'attackers': [
          {
            'name': 'Attacker 1',
            'locationName': 'China',
            'latitude': 35.8617,
            'longitude': 104.1954,
            'ip': '2.2.2.2',
            'threatType': 'SQL injection',
            'severity': 'HIGH',
            'description': 'Description details',
          },
        ],
      };

      final prompt = GeminiPromptTemplate.fillSimulationTourScriptPrompt(
        simData,
      );
      expect(prompt, contains('SQL Injection Simulation'));
      expect(prompt, contains('Target Server: US Database'));
      expect(prompt, contains('Attacker: Attacker 1'));
    });
  });

  group('Simulation Page Widget and Tour UI Tests', () {
    late DummyTextToSpeechService dummyTts;
    late DummyGeminiService dummyGemini;
    late LgService realLg;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      dummyTts = DummyTextToSpeechService();
      dummyGemini = DummyGeminiService();
      realLg = LgService();
    });

    testWidgets(
      'Should render 3D Geographic Tour card with initial generate state',
      (WidgetTester tester) async {
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider<LgService>.value(value: realLg),
              ChangeNotifierProvider<TextToSpeechService>.value(
                value: dummyTts,
              ),
              Provider<GeminiService>.value(value: dummyGemini),
            ],
            child: const MaterialApp(
              home: Scaffold(body: SimulateAttackPage()),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify the tour card is displayed
        expect(find.text('3D GEOGRAPHIC TOUR'), findsOneWidget);
        expect(find.text('No scenario generated yet.'), findsOneWidget);
        expect(find.text('Generate & Start Tour'), findsOneWidget);
      },
    );
  });
}
