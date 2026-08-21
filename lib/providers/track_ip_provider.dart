import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import '../models/abuse_report_model.dart';
import '../repositories/track_ip_repository.dart';
import '../services/track_ip_lg_service.dart';
import '../services/gemini_service.dart';
import '../templates/gemini_prompt_template.dart';
import '../utils/country_coordinates.dart';
import '../services/text_to_speech_service.dart';

class TrackIpProvider extends ChangeNotifier {
  final TrackIpRepository _repository;

  // Tour State Variables
  bool _isTourScriptLoading = false;
  bool _isTourPlaying = false;
  bool _isTourPaused = false;
  int _currentTourStepIndex = 0;
  List<Map<String, dynamic>> _tourSteps = [];
  Timer? _tourOrbitTimer;
  double _currentHeading = 0.0;
  String? _tourError;

  bool get isTourScriptLoading => _isTourScriptLoading;
  bool get isTourPlaying => _isTourPlaying;
  bool get isTourPaused => _isTourPaused;
  int get currentTourStepIndex => _currentTourStepIndex;
  List<Map<String, dynamic>> get tourSteps => _tourSteps;
  String? get tourError => _tourError;

  bool _isLoading = false;
  String? _errorMessage;
  AbuseIpReport? _report;
  bool _isVisualized = false;

  bool _isAnalyzing = false;
  String? _geminiSummary;
  String? _geminiError;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  AbuseIpReport? get report => _report;
  bool get isVisualized => _isVisualized;

  bool get isAnalyzing => _isAnalyzing;
  String? get geminiSummary => _geminiSummary;
  String? get geminiError => _geminiError;

  TrackIpProvider(this._repository);

