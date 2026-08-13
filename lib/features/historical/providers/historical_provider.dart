import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../services/gemini_service.dart';
import '../../../services/lg_service.dart';
import '../../../services/text_to_speech_service.dart';
import '../../../templates/gemini_prompt_template.dart';
import '../../../templates/historical_kml_generator.dart';
import '../models/historical_attack.dart';
import '../repository/historical_repository.dart';

/// Provider for managing state and business logic of the Historical Attacks feature.
class HistoricalProvider extends ChangeNotifier {
  final HistoricalRepository _repository;

  bool _loading = false;
  List<HistoricalAttack> _allAttacks = [];
  List<HistoricalAttack> _filteredAttacks = [];

  String? _selectedCountry;
  String? _selectedCategory;
  String? _selectedSector;
  int? _selectedYear;
  String _searchQuery = "";

  // Tour State Variables
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

  HistoricalProvider(this._repository);

  // Getters for states
  bool get loading => _loading;
  List<HistoricalAttack> get allAttacks => _allAttacks;
  List<HistoricalAttack> get filteredAttacks => _filteredAttacks;
  String? get selectedCountry => _selectedCountry;
  String? get selectedCategory => _selectedCategory;
  String? get selectedSector => _selectedSector;
  int? get selectedYear => _selectedYear;
  String get searchQuery => _searchQuery;

  // Tour State Getters
  bool get isTourScriptLoading => _isTourScriptLoading;
  bool get isTourPlaying => _isTourPlaying;
  bool get isTourPaused => _isTourPaused;
  int get currentTourStepIndex => _currentTourStepIndex;
  List<Map<String, dynamic>> get tourSteps => _tourSteps;
  String? get tourError => _tourError;
  String get generatedKml => _generatedKml;
  String get statusMessage => _statusMessage;
  bool get isVisualized => _isVisualized;

  // Computed getters derived dynamically from all attacks
  List<String> get countries {
    final uniqueCountries = _allAttacks
        .map((a) => a.victim.country)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    uniqueCountries.sort();
    return uniqueCountries;
  }

