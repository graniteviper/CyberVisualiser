import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/attack_event.dart';
import '../repositories/attack_repository.dart';
import '../services/lg_adapter.dart';
import '../services/lg_service.dart';
import '../services/gemini_service.dart';
import '../services/text_to_speech_service.dart';
import '../templates/gemini_prompt_template.dart';
import '../templates/historical_kml_generator.dart';
import '../utils/config.dart';
import '../utils/country_coordinates.dart';

class AttackProvider extends ChangeNotifier {
  final AttackRepository _repository;
  final List<AttackEvent> _events = [];

  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastFetchTime;
  Timer? _pollTimer;

  List<AttackEvent> get events => _events;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastFetchTime => _lastFetchTime;
  bool get isPollingActive => _pollTimer != null;

  // Live Statistics Getters
  int get totalEvents => _events.length;

  int get uniqueSourceIps {
    final ips = _events
        .map((e) => e.sourceIp)
        .where((ip) => ip.isNotEmpty)
        .toSet();
    return ips.length;
  }

  int get uniqueCountries {
    final countries = _events
        .map((e) => e.countryCode)
        .where((c) => c.isNotEmpty)
        .toSet();
    return countries.length;
  }

  int get uniqueAsns {
    final asns = _events.map((e) => e.asnNumber).where((a) => a > 0).toSet();
    return asns.length;
  }

  // 3D Tour State Variables
  bool _isTourScriptLoading = false;
  bool _isTourPlaying = false;
  bool _isTourPaused = false;
  int _currentTourStepIndex = 0;
  List<Map<String, dynamic>> _tourSteps = [];
  Timer? _tourOrbitTimer;
  double _currentHeading = 0.0;
  String? _tourError;
  String _generatedKml = "";
  String _statusMessage = "";
  bool _isVisualized = false;

  bool get isTourScriptLoading => _isTourScriptLoading;
  bool get isTourPlaying => _isTourPlaying;
  bool get isTourPaused => _isTourPaused;
  int get currentTourStepIndex => _currentTourStepIndex;
  List<Map<String, dynamic>> get tourSteps => _tourSteps;
  String? get tourError => _tourError;
  String get generatedKml => _generatedKml;
  String get statusMessage => _statusMessage;
  bool get isVisualized => _isVisualized;

  AttackProvider(this._repository) {
    // Polling threat events on manual refresh only
  }

  /// Starts polling threat events every 5 seconds (disabled for manual updates)
  void startPolling() {}

