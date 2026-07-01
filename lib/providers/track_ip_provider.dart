import 'package:flutter/foundation.dart';
import '../models/abuse_report_model.dart';
import '../repositories/track_ip_repository.dart';
import '../services/track_ip_lg_service.dart';
import '../services/gemini_service.dart';
import '../templates/gemini_prompt_template.dart';

class TrackIpProvider extends ChangeNotifier {
  final TrackIpRepository _repository;

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
      debugPrint('HoneyVision TrackIP Provider Error: $e');
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
      debugPrint('HoneyVision Gemini Analysis Error: $e');
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
      debugPrint('HoneyVision TrackIP Provider LG Projection Error: $e');
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
      debugPrint('HoneyVision TrackIP Provider LG Clear Error: $e');
      return false;
    }
  }

  /// Resets the provider state and clears any LG visuals.
  void clearState({TrackIpLgService? lgService}) {
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
    notifyListeners();
  }
}