  List<String> get categories {
    final uniqueCategories = _allAttacks
        .map((a) => a.attack.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    uniqueCategories.sort();
    return uniqueCategories;
  }

  List<String> get sectors {
    final uniqueSectors = _allAttacks
        .map((a) => a.attack.targetSector)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    uniqueSectors.sort();
    return uniqueSectors;
  }

  List<int> get years {
    final uniqueYears = _allAttacks.map((a) => a.year).toSet().toList();
    uniqueYears.sort(
      (a, b) => b.compareTo(a),
    ); // Descending order (newest years first)
    return uniqueYears;
  }

  /// Loads historical cyber attacks from the repository.
  Future<void> loadHistoricalAttacks() async {
    _loading = true;
    notifyListeners();

    try {
      _allAttacks = await _repository.getHistoricalAttacks();
      _applyFilters();
    } catch (e) {
      debugPrint("Error in HistoricalProvider.loadHistoricalAttacks: $e");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Filters the incidents list using search query.
  void search(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  /// Filters the incidents list by victim country.
  void filterCountry(String? country) {
    _selectedCountry = country;
    _applyFilters();
  }

  /// Filters the incidents list by attack category.
  void filterCategory(String? category) {
    _selectedCategory = category;
    _applyFilters();
  }

  /// Filters the incidents list by target sector.
  void filterSector(String? sector) {
    _selectedSector = sector;
    _applyFilters();
  }

  /// Filters the incidents list by attack year.
  void filterYear(int? year) {
    _selectedYear = year;
    _applyFilters();
  }

  /// Resets all filters and search query.
  void clearFilters() {
    _selectedCountry = null;
    _selectedCategory = null;
    _selectedSector = null;
    _selectedYear = null;
    _searchQuery = "";
    _applyFilters();
  }

  /// Combines all active filters and search query, updating [filteredAttacks].
  void _applyFilters() {
    var attacks = _allAttacks;

    // Apply search query (case-insensitive) on: title, victim.name, attacker.name, summary, tags
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      attacks = attacks.where((attack) {
        final titleMatch = attack.title.toLowerCase().contains(query);
        final victimMatch = attack.victim.name.toLowerCase().contains(query);
        final attackerMatch = attack.attacker.name.toLowerCase().contains(
          query,
        );
        final summaryMatch = attack.summary.toLowerCase().contains(query);
        final tagsMatch = attack.tags.any(
          (tag) => tag.toLowerCase().contains(query),
        );
        return titleMatch ||
            victimMatch ||
            attackerMatch ||
            summaryMatch ||
            tagsMatch;
      }).toList();
    }

    // Apply country filter
    if (_selectedCountry != null) {
      attacks = attacks
          .where((a) => a.victim.country == _selectedCountry)
          .toList();
    }

    // Apply category filter
    if (_selectedCategory != null) {
      attacks = attacks
          .where((a) => a.attack.category == _selectedCategory)
          .toList();
    }

    // Apply target sector filter
    if (_selectedSector != null) {
      attacks = attacks
          .where((a) => a.attack.targetSector == _selectedSector)
          .toList();
    }

    // Apply year filter
    if (_selectedYear != null) {
      attacks = attacks.where((a) => a.year == _selectedYear).toList();
    }

    _filteredAttacks = attacks;
    notifyListeners();
  }

  // ---------------------------------- TOUR OPERATIONS ----------------------------------

  /// Clean JSON utility to remove markdown block formatting
  String _extractJson(String responseText) {
    String cleanJson = responseText.trim();
    if (cleanJson.startsWith('```')) {
      final lines = cleanJson.split('\n');
      if (lines.first.startsWith('```')) {
        lines.removeAt(0);
      }
      if (lines.isNotEmpty && lines.last.startsWith('```')) {
        lines.removeLast();
      }
      cleanJson = lines.join('\n').trim();
    }
    return cleanJson;
  }

  double _toDouble(dynamic val) {
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  /// Generates the KML and Tour steps for a single historical attack using Gemini.
  Future<void> generateSingleAttackTour(
    HistoricalAttack attack,
    GeminiService geminiService,
    LgService lgService,
  ) async {
    _isTourScriptLoading = true;
    _tourError = null;
    _tourSteps = [];
    _currentTourStepIndex = 0;
    _isTourPlaying = false;
    _isTourPaused = false;
    _generatedKml = "";
    _statusMessage = "Analyzing attack and requesting tour data from Gemini...";
    notifyListeners();

    try {
      final prompt = GeminiPromptTemplate.fillHistoricalAttackTourPrompt(
        attack,
      );
      final responseText = await geminiService.generateThreatSummary(prompt);

      _statusMessage = "Parsing simulation layout...";
      notifyListeners();

      final jsonBlock = _extractJson(responseText);
      final decoded = json.decode(jsonBlock) as Map<String, dynamic>;

      // Build steps from JSON
      final tourData = decoded['tour'] as Map<String, dynamic>? ?? {};
      final rawSteps = tourData['steps'] as List? ?? [];
      final List<Map<String, dynamic>> steps = [];

      // Add Overview step
      steps.add({
        'title': 'Overview',
        'latitude': _toDouble(
          decoded['victim']?['latitude'] ?? attack.victim.latitude,
        ),
        'longitude': _toDouble(
          decoded['victim']?['longitude'] ?? attack.victim.longitude,
        ),
        'range': 4500000.0,
        'tilt': 20.0,
        'narration':
            tourData['overview'] ??
            'Starting tour of this historical security incident.',
      });

      for (final step in rawSteps) {
        if (step is Map<String, dynamic>) {
          steps.add({
            'title': step['title'] ?? 'Tour Point',
            'latitude': _toDouble(step['latitude']),
            'longitude': _toDouble(step['longitude']),
            'range': _toDouble(step['range'] ?? 2000000.0),
            'tilt': _toDouble(step['tilt'] ?? 40.0),
            'narration': step['narration'] ?? '',
          });
        }
      }

      // Add Conclusion step
      steps.add({
        'title': 'Mitigations and Conclusion',
        'latitude': _toDouble(
          decoded['victim']?['latitude'] ?? attack.victim.latitude,
        ),
        'longitude': _toDouble(
          decoded['victim']?['longitude'] ?? attack.victim.longitude,
        ),
        'range': 4000000.0,
        'tilt': 30.0,
        'narration':
            tourData['conclusion'] ??
            'This concludes our incident analysis tour.',
      });

      _tourSteps = steps;

      _statusMessage = "Generating KML visual assets...";
      notifyListeners();

      _generatedKml = HistoricalKmlGenerator.generateSingleAttackKml(decoded);

      _statusMessage = "Uploading attack KML to Liquid Galaxy rig...";
      notifyListeners();

      final uploadedName = await lgService.uploadKml(
        _generatedKml,
        'historical_attack.kml',
      );
      if (uploadedName == null) {
        throw Exception(
          'Failed to upload the KML file to your Liquid Galaxy rig.',
        );
      }

      await lgService.query('slave_1=http://lg1:81/$uploadedName');

      // Fly camera to first viewpoint
      final double lat = _toDouble(steps.first['latitude']);
      final double lon = _toDouble(steps.first['longitude']);
      final double range = _toDouble(steps.first['range']);
      final double tilt = _toDouble(steps.first['tilt']);

      await lgService.flyTo('''<LookAt>
          <longitude>$lon</longitude>
          <latitude>$lat</latitude>
          <altitude>0</altitude>
          <heading>0</heading>
          <tilt>$tilt</tilt>
          <range>$range</range>
          <gx:altitudeMode>relativeToGround</gx:altitudeMode>
        </LookAt>''');

      _isVisualized = true;
      _statusMessage = "KML Projected successfully!";
      _tourError = null;
    } catch (e) {
      debugPrint("Error generating single attack tour: $e");
      _tourError = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isTourScriptLoading = false;
      notifyListeners();
    }
  }

  /// Generates the KML and Tour steps for a category of historical attacks (top 10).
  Future<void> generateCategoryTour(
    String categoryName,
    List<HistoricalAttack> attacks,
    GeminiService geminiService,
    LgService lgService,
  ) async {
    _isTourScriptLoading = true;
    _tourError = null;
    _tourSteps = [];
    _currentTourStepIndex = 0;
    _isTourPlaying = false;
    _isTourPaused = false;
    _generatedKml = "";
    _statusMessage =
        "Requesting category threat tour from Gemini (max 10 incidents)...";
    notifyListeners();

    try {
      final prompt = GeminiPromptTemplate.fillHistoricalCategoryTourPrompt(
        categoryName,
        attacks,
      );
      final responseText = await geminiService.generateThreatSummary(prompt);

      _statusMessage = "Parsing category tour structure...";
      notifyListeners();

      final jsonBlock = _extractJson(responseText);
      final decoded = json.decode(jsonBlock) as Map<String, dynamic>;

      // Build steps from JSON
      final tourData = decoded['tour'] as Map<String, dynamic>? ?? {};
      final rawSteps = tourData['steps'] as List? ?? [];
      final List<Map<String, dynamic>> steps = [];

      // Add Overview step
      steps.add({
        'title': 'Category Overview',
        'latitude': 0.0,
        'longitude': 0.0,
        'range': 8000000.0,
        'tilt': 0.0,
        'narration':
            tourData['overview'] ??
            'Starting overview tour for $categoryName category.',
      });

      for (final step in rawSteps) {
        if (step is Map<String, dynamic>) {
          steps.add({
            'title': step['title'] ?? 'Incident Node',
            'latitude': _toDouble(step['latitude']),
            'longitude': _toDouble(step['longitude']),
            'range': _toDouble(step['range'] ?? 2000000.0),
            'tilt': _toDouble(step['tilt'] ?? 40.0),
            'narration': step['narration'] ?? '',
          });
        }
      }

      // Add Conclusion step
      steps.add({
        'title': 'Category Mitigations',
        'latitude': 0.0,
        'longitude': 0.0,
        'range': 8000000.0,
        'tilt': 0.0,
        'narration':
            tourData['conclusion'] ??
            'This concludes our category incident tour.',
      });

      _tourSteps = steps;

      _statusMessage = "Synthesizing combined KML data...";
      notifyListeners();

      _generatedKml = HistoricalKmlGenerator.generateCategoryAttackKml(decoded);

      _statusMessage = "Uploading category KML to Liquid Galaxy rig...";
      notifyListeners();

      final uploadedName = await lgService.uploadKml(
        _generatedKml,
        'historical_category.kml',
      );
      if (uploadedName == null) {
        throw Exception('Failed to upload the category KML file.');
      }

      await lgService.query('slave_1=http://lg1:81/$uploadedName');

      // Fly camera to first step coordinates (global view)
      await lgService.flyTo('''<LookAt>
          <longitude>0.0</longitude>
          <latitude>0.0</latitude>
          <altitude>0</altitude>
          <heading>0</heading>
          <tilt>0</tilt>
          <range>8000000</range>
          <gx:altitudeMode>relativeToGround</gx:altitudeMode>
        </LookAt>''');

      _isVisualized = true;
      _statusMessage = "Category KML Projected successfully!";
      _tourError = null;
    } catch (e) {
      debugPrint("Error generating category tour: $e");
      _tourError = e.toString().replaceAll('Exception: ', '');
    } finally {
      _isTourScriptLoading = false;
      notifyListeners();
    }
  }

  /// Starts the 3D tour from the beginning
  void startTour(TextToSpeechService ttsService, LgService lgService) {
    if (_tourSteps.isEmpty) return;
    _isTourPlaying = true;
    _isTourPaused = false;
    _currentTourStepIndex = 0;

    // Register completion handler
    ttsService.onCompletion = () {
      if (_isTourPlaying && !_isTourPaused) {
        // Proceed automatically after a short delay
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

  /// Pauses the current step (stops speech and camera rotation)
  void pauseTour(TextToSpeechService ttsService) {
    if (!_isTourPlaying || _isTourPaused) return;
    _isTourPaused = true;
    _stopOrbitTimer();
    ttsService.onCompletion = null;
    ttsService.stop();
    notifyListeners();
  }

  /// Resumes the current step
  void resumeTour(TextToSpeechService ttsService, LgService lgService) {
    if (!_isTourPlaying || !_isTourPaused) return;
    _isTourPaused = false;

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
    _playCurrentStep(ttsService, lgService);
  }

  /// Stops the tour entirely and clears rig views if desired
  void stopTour(TextToSpeechService ttsService, LgService lgService) {
    _isTourPlaying = false;
    _isTourPaused = false;
    _stopOrbitTimer();
    ttsService.onCompletion = null;
    ttsService.stop();
    scheduleMicrotask(() {
      notifyListeners();
    });
  }

  /// Proceeds to the next step
  void nextStep(TextToSpeechService ttsService, LgService lgService) {
    if (!_isTourPlaying) return;
    _stopOrbitTimer();
    ttsService.onCompletion = null;
    ttsService.stop();

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
      stopTour(ttsService, lgService);
    }
  }

  /// Goes back to the previous step
  void previousStep(TextToSpeechService ttsService, LgService lgService) {
    if (!_isTourPlaying) return;
    _stopOrbitTimer();
    ttsService.onCompletion = null;
    ttsService.stop();

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

  /// Internal playback controller for the active step
  void _playCurrentStep(
    TextToSpeechService ttsService,
    LgService lgService,
  ) async {
    if (_currentTourStepIndex < 0 || _currentTourStepIndex >= _tourSteps.length)
      return;

    final step = _tourSteps[_currentTourStepIndex];
    final double lat = _toDouble(step['latitude']);
    final double lon = _toDouble(step['longitude']);
    final double range = _toDouble(step['range']);
    final double tilt = _toDouble(step['tilt']);
    final String narration = step['narration'] ?? '';

    _currentHeading = 0.0;

    // 1. Move camera to viewpoint
    await lgService.flyTo('''<LookAt>
        <longitude>$lon</longitude>
        <latitude>$lat</latitude>
        <altitude>0</altitude>
        <heading>$_currentHeading</heading>
        <tilt>$tilt</tilt>
        <range>$range</range>
        <gx:altitudeMode>relativeToGround</gx:altitudeMode>
      </LookAt>''');

    // 2. Start orbiting target
    _startOrbitTimer(lgService, lat, lon, range, tilt);

    // 3. Narrative Voice
    await ttsService.speak(
      narration,
      utteranceId: 'historical_step_$_currentTourStepIndex',
    );
  }

  void _startOrbitTimer(
    LgService lgService,
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
      await lgService.flyTo('''<LookAt>
          <longitude>$lon</longitude>
          <latitude>$lat</latitude>
          <altitude>0</altitude>
          <heading>$_currentHeading</heading>
          <tilt>$tilt</tilt>
          <range>$range</range>
          <gx:altitudeMode>relativeToGround</gx:altitudeMode>
        </LookAt>''');
    });
  }

  void _stopOrbitTimer() {
    _tourOrbitTimer?.cancel();
    _tourOrbitTimer = null;
  }

  /// Clears tour variables and stops speech / timers
  void clearTourState() {
    _stopOrbitTimer();
    _isTourScriptLoading = false;
    _isTourPlaying = false;
    _isTourPaused = false;
    _currentTourStepIndex = 0;
    _tourSteps = [];
    _tourError = null;
    _generatedKml = "";
    _statusMessage = "";
    _isVisualized = false;
    scheduleMicrotask(() {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _stopOrbitTimer();
    super.dispose();
  }
}
