import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cyber_visualiser/providers/track_ip_provider.dart';
import 'package:cyber_visualiser/models/abuse_report_model.dart';
import 'package:cyber_visualiser/repositories/track_ip_repository.dart';
import 'package:cyber_visualiser/services/track_ip_lg_service.dart';
import 'package:cyber_visualiser/services/lg_service.dart';
import 'package:cyber_visualiser/services/gemini_service.dart';
import 'package:cyber_visualiser/services/text_to_speech_service.dart';
import 'package:cyber_visualiser/services/abuseipdb_service.dart';

class DummyTrackIpRepository extends TrackIpRepository {
  final AbuseIpReport reportToReturn;
  DummyTrackIpRepository(this.reportToReturn) : super(AbuseIpDbService());

  @override
  Future<AbuseIpReport> getIpReport(String ipAddress, int maxAgeInDays) async {
    return reportToReturn;
  }
}

class DummyGeminiService extends GeminiService {
  final String responseToReturn;
  DummyGeminiService(this.responseToReturn);

  @override
  Future<String> generateThreatSummary(String prompt) async {
    return responseToReturn;
  }
}

class DummyTrackIpLgService extends TrackIpLgService {
  List<Map<String, dynamic>> flyHistory = [];
  
  DummyTrackIpLgService() : super(LgService());

  @override
  Future<void> flyToCoordinate({
    required double latitude,
    required double longitude,
    required double range,
    required double tilt,
    required double heading,
  }) async {
    flyHistory.add({
      'latitude': latitude,
      'longitude': longitude,
      'range': range,
      'tilt': tilt,
      'heading': heading,
    });
  }
}

class DummyTextToSpeechService extends ChangeNotifier implements TextToSpeechService {
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

void main() {
  late AbuseIpReport mockReport;

  setUp(() {
    mockReport = AbuseIpReport(
      ipAddress: '8.8.8.8',
      isPublic: true,
      ipVersion: 4,
      isWhitelisted: false,
      abuseConfidenceScore: 85,
      countryCode: 'US',
      countryName: 'United States',
      usageType: 'Data Center',
      isp: 'Google LLC',
      domain: 'google.com',
      totalReports: 120,
      numDistinctUsers: 50,
      reports: [
        AbuseReportItem(
          reportedAt: DateTime.now(),
          comment: 'DDoS traffic observed from this subnet.',
          categories: [4],
          reporterId: 1,
          reporterCountryCode: 'DE',
          reporterCountryName: 'Germany',
        ),
      ],
    );
  });

  group('IP Tracker 3D Tour Tests', () {
    test('Should build fallback script correctly if Gemini API fails or returns malformed response', () async {
      final repository = DummyTrackIpRepository(mockReport);
      final provider = TrackIpProvider(repository);
      final gemini = DummyGeminiService('INVALID_NON_JSON_RESPONSE');

      // Fetch IP details to load the report
      await provider.fetchIpDetails(ipAddress: '8.8.8.8', maxAgeInDays: 5);
      
      // Generate tour
      await provider.generateTour(gemini);
      
      expect(provider.tourSteps.length, 3); // Origin + 1 Reporter + Conclusion
      expect(provider.tourError, isNull);
      
      // origin step
      expect(provider.tourSteps[0]['title'], 'Threat Origin Overview');
      expect(provider.tourSteps[0]['narration'], contains('Starting threat intelligence profile'));
      
      // reporter step
      expect(provider.tourSteps[1]['title'], contains('Reporter: Germany'));
      
      // conclusion step
      expect(provider.tourSteps[2]['title'], 'Threat Analysis Conclusion');
    });

    test('Should parse correct steps from clean Gemini JSON response', () async {
      final repository = DummyTrackIpRepository(mockReport);
      final provider = TrackIpProvider(repository);
      
      const cleanJsonResponse = '''
{
  "overview": "This is a custom AI overview.",
  "regions": [
    {
      "countryCode": "DE",
      "narration": "This is Germany custom threat description."
    }
  ],
  "conclusion": "This is a custom AI conclusion."
}
''';
      final gemini = DummyGeminiService(cleanJsonResponse);

      await provider.fetchIpDetails(ipAddress: '8.8.8.8', maxAgeInDays: 5);
      await provider.generateTour(gemini);
      
      expect(provider.tourSteps.length, 3);
      expect(provider.tourSteps[0]['narration'], 'This is a custom AI overview.');
      expect(provider.tourSteps[1]['narration'], 'This is Germany custom threat description.');
      expect(provider.tourSteps[2]['narration'], 'This is a custom AI conclusion.');
    });

    test('Should execute play, pause, next, skip correctly updating speaker and camera', () async {
      final repository = DummyTrackIpRepository(mockReport);
      final provider = TrackIpProvider(repository);
      final tts = DummyTextToSpeechService();
      final trackLg = DummyTrackIpLgService();
      
      const response = '''
{
  "overview": "Overview script.",
  "regions": [
    {
      "countryCode": "DE",
      "narration": "Germany script."
    }
  ],
  "conclusion": "Conclusion script."
}
''';
      final gemini = DummyGeminiService(response);

      await provider.fetchIpDetails(ipAddress: '8.8.8.8', maxAgeInDays: 5);
      await provider.generateTour(gemini);

      // Start Tour
      provider.startTour(tts, trackLg);
      await Future.delayed(Duration.zero);
      expect(provider.isTourPlaying, isTrue);
      expect(provider.isTourPaused, isFalse);
      expect(provider.currentTourStepIndex, 0);
      expect(tts.lastSpokenText, 'Overview script.');
      expect(trackLg.flyHistory.length, 1);

      // Go to Next Step
      provider.nextStep(tts, trackLg);
      await Future.delayed(Duration.zero);
      expect(provider.currentTourStepIndex, 1);
      expect(tts.lastSpokenText, 'Germany script.');
      expect(trackLg.flyHistory.length, 2);

      // Pause Tour
      provider.pauseTour(tts);
      expect(provider.isTourPaused, isTrue);
      expect(tts.isSpeaking, isFalse);

      // Resume Tour
      provider.resumeTour(tts, trackLg);
      await Future.delayed(Duration.zero);
      expect(provider.isTourPaused, isFalse);
      expect(tts.lastSpokenText, 'Germany script.');

      // Previous Step
      provider.previousStep(tts, trackLg);
      await Future.delayed(Duration.zero);
      expect(provider.currentTourStepIndex, 0);
      expect(tts.lastSpokenText, 'Overview script.');

      // Stop Tour
      provider.stopTour(tts);
      expect(provider.isTourPlaying, isFalse);
      expect(tts.isSpeaking, isFalse);
    });
  });
}