  /// Fetch AbuseIPDB intelligence reports for a specific IP.
  Future<void> fetchIpDetails({
    required String ipAddress,
    required int maxAgeInDays,
    TrackIpLgService? lgService,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    _report = null;
    _isVisualized = false;
    _geminiSummary = null;
    _geminiError = null;
    notifyListeners();

    try {
      final data = await _repository.getIpReport(ipAddress, maxAgeInDays);
      _report = data;
      _errorMessage = null;

      // Automatically project on LG if connection is active and service is provided
      if (lgService != null) {
        await projectOnLG(lgService);
      }
    } catch (e) {
      debugPrint('cyber visualiser TrackIP Provider Error: $e');
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Performs Gemini Threat Analysis on the current report
  Future<void> analyzeWithGemini(GeminiService geminiService) async {
    if (_report == null) {
      _geminiError = 'No active threat report available to analyze.';
      notifyListeners();
      return;
    }

    _isAnalyzing = true;
    _geminiError = null;
    _geminiSummary = null;
    notifyListeners();

    try {
      final prompt = GeminiPromptTemplate.fillAttackAnalysisTemplate(_report!);
      final summary = await geminiService.generateThreatSummary(prompt);
      _geminiSummary = summary;
      _geminiError = null;
    } catch (e) {
      debugPrint('cyber visualiser Gemini Analysis Error: $e');
      _geminiError = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isAnalyzing = false;
      notifyListeners();
    }
  }

  /// Does BOTH tracking and Gemini analysis in one single operation
  Future<void> trackAndAnalyze({
    required String ipAddress,
    required int maxAgeInDays,
    required GeminiService geminiService,
    TrackIpLgService? lgService,
  }) async {
    await fetchIpDetails(
      ipAddress: ipAddress,
      maxAgeInDays: maxAgeInDays,
      lgService: lgService,
    );

    if (_errorMessage == null && _report != null) {
      await analyzeWithGemini(geminiService);
    } else {
      _geminiError = 'Could not fetch IP details to perform analysis.';
      notifyListeners();
    }
  }

  /// Sends the KML vectors and the SVG overlay to Liquid Galaxy screens.
  Future<bool> projectOnLG(TrackIpLgService lgService) async {
    if (_report == null) return false;

    try {
      // 1. Send the KML file (placing markers and curves)
      final kmlSuccess = await lgService.sendTrackIpKML(_report!);
      if (!kmlSuccess) return false;

      // 2. Send the rightmost screen overlay (SVG card summary)
      final overlaySuccess = await lgService.sendTrackIpOverlay(_report!);
      if (!overlaySuccess) return false;

      _isVisualized = true;
      notifyListeners();
      return true;
    } catch (e) {
      debugPrint('cyber visualiser TrackIP Provider LG Projection Error: $e');
      return false;
    }
  }

  /// Clears KML and SVG overlay on Liquid Galaxy.
  Future<bool> clearLGVisuals(TrackIpLgService lgService) async {
    try {
      final success = await lgService.clearTrackIpVisuals();
      if (success) {
        _isVisualized = false;
        notifyListeners();
      }
      return success;
    } catch (e) {
      debugPrint('cyber visualiser TrackIP Provider LG Clear Error: $e');
      return false;
    }
  }

  /// Resets the provider state and clears any LG visuals.
  void clearState({
    TrackIpLgService? lgService,
    TextToSpeechService? ttsService,
  }) {
    if (ttsService != null) {
      stopTour(ttsService);
    }
    if (lgService != null && _isVisualized) {
      clearLGVisuals(lgService);
    }
    _report = null;
    _errorMessage = null;
    _isLoading = false;
    _isVisualized = false;
    _isAnalyzing = false;
    _geminiSummary = null;
    _geminiError = null;
    _tourSteps = [];
    _currentTourStepIndex = 0;
    _tourError = null;
    notifyListeners();
  }

  /// Generates the 3D Tour script utilizing Gemini
  Future<void> generateTour(GeminiService geminiService) async {
    if (_report == null) {
      _tourError = 'No active threat report available to generate a tour.';
      notifyListeners();
      return;
    }

    _isTourScriptLoading = true;
    _tourError = null;
    _tourSteps = [];
    _currentTourStepIndex = 0;
    _isTourPlaying = false;
    _isTourPaused = false;
    notifyListeners();

    try {
      final prompt = GeminiPromptTemplate.fillTourScriptPrompt(_report!);
      final responseText = await geminiService.generateThreatSummary(prompt);

      // Attempt to clean JSON formatting from response text if present
      String cleanJson = responseText.trim();
      if (cleanJson.startsWith('```')) {
        // Strip out ```json ... ``` blocks
        final lines = cleanJson.split('\n');
        if (lines.first.startsWith('```')) {
          lines.removeAt(0);
        }
        if (lines.isNotEmpty && lines.last.startsWith('```')) {
          lines.removeLast();
        }
        cleanJson = lines.join('\n').trim();
      }

      Map<String, dynamic> scriptData;
      try {
        scriptData = json.decode(cleanJson) as Map<String, dynamic>;
      } catch (e) {
        debugPrint(
          'cyber visualiser Tour JSON Parse Error: $e. Falling back to template-based narration.',
        );
        scriptData = _generateFallbackScript(_report!);
      }

      // Build step objects
      _tourSteps = _buildTourStepsFromScript(scriptData, _report!);
      _tourError = null;
    } catch (e) {
      debugPrint('cyber visualiser Tour Generation Error: $e');
      _tourError = e.toString().replaceAll('Exception: ', '');
      // Fallback
      if (_report != null) {
        final fallbackScript = _generateFallbackScript(_report!);
        _tourSteps = _buildTourStepsFromScript(fallbackScript, _report!);
        _tourError = null; // Clear error if fallback succeeds
      }
    } finally {
      _isTourScriptLoading = false;
      notifyListeners();
    }
  }

  /// Helper to build structured steps matching coordinates & narration scripts
  List<Map<String, dynamic>> _buildTourStepsFromScript(
    Map<String, dynamic> script,
    AbuseIpReport report,
  ) {
    final List<Map<String, dynamic>> steps = [];

    // Step 1: Overview
    final sCoord = CountryCoordinatesLookup.getCoordinate(report.countryCode);
    steps.add({
      'title': 'Threat Origin Overview',
      'latitude': sCoord.latitude,
      'longitude': sCoord.longitude,
      'range': 5000000.0,
      'tilt': 30.0,
      'narration': script['overview'] ?? 'This is the threat origin overview.',
    });

    // Step 2: Reporter Locations
    final regionsScriptList = script['regions'] as List? ?? [];
    final Map<String, String> regionNarrations = {};
    for (var reg in regionsScriptList) {
      if (reg is Map && reg['countryCode'] != null) {
        regionNarrations[reg['countryCode'].toString().toUpperCase()] =
            reg['narration']?.toString() ?? '';
      }
    }

    // Group reports by country code to prevent overlapping
    final Map<String, List<AbuseReportItem>> reportsByCountry = {};
    for (final r in report.reports) {
      if (r.reporterCountryCode.isNotEmpty) {
        reportsByCountry.putIfAbsent(r.reporterCountryCode, () => []).add(r);
      }
    }

    reportsByCountry.forEach((countryCode, list) {
      final rCoord = CountryCoordinatesLookup.getCoordinate(countryCode);
      if (rCoord.latitude == 0.0 && rCoord.longitude == 0.0) return;

      final countryName = list.first.reporterCountryName.isNotEmpty
          ? list.first.reporterCountryName
          : countryCode;

      final narration =
          regionNarrations[countryCode.toUpperCase()] ??
          'This location reported ${list.length} threat incident(s) from $countryName against the source IP.';

      steps.add({
        'title': 'Reporter: $countryName (${list.length} reports)',
        'latitude': rCoord.latitude,
        'longitude': rCoord.longitude,
        'range': 1500000.0,
        'tilt': 45.0,
        'narration': narration,
      });
    });

    // Step 3: Conclusion
    steps.add({
      'title': 'Threat Analysis Conclusion',
      'latitude': sCoord.latitude,
      'longitude': sCoord.longitude,
      'range': 4000000.0,
      'tilt': 35.0,
      'narration':
          script['conclusion'] ??
          'This concludes the threat intelligence profile for IP ${report.ipAddress}.',
    });

    return steps;
  }

  /// Template fallback script generator
  Map<String, dynamic> _generateFallbackScript(AbuseIpReport report) {
    // Basic templates
    final String overview =
        'Starting threat intelligence profile for IP address ${report.ipAddress}. '
        'This network resource is managed by the Internet Service Provider ${report.isp} in ${report.countryName}. '
        'It has triggered an abuse confidence score of ${report.abuseConfidenceScore} percent out of a total of ${report.totalReports} reports.';

    final List<Map<String, dynamic>> regions = [];
    final Map<String, List<AbuseReportItem>> reportsByCountry = {};
    for (final r in report.reports) {
      if (r.reporterCountryCode.isNotEmpty) {
        reportsByCountry.putIfAbsent(r.reporterCountryCode, () => []).add(r);
      }
    }

    reportsByCountry.forEach((countryCode, list) {
      final countryName = list.first.reporterCountryName.isNotEmpty
          ? list.first.reporterCountryName
          : countryCode;
      regions.add({
        'countryCode': countryCode,
        'narration':
            'Analyzing traffic vector from ${report.ipAddress} targeting $countryName. '
            'We have registered ${list.length} distinct reports in this region. '
            'Reporters cited categories such as ${list.first.categoryNames.join(", ")}.',
      });
    });

    final String conclusion =
        'This concludes the visualization. The security Operations Center recommends '
        'applying access controls for target networks and blacklisting the suspect IP address ${report.ipAddress} to prevent further compromises.';

    return {'overview': overview, 'regions': regions, 'conclusion': conclusion};
  }

  /// Starts the 3D tour from the beginning
  void startTour(TextToSpeechService ttsService, TrackIpLgService lgService) {
    if (_tourSteps.isEmpty) return;
    _isTourPlaying = true;
    _isTourPaused = false;
    _currentTourStepIndex = 0;

    // Register completion handler
    ttsService.onCompletion = () {
      if (_isTourPlaying && !_isTourPaused) {
        // Automatically proceed to the next step after a 2-second pause (gives user time to view the orbit)
        Timer(const Duration(seconds: 2), () {
          if (_isTourPlaying && !_isTourPaused) {
            nextStep(ttsService, lgService);
          }
        });
      }
    };

    notifyListeners();
    _playCurrentStep(ttsService, lgService);
  }

  /// Pauses the current step (stops orbit timer and halts speech)
  void pauseTour(TextToSpeechService ttsService) {
    if (!_isTourPlaying || _isTourPaused) return;
    _isTourPaused = true;
    _stopOrbitTimer();
    ttsService.onCompletion = null; // Prevent stop() from triggering next step
    ttsService.stop();
    notifyListeners();
  }

  /// Resumes the current step from where it was
  void resumeTour(TextToSpeechService ttsService, TrackIpLgService lgService) {
    if (!_isTourPlaying || !_isTourPaused) return;
    _isTourPaused = false;

    // Re-register callback
    ttsService.onCompletion = () {
      if (_isTourPlaying && !_isTourPaused) {
        Timer(const Duration(seconds: 2), () {
          if (_isTourPlaying && !_isTourPaused) {
            nextStep(ttsService, lgService);
          }
        });
      }
    };

    notifyListeners();

    // Replay narration for the current step
    _playCurrentStep(ttsService, lgService);
  }

  /// Stops the tour entirely, resetting states and timers
  void stopTour(TextToSpeechService ttsService) {
    _isTourPlaying = false;
    _isTourPaused = false;
    _stopOrbitTimer();
    ttsService.onCompletion = null; // Prevent stop() from triggering next step
    ttsService.stop();
    notifyListeners();
  }

  /// Proceeds to the next step
  void nextStep(TextToSpeechService ttsService, TrackIpLgService lgService) {
    if (!_isTourPlaying) return;
    _stopOrbitTimer();
    ttsService.onCompletion = null; // Temporarily disable callback
    ttsService.stop();

    // Re-register callback for the new step
    ttsService.onCompletion = () {
      if (_isTourPlaying && !_isTourPaused) {
        Timer(const Duration(seconds: 2), () {
          if (_isTourPlaying && !_isTourPaused) {
            nextStep(ttsService, lgService);
          }
        });
      }
    };

    if (_currentTourStepIndex < _tourSteps.length - 1) {
      _currentTourStepIndex++;
      _isTourPaused = false;
      notifyListeners();
      _playCurrentStep(ttsService, lgService);
    } else {
      // Tour complete
      stopTour(ttsService);
    }
  }

  /// Goes back to the previous step
  void previousStep(
    TextToSpeechService ttsService,
    TrackIpLgService lgService,
  ) {
    if (!_isTourPlaying) return;
    _stopOrbitTimer();
    ttsService.onCompletion = null; // Temporarily disable callback
    ttsService.stop();

    // Re-register callback for the new step
    ttsService.onCompletion = () {
      if (_isTourPlaying && !_isTourPaused) {
        Timer(const Duration(seconds: 2), () {
          if (_isTourPlaying && !_isTourPaused) {
            nextStep(ttsService, lgService);
          }
        });
      }
    };

    if (_currentTourStepIndex > 0) {
      _currentTourStepIndex--;
      _isTourPaused = false;
      notifyListeners();
      _playCurrentStep(ttsService, lgService);
    }
  }

  /// Internal playback loop for the current active step
  void _playCurrentStep(
    TextToSpeechService ttsService,
    TrackIpLgService lgService,
  ) async {
    if (_currentTourStepIndex < 0 ||
        _currentTourStepIndex >= _tourSteps.length) {
      return;
    }

    final step = _tourSteps[_currentTourStepIndex];
    final double lat = step['latitude'];
    final double lon = step['longitude'];
    final double range = step['range'];
    final double tilt = step['tilt'];
    final String narration = step['narration'];

    _currentHeading = 0.0;

    // 1. Zoom and fly camera to target location
    await lgService.flyToCoordinate(
      latitude: lat,
      longitude: lon,
      range: range,
      tilt: tilt,
      heading: _currentHeading,
    );

    // 2. Start dynamic camera updates (orbiting)
    _startOrbitTimer(lgService, lat, lon, range, tilt);

    // 3. Play voice description
    await ttsService.speak(
      narration,
      utteranceId: 'step_$_currentTourStepIndex',
    );
  }

  void _startOrbitTimer(
    TrackIpLgService lgService,
    double lat,
    double lon,
    double range,
    double tilt,
  ) {
    _stopOrbitTimer();
    _tourOrbitTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_isTourPaused || !_isTourPlaying) {
        timer.cancel();
        return;
      }
      _currentHeading = (_currentHeading + 15) % 360;
      await lgService.flyToCoordinate(
        latitude: lat,
        longitude: lon,
        range: range,
        tilt: tilt,
        heading: _currentHeading,
      );
    });
  }

  void _stopOrbitTimer() {
    _tourOrbitTimer?.cancel();
    _tourOrbitTimer = null;
  }

  @override
  void dispose() {
    _stopOrbitTimer();
    super.dispose();
  }
}