  /// Stops periodic polling
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    notifyListeners();
  }

  /// Fetches new threat events and appends them to the live feed
  Future<void> fetchRecentTelemetry({int minutes = 15}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      final since = now.subtract(Duration(minutes: minutes));

      final newEvents = await _repository.fetchNewEvents(
        since: since,
        until: now,
      );

      if (newEvents.isNotEmpty) {
        _events.insertAll(0, newEvents);

        if (_events.length > 100) {
          _events.removeRange(100, _events.length);
        }
      }

      _lastFetchTime = DateTime.now();
      _errorMessage = null;
    } catch (e) {
      debugPrint('cyber visualiser Provider Error: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Triggers Liquid Galaxy visualization via the adapter
  Future<bool> triggerVisualization(
    LgAdapter adapter,
    AttackEvent event,
  ) async {
    return await adapter.visualizeOnLG(event);
  }

  String _buildLookAt(
    double lat,
    double lon,
    double range,
    double tilt,
    double bearing,
  ) {
    return '''<LookAt>
      <longitude>$lon</longitude>
      <latitude>$lat</latitude>
      <altitude>0</altitude>
      <heading>$bearing</heading>
      <tilt>$tilt</tilt>
      <range>$range</range>
      <gx:altitudeMode>relativeToGround</gx:altitudeMode>
    </LookAt>''';
  }

  /// Generates a 3D tour script and KML projection for a single live attack
  Future<void> generateSingleAttackTour({
    required AttackEvent event,
    required GeminiService geminiService,
    required LgService lgService,
    required LgAdapter adapter,
  }) async {
    _isTourScriptLoading = true;
    _isTourPlaying = false;
    _isTourPaused = false;
    _currentTourStepIndex = 0;
    _tourSteps = [];
    _tourError = null;
    _isVisualized = false;
    _statusMessage = "Analyzing attack vectors and generating tour...";
    notifyListeners();

    try {
      final sourceCoord = CountryCoordinatesLookup.getCoordinate(
        event.countryCode,
      );
      final prompt = GeminiPromptTemplate.fillLiveAttackTourPrompt(
        event: event,
        sourceLat: sourceCoord.latitude,
        sourceLon: sourceCoord.longitude,
        targetLat: adapter.targetLat,
        targetLon: adapter.targetLon,
        targetCountry: adapter.targetCountry,
      );

      _statusMessage = "Calling Google Gemini AI Threat Intelligence...";
      notifyListeners();

      final response = await geminiService.generateThreatSummary(prompt);
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception("Invalid JSON response format from Gemini model.");
      }

      final jsonString = response.substring(jsonStart, jsonEnd + 1);
      final data = json.decode(jsonString);

      _statusMessage = "Constructing 3D vector KML map...";
      notifyListeners();

      final kmlContent = HistoricalKmlGenerator.generateSingleAttackKml(data);
      _generatedKml = kmlContent;

      _statusMessage = "Uploading map projection to Liquid Galaxy...";
      notifyListeners();

      final uploadedName = await lgService.uploadKml(
        kmlContent,
        'live_attack_tour.kml',
      );
      if (uploadedName == null) {
        throw Exception('Failed to upload the live attack KML file.');
      }

      await lgService.query('slave_1=http://lg1:81/$uploadedName');

      final tourData = data['tour'];
      final stepsData = tourData['steps'] as List<dynamic>;
      _tourSteps = stepsData.map((s) => Map<String, dynamic>.from(s)).toList();

      final attackerData = data['attacker'];
      final lat = (attackerData['latitude'] as num).toDouble();
      final lon = (attackerData['longitude'] as num).toDouble();

      await lgService.flyTo(_buildLookAt(lat, lon, 2000000.0, 45.0, 0.0));

      _isVisualized = true;
      _isTourScriptLoading = false;
      _statusMessage = "Projection complete! Ready to start 3D tour.";
      notifyListeners();
    } catch (e) {
      debugPrint("Live Tour Generation Error: $e");
      _tourError = e.toString();
      _isTourScriptLoading = false;
      _statusMessage = "Error: ${_tourError.toString()}";
      notifyListeners();
    }
  }

  /// Generates a 3D tour script and KML projection for a live category (top 10 attacks)
  Future<void> generateCategoryTour({
    required String categoryName,
    required List<AttackEvent> events,
    required GeminiService geminiService,
    required LgService lgService,
    required LgAdapter adapter,
  }) async {
    _isTourScriptLoading = true;
    _isTourPlaying = false;
    _isTourPaused = false;
    _currentTourStepIndex = 0;
    _tourSteps = [];
    _tourError = null;
    _isVisualized = false;
    _statusMessage = "Plotting multi-vector tour for category...";
    notifyListeners();

    try {
      final prompt = GeminiPromptTemplate.fillLiveCategoryTourPrompt(
        categoryName: categoryName,
        events: events,
        targetLat: adapter.targetLat,
        targetLon: adapter.targetLon,
        targetCountry: adapter.targetCountry,
      );

      _statusMessage = "Querying Gemini AI Threat Intelligence...";
      notifyListeners();

      final response = await geminiService.generateThreatSummary(prompt);
      final jsonStart = response.indexOf('{');
      final jsonEnd = response.lastIndexOf('}');
      if (jsonStart == -1 || jsonEnd == -1) {
        throw Exception("Invalid JSON response format from Gemini model.");
      }

      final jsonString = response.substring(jsonStart, jsonEnd + 1);
      final data = json.decode(jsonString);

      _statusMessage = "Creating combined attack vectors map...";
      notifyListeners();

      final kmlContent = HistoricalKmlGenerator.generateCategoryAttackKml(data);
      _generatedKml = kmlContent;

      _statusMessage = "Uploading maps to Liquid Galaxy rig...";
      notifyListeners();

      final uploadedName = await lgService.uploadKml(
        kmlContent,
        'live_category_tour.kml',
      );
      if (uploadedName == null) {
        throw Exception('Failed to upload the category KML file.');
      }

      await lgService.query('slave_1=http://lg1:81/$uploadedName');

      final tourData = data['tour'];
      final stepsData = tourData['steps'] as List<dynamic>;
      _tourSteps = stepsData.map((s) => Map<String, dynamic>.from(s)).toList();

      await lgService.flyTo(_buildLookAt(0.0, 0.0, 8000000.0, 0.0, 0.0));

      _isVisualized = true;
      _isTourScriptLoading = false;
      _statusMessage = "Category projection uploaded! Ready to begin tour.";
      notifyListeners();
    } catch (e) {
      debugPrint("Category Tour Generation Error: $e");
      _tourError = e.toString();
      _isTourScriptLoading = false;
      _statusMessage = "Error: ${_tourError.toString()}";
      notifyListeners();
    }
  }

  /// Starts the 3D tour narration playback
  Future<void> startTour(
    TextToSpeechService ttsService,
    LgService lgService,
  ) async {
    if (_tourSteps.isEmpty) return;
    _isTourPlaying = true;
    _isTourPaused = false;
    _currentTourStepIndex = 0;
    notifyListeners();
    await _playCurrentStep(ttsService, lgService);
  }

  /// Pauses the 3D tour narration playback
  Future<void> pauseTour(TextToSpeechService ttsService) async {
    _isTourPaused = true;
    _stopOrbitTimer();
    await ttsService.stop();
    notifyListeners();
  }

  /// Resumes the paused 3D tour narration playback
  Future<void> resumeTour(
    TextToSpeechService ttsService,
    LgService lgService,
  ) async {
    _isTourPaused = false;
    notifyListeners();
    await _playCurrentStep(ttsService, lgService);
  }

  /// Stops and terminates the 3D tour narration
  Future<void> stopTour(
    TextToSpeechService ttsService,
    LgService lgService,
  ) async {
    _isTourPlaying = false;
    _isTourPaused = false;
    _currentTourStepIndex = 0;
    _stopOrbitTimer();
    await ttsService.stop();
    scheduleMicrotask(() {
      notifyListeners();
    });
  }

  /// Advances to the next tour step
  Future<void> nextStep(
    TextToSpeechService ttsService,
    LgService lgService,
  ) async {
    if (_currentTourStepIndex < _tourSteps.length - 1) {
      _currentTourStepIndex++;
      notifyListeners();
      await _playCurrentStep(ttsService, lgService);
    } else {
      await stopTour(ttsService, lgService);
    }
  }

  /// Goes back to the previous tour step
  Future<void> previousStep(
    TextToSpeechService ttsService,
    LgService lgService,
  ) async {
    if (_currentTourStepIndex > 0) {
      _currentTourStepIndex--;
      notifyListeners();
      await _playCurrentStep(ttsService, lgService);
    }
  }

  /// Executes the camera movement and speaks the narration for the active step
  Future<void> _playCurrentStep(
    TextToSpeechService ttsService,
    LgService lgService,
  ) async {
    _stopOrbitTimer();
    if (_currentTourStepIndex >= _tourSteps.length) return;

    final step = _tourSteps[_currentTourStepIndex];
    final lat = (step['latitude'] as num).toDouble();
    final lon = (step['longitude'] as num).toDouble();
    final range = (step['range'] as num).toDouble();
    final tilt = (step['tilt'] as num).toDouble();
    final narration = step['narration'] as String;

    await ttsService.stop();

    // Trigger Rig movement
    await lgService.flyTo(_buildLookAt(lat, lon, range, tilt, 0.0));

    // Speak audio text
    await ttsService.speak(
      narration,
      utteranceId: 'live_tour_step_$_currentTourStepIndex',
    );

    // Start orbiting camera once arrived
    _startOrbitTimer(lgService, lat, lon, range, tilt);
  }

  void _startOrbitTimer(
    LgService lgService,
    double lat,
    double lon,
    double range,
    double tilt,
  ) {
    _stopOrbitTimer();
    _currentHeading = 0.0;

    _tourOrbitTimer = Timer.periodic(const Duration(milliseconds: 2000), (
      timer,
    ) {
      if (!_isTourPlaying || _isTourPaused) {
        timer.cancel();
        return;
      }
      _currentHeading = (_currentHeading + 30.0) % 360.0;
      lgService
          .flyTo(_buildLookAt(lat, lon, range, tilt, _currentHeading))
          .catchError((e) {
            debugPrint("Orbit flyTo error: $e");
          });
    });
  }

  void _stopOrbitTimer() {
    _tourOrbitTimer?.cancel();
    _tourOrbitTimer = null;
  }

  /// Clears tour states and parameters
  void clearTourState() {
    _isTourScriptLoading = false;
    _isTourPlaying = false;
    _isTourPaused = false;
    _currentTourStepIndex = 0;
    _tourSteps = [];
    _tourError = null;
    _generatedKml = "";
    _statusMessage = "";
    _isVisualized = false;
    _stopOrbitTimer();
    scheduleMicrotask(() {
      notifyListeners();
    });
  }

  /// List of distinct attack categories supported by the application
  static const List<String> categories = [
    'DDOS attacks',
    'SSH attacks',
    'malware',
    'brute force',
    'other',
  ];

  /// Groups currently fetched events by their categorized type
  Map<String, List<AttackEvent>> getGroupedEvents() {
    final Map<String, List<AttackEvent>> groups = {
      'DDOS attacks': [],
      'SSH attacks': [],
      'malware': [],
      'brute force': [],
      'other': [],
    };
    for (final event in _events) {
      final category = event.attackCategory;
      if (groups.containsKey(category)) {
        groups[category]!.add(event);
      } else {
        groups['other']!.add(event);
      }
    }
    return groups;
  }

  @override
  void dispose() {
    stopPolling();
    _stopOrbitTimer();
    super.dispose();
  }
}
