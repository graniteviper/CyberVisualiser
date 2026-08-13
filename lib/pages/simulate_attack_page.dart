import 'dart:io';
import 'dart:convert';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../services/lg_service.dart';
import '../services/gemini_service.dart';
import '../services/text_to_speech_service.dart';
import '../templates/simulation_prompt_template.dart';
import '../templates/simulation_kml_generator.dart';
import '../templates/gemini_prompt_template.dart';

class SimulateAttackPage extends StatefulWidget {
  const SimulateAttackPage({super.key});

  @override
  State<SimulateAttackPage> createState() => _SimulateAttackPageState();
}

class _SimulateAttackPageState extends State<SimulateAttackPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _promptController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = '';
  String _generatedKml = '';
  String _errorMessage = '';
  bool _isVisualized = false;
  String _simulationSummary = '';
  TextToSpeechService? _ttsService;
  late final AnimationController _pulseController;

  // Tour state variables
  Map<String, dynamic>? _simulationData;
  bool _isTourScriptLoading = false;
  bool _isTourPlaying = false;
  bool _isTourPaused = false;
  int _currentTourStepIndex = 0;
  List<Map<String, dynamic>> _tourSteps = [];
  Timer? _tourOrbitTimer;
  double _currentHeading = 0.0;
  String? _tourError;
  bool _isDisposed = false;

  final List<String> _presets = [
    'show me a ddos attack from multiple locations to a server based in usa',
    'brute-force ssh attack from china and russia on a server in germany',
    'sql injection exploit from east europe targeting a database in brazil',
    'botnet spam wave from south america and africa directed at a server in japan',
  ];

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ttsService = Provider.of<TextToSpeechService>(context, listen: false);
  }

  @override
  void dispose() {
    _isDisposed = true;
    _promptController.dispose();
    _stopTour();
    _pulseController.dispose();
    super.dispose();
  }

  String _extractJson(String responseText) {
    // 1. Try finding JSON block enclosed in ```json ... ```
    final jsonRegex = RegExp(r'```json([\s\S]*?)```');
    var match = jsonRegex.firstMatch(responseText);
    if (match != null) {
      return match.group(1)!.trim();
    }

    // 2. Try finding generic code block ``` ... ```
    final genericRegex = RegExp(r'```([\s\S]*?)```');
    match = genericRegex.firstMatch(responseText);
    if (match != null) {
      final codeBlock = match.group(1)!.trim();
      if (codeBlock.startsWith('{') || codeBlock.contains('"target"')) {
        return codeBlock;
      }
    }

    // 3. Fallback: search for direct JSON structure
    if (responseText.contains('{') && responseText.contains('}')) {
      final start = responseText.indexOf('{');
      final end = responseText.lastIndexOf('}') + 1;
      return responseText.substring(start, end).trim();
    }

    return responseText.trim();
  }

  String? _extractLookAt(String kmlContent) {
    final lookAtRegex = RegExp(r'<LookAt>([\s\S]*?)</LookAt>');
    final match = lookAtRegex.firstMatch(kmlContent);
    if (match != null) {
      return match.group(0);
    }
    return null;
  }

  Future<void> _runSimulation() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();

    final promptText = _promptController.text.trim();
    final geminiService = context.read<GeminiService>();
    final lgService = context.read<LgService>();

    _ttsService?.stop();

    setState(() {
      _isLoading = true;
      _statusMessage =
          'Prompting Gemini AI model to generate KML simulation...';
      _errorMessage = '';
      _generatedKml = '';
      _simulationSummary = '';
    });

    try {
      // 1. Build prompt template
      final fullPrompt = SimulationPromptTemplate.buildSimulationPrompt(
        promptText,
      );

      // 2. Call Gemini Service
      final responseText = await geminiService.generateThreatSummary(
        fullPrompt,
      );

      setState(() {
        _statusMessage = 'Extracting and parsing threat intelligence...';
      });

      // 3. Extract JSON and generate KML
      final jsonBlock = _extractJson(responseText);
      final kml = SimulationKmlGenerator.generateKmlFromJson(jsonBlock);

      // Extract summary
      String summary = '';
      Map<String, dynamic>? decodedJson;
      try {
        decodedJson = json.decode(jsonBlock);
        summary = decodedJson?['summary'] ?? '';
      } catch (e) {
        debugPrint('Failed to extract summary from JSON: $e');
      }

      setState(() {
        _simulationData = decodedJson;
        _generatedKml = kml;
        _simulationSummary = summary;
        _statusMessage = 'Uploading KML simulation file to Liquid Galaxy...';
      });

      // 4. Upload KML
      final uploadedName = await lgService.uploadKml(
        kml,
        'simulated_attack.kml',
      );
      if (uploadedName == null) {
        throw Exception(
          'Failed to upload the simulated KML file to your Liquid Galaxy rig.',
        );
      }

      setState(() {
        _statusMessage =
            'Projecting KML vectors and flying camera to the target server...';
      });

      // 5. Project on master screen (slave_1)
      await lgService.query('slave_1=http://lg1:81/$uploadedName');

      // 6. Fly to camera view if LookAt exists
      final lookAt = _extractLookAt(kml);
      if (lookAt != null) {
        await lgService.flyTo(lookAt);
      }

      setState(() {
        _isLoading = false;
        _isVisualized = true;
        _statusMessage = 'Simulation projected successfully!';
      });

      if (_simulationSummary.isNotEmpty) {
        _ttsService?.speak(
          _simulationSummary,
          utteranceId: 'simulation_summary',
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Attack simulation projected successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = e.toString();
        _statusMessage = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Simulation error: ${e.toString()}'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  double _toDouble(dynamic val) {
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  Future<void> _flyToCoordinate({
    required double latitude,
    required double longitude,
    required double range,
    required double tilt,
    required double heading,
  }) async {
    final lgService = context.read<LgService>();
    final lookAt =
        '''<LookAt>
        <longitude>$longitude</longitude>
        <latitude>$latitude</latitude>
        <altitude>0</altitude>
        <heading>$heading</heading>
        <tilt>$tilt</tilt>
        <range>$range</range>
        <gx:altitudeMode>relativeToGround</gx:altitudeMode>
      </LookAt>''';
    await lgService.flyTo(lookAt);
  }

  void _startOrbitTimer(double lat, double lon, double range, double tilt) {
    _stopOrbitTimer();
    _tourOrbitTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_isTourPaused || !_isTourPlaying) {
        timer.cancel();
        return;
      }
      _currentHeading = (_currentHeading + 15) % 360;
      await _flyToCoordinate(
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

  void _playCurrentStep() async {
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

    await _flyToCoordinate(
      latitude: lat,
      longitude: lon,
      range: range,
      tilt: tilt,
      heading: _currentHeading,
    );

    _startOrbitTimer(lat, lon, range, tilt);

    if (_ttsService != null) {
      await _ttsService!.speak(
        narration,
        utteranceId: 'sim_step_$_currentTourStepIndex',
      );
    }
  }

  void _startTourPlayback() {
    if (_tourSteps.isEmpty) return;
    setState(() {
      _isTourPlaying = true;
      _isTourPaused = false;
      _currentTourStepIndex = 0;
    });

    if (_ttsService != null) {
      _ttsService!.onCompletion = () {
        if (_isTourPlaying && !_isTourPaused) {
          Timer(const Duration(seconds: 2), () {
            if (_isTourPlaying && !_isTourPaused) {
              _nextTourStep();
            }
          });
        }
      };
    }

    _playCurrentStep();
  }

  void _pauseTour() {
    if (!_isTourPlaying || _isTourPaused) return;
    setState(() {
      _isTourPaused = true;
    });
    _stopOrbitTimer();
    if (_ttsService != null) {
      _ttsService!.onCompletion = null;
      _ttsService!.stop();
    }
  }

  void _resumeTour() {
    if (!_isTourPlaying || !_isTourPaused) return;
    setState(() {
      _isTourPaused = false;
    });
    if (_ttsService != null) {
      _ttsService!.onCompletion = () {
        if (_isTourPlaying && !_isTourPaused) {
          Timer(const Duration(seconds: 2), () {
            if (_isTourPlaying && !_isTourPaused) {
              _nextTourStep();
            }
          });
        }
      };
    }
    _playCurrentStep();
  }

  void _stopTour() {
    _stopOrbitTimer();
    if (_ttsService != null) {
      _ttsService!.onCompletion = null;
      _ttsService!.stop();
    }
    if (mounted && !_isDisposed) {
      setState(() {
        _isTourPlaying = false;
        _isTourPaused = false;
      });
    } else {
      _isTourPlaying = false;
      _isTourPaused = false;
    }
  }

  void _nextTourStep() {
    if (!_isTourPlaying) return;
    _stopOrbitTimer();
    if (_ttsService != null) {
      _ttsService!.onCompletion = null;
      _ttsService!.stop();
    }

    if (_ttsService != null) {
      _ttsService!.onCompletion = () {
        if (_isTourPlaying && !_isTourPaused) {
          Timer(const Duration(seconds: 2), () {
            if (_isTourPlaying && !_isTourPaused) {
              _nextTourStep();
            }
          });
        }
      };
    }

    if (_currentTourStepIndex < _tourSteps.length - 1) {
      setState(() {
        _currentTourStepIndex++;
        _isTourPaused = false;
      });
      _playCurrentStep();
    } else {
      _stopTour();
    }
  }

  void _previousTourStep() {
    if (!_isTourPlaying) return;
    _stopOrbitTimer();
    if (_ttsService != null) {
      _ttsService!.onCompletion = null;
      _ttsService!.stop();
    }

    if (_ttsService != null) {
      _ttsService!.onCompletion = () {
        if (_isTourPlaying && !_isTourPaused) {
          Timer(const Duration(seconds: 2), () {
            if (_isTourPlaying && !_isTourPaused) {
              _nextTourStep();
            }
          });
        }
      };
    }

    if (_currentTourStepIndex > 0) {
      setState(() {
        _currentTourStepIndex--;
        _isTourPaused = false;
      });
      _playCurrentStep();
    }
  }

  Map<String, dynamic> _generateFallbackTourScript(
    Map<String, dynamic> simData,
  ) {
    final String scenarioName = simData['scenarioName'] ?? 'Attack Simulation';
    final Map<String, dynamic> target = simData['target'] ?? {};
    final String summary = simData['summary'] ?? '';
    final List<dynamic> attackers = simData['attackers'] ?? [];

    final String overview =
        'Starting 3D tour for scenario: $scenarioName. We are viewing the target server, '
        '${target['name']}, located in ${target['locationName']}. $summary';

    final List<Map<String, dynamic>> attackersList = [];
    for (var a in attackers) {
      if (a is Map<String, dynamic>) {
        attackersList.add({
          'nodeName': a['name'] ?? 'Attacker',
          'narration':
              'Analyzing threat vector from ${a['name']} located in ${a['locationName']}. '
              'It is launching a ${a['threatType']} with ${a['severity']} severity. '
              'Details: ${a['description']}.',
        });
      }
    }

    final String conclusion =
        'This concludes the attack simulation. The security team recommends monitoring firewall logs '
        'and implementing defensive measures against these simulated attack paths.';

    return {
      'overview': overview,
      'attackers': attackersList,
      'conclusion': conclusion,
    };
  }

  List<Map<String, dynamic>> _buildTourSteps(
    Map<String, dynamic> script,
    Map<String, dynamic> simData,
  ) {
    final List<Map<String, dynamic>> steps = [];
    final Map<String, dynamic> target = simData['target'] ?? {};
    final List<dynamic> attackers = simData['attackers'] ?? [];

    steps.add({
      'title': 'Target: ${target['name']}',
      'latitude': _toDouble(target['latitude']),
      'longitude': _toDouble(target['longitude']),
      'range': 4000000.0,
      'tilt': 30.0,
      'narration': script['overview'] ?? '',
    });

    final regionsScriptList = script['attackers'] as List? ?? [];
    final Map<String, String> attackerNarrations = {};
    for (var reg in regionsScriptList) {
      if (reg is Map && reg['nodeName'] != null) {
        attackerNarrations[reg['nodeName'].toString().toUpperCase()] =
            reg['narration']?.toString() ?? '';
      }
    }

    for (var a in attackers) {
      if (a is! Map<String, dynamic>) continue;
      final String nodeName = a['name'] ?? 'Attacker';
      final String location = a['locationName'] ?? 'Unknown';
      final double lat = _toDouble(a['latitude']);
      final double lon = _toDouble(a['longitude']);
      final String narration =
          attackerNarrations[nodeName.toUpperCase()] ??
          'Focusing on threat node $nodeName located in $location, launching a ${a['threatType']} against the target.';

      steps.add({
        'title': 'Attacker: $nodeName ($location)',
        'latitude': lat,
        'longitude': lon,
        'range': 2000000.0,
        'tilt': 45.0,
        'narration': narration,
      });
    }

    steps.add({
      'title': 'Simulation Conclusion',
      'latitude': _toDouble(target['latitude']),
      'longitude': _toDouble(target['longitude']),
      'range': 4500000.0,
      'tilt': 35.0,
      'narration': script['conclusion'] ?? '',
    });

    return steps;
  }

  Future<void> _generateTourScript() async {
    if (_simulationData == null) return;

    setState(() {
      _isTourScriptLoading = true;
      _tourError = null;
      _tourSteps = [];
      _currentTourStepIndex = 0;
    });

    try {
      final prompt = GeminiPromptTemplate.fillSimulationTourScriptPrompt(
        _simulationData!,
      );
      final geminiService = context.read<GeminiService>();
      final responseText = await geminiService.generateThreatSummary(prompt);

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

      Map<String, dynamic> scriptData;
      try {
        scriptData = json.decode(cleanJson) as Map<String, dynamic>;
      } catch (e) {
        debugPrint(
          'cyber visualiser Simulation Tour JSON Parse Error: $e. Falling back to template.',
        );
        scriptData = _generateFallbackTourScript(_simulationData!);
      }

      final steps = _buildTourSteps(scriptData, _simulationData!);
      setState(() {
        _tourSteps = steps;
        _tourError = null;
      });
    } catch (e) {
      debugPrint(
        'cyber visualiser Simulation Tour Script Generation Error: $e',
      );
      final fallbackScript = _generateFallbackTourScript(_simulationData!);
      setState(() {
        _tourSteps = _buildTourSteps(fallbackScript, _simulationData!);
        _tourError = null;
      });
    } finally {
      setState(() {
        _isTourScriptLoading = false;
      });
    }
  }

  Future<void> _startTourFlow() async {
    if (_generatedKml.isEmpty) {
      if (_promptController.text.trim().isEmpty) {
        _promptController.text = _presets.first;
      }
      await _runSimulation();
    }

    if (_generatedKml.isEmpty) {
      return;
    }

    await _generateTourScript();

    if (_tourSteps.isNotEmpty) {
      _startTourPlayback();
    }
  }

  Future<void> _clearSimulation() async {
    final lgService = context.read<LgService>();
    _stopTour();
    setState(() {
      _isLoading = true;
      _statusMessage = 'Clearing Liquid Galaxy visuals...';
    });

    try {
      await lgService.cleanKML();
      setState(() {
        _simulationData = null;
        _tourSteps = [];
        _currentTourStepIndex = 0;
        _isTourPlaying = false;
        _isTourPaused = false;
        _isVisualized = false;
        _generatedKml = '';
        _simulationSummary = '';
        _isLoading = false;
        _statusMessage = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Simulation cleared from Liquid Galaxy.'),
            backgroundColor: Colors.indigo,
          ),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _statusMessage = '';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear visuals: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lgService = context.watch<LgService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderBanner(context, isDark),
            _buildRigConnectionBar(lgService, isDark),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildIntroCard(isDark),
                    const SizedBox(height: 16),
                    _buildFormCard(lgService, isDark),
                    const SizedBox(height: 16),
                    _buildTourPlayerCard(isDark),
                    if (_isLoading ||
                        _statusMessage.isNotEmpty ||
                        _errorMessage.isNotEmpty ||
                        _generatedKml.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      _buildStatusAndResultCard(isDark),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTourPlayerCard(bool isDark) {
    final bool hasSimulation =
        _generatedKml.isNotEmpty && _simulationData != null;
    final activeColor = isDark
        ? const Color(0xFF00E5FF)
        : const Color(0xFF3B82F6);

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1124) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? const Color(0xFF1F294D) : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.12)
                : Colors.black.withOpacity(0.02),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: activeColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.map_rounded, color: activeColor, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3D GEOGRAPHIC TOUR',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : const Color(0xFF0F172A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    Text(
                      _isTourPlaying
                          ? 'Step ${_currentTourStepIndex + 1} of ${_tourSteps.length}: ${_tourSteps[_currentTourStepIndex]['title']}'
                          : (hasSimulation
                                ? 'Simulation ready. Start tour narration.'
                                : 'No scenario generated yet.'),
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark
                            ? Colors.grey.shade400
                            : Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (_isTourScriptLoading) ...[
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20.0),
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Generating 3D Tour script with Gemini AI...',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: isDark
                            ? Colors.grey.shade300
                            : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (!_isTourPlaying) ...[
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: activeColor,
                      foregroundColor: isDark ? Colors.black : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: _isLoading ? null : _startTourFlow,
                    icon: Icon(
                      hasSimulation
                          ? Icons.play_arrow_rounded
                          : Icons.auto_mode_rounded,
                      size: 22,
                    ),
                    label: Text(
                      hasSimulation ? 'Start 3D Tour' : 'Generate & Start Tour',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
                if (hasSimulation) ...[
                  const SizedBox(width: 12),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: activeColor.withOpacity(0.12),
                      foregroundColor: activeColor,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      padding: const EdgeInsets.all(14),
                    ),
                    icon: const Icon(Icons.refresh_rounded, size: 20),
                    tooltip: 'Pre-generate Tour Script',
                    onPressed: _isLoading ? null : _generateTourScript,
                  ),
                ],
              ],
            ),
          ] else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: _tourSteps.isEmpty
                    ? 0
                    : (_currentTourStepIndex + 1) / _tourSteps.length,
                backgroundColor: isDark
                    ? Colors.blueGrey.shade900
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 80),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141A35) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1F294D)
                      : Colors.grey.shade200,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'NARRATION SUBTITLES',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w900,
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (_ttsService != null &&
                          _ttsService!.isSpeaking &&
                          !_isTourPaused)
                        Row(
                          children: List.generate(
                            4,
                            (index) => Container(
                              margin: const EdgeInsets.only(left: 2),
                              width: 3,
                              height: 10 + (index % 2 == 0 ? 4 : 0),
                              decoration: BoxDecoration(
                                color: activeColor,
                                borderRadius: BorderRadius.circular(1),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    _tourSteps[_currentTourStepIndex]['narration'] ?? '',
                    style: TextStyle(
                      fontSize: 13,
                      height: 1.5,
                      color: isDark ? Colors.grey.shade200 : Colors.black87,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.blueGrey.shade900
                        : Colors.grey.shade100,
                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: const Icon(Icons.skip_previous_rounded, size: 20),
                  onPressed: _currentTourStepIndex == 0
                      ? null
                      : _previousTourStep,
                ),
                const SizedBox(width: 14),

                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: activeColor,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(18),
                    ),
                    padding: const EdgeInsets.all(16),
                  ),
                  icon: Icon(
                    _isTourPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    size: 30,
                  ),
                  onPressed: _isTourPaused ? _resumeTour : _pauseTour,
                ),
                const SizedBox(width: 14),

                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: isDark
                        ? Colors.blueGrey.shade900
                        : Colors.grey.shade100,
                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: Icon(
                    _currentTourStepIndex == _tourSteps.length - 1
                        ? Icons.check_rounded
                        : Icons.skip_next_rounded,
                    size: 20,
                  ),
                  onPressed: _nextTourStep,
                ),
                const SizedBox(width: 24),

                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.12),
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: const Icon(Icons.stop_rounded, size: 20),
                  onPressed: _stopTour,
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context, bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1124) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF1F294D) : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? const Color(0xFF00E5FF).withOpacity(0.05)
                      : Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(
              Icons.psychology,
              color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF3B82F6),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'ATTACK SIMULATOR',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'AI Threat Projection Console',
                  style: TextStyle(
                    fontSize: 11,
                    color: subtitleColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRigConnectionBar(LgService lgService, bool isDark) {
    final statusColor = lgService.isConnected
        ? const Color(0xFF00FFC2)
        : Colors.redAccent;
    final statusText = lgService.isConnected ? "Rig Connected" : "Rig Offline";
    final activeGlowColor = lgService.isConnected
        ? const Color(0xFF00FFC2)
        : Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1124) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF1F294D) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.1)
                  : Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: activeGlowColor.withOpacity(
                              0.6 * _pulseController.value,
                            ),
                            blurRadius: 8 * _pulseController.value,
                            spreadRadius: 2 * _pulseController.value,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Text(
                  '$statusText • ${lgService.connectionModel.ip}:${lgService.connectionModel.port}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Text(
              lgService.isConnected ? 'Ready' : 'Offline',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: lgService.isConnected
                    ? const Color(0xFF00FFC2)
                    : Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIntroCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1124) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF1F294D) : Colors.grey.shade200,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.12)
                  : Colors.black.withOpacity(0.02),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF00E5FF).withOpacity(0.08)
                    : const Color(0xFF3B82F6).withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.info_outline_rounded,
                color: isDark
                    ? const Color(0xFF00E5FF)
                    : const Color(0xFF3B82F6),
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'How it works',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : const Color(0xFF0F172A),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Describe a cybersecurity attack scenario in natural language. Gemini AI will interpret the locations, attack type, and intensity, generate a corresponding KML file, project it on the screens, and fly your Liquid Galaxy viewport straight to the center of the action.',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? Colors.grey.shade400 : Colors.black87,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormCard(LgService lgService, bool isDark) {
    final activeColor = isDark
        ? const Color(0xFF00E5FF)
        : const Color(0xFF3B82F6);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1124) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF1F294D) : Colors.grey.shade200,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.12)
                  : Colors.black.withOpacity(0.02),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Attack Scenario Parameters',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark
                      ? const Color(0xFF00E5FF)
                      : const Color(0xFF3B82F6),
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _promptController,
                maxLines: 3,
                maxLength: 200,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please enter a description for the simulation scenario';
                  }
                  return null;
                },
                decoration: const InputDecoration(
                  labelText: 'Describe the Attack Scenario',
                  hintText:
                      'e.g. show me a ddos attack from multiple locations to a server based in usa',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Quick Presets (Tap to populate):',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets.map((preset) {
                  return ActionChip(
                    padding: EdgeInsets.zero,
                    labelPadding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 0,
                    ),
                    label: Text(
                      preset.length > 35
                          ? '${preset.substring(0, 35)}...'
                          : preset,
                      style: const TextStyle(fontSize: 10.5),
                    ),
                    backgroundColor: isDark
                        ? const Color(0xFF141A35)
                        : Colors.grey.shade100,
                    side: BorderSide(
                      color: isDark
                          ? const Color(0xFF1F294D)
                          : Colors.grey.shade200,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onPressed: _isLoading
                        ? null
                        : () {
                            setState(() {
                              _promptController.text = preset;
                            });
                          },
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: activeColor,
                        foregroundColor: isDark ? Colors.black : Colors.white,
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      onPressed: _isLoading ? null : _runSimulation,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.play_arrow_rounded, size: 20),
                      label: const Text(
                        'Simulate Scenario',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  if (_isVisualized) ...[
                    const SizedBox(width: 12),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.redAccent.withOpacity(0.12),
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(
                          color: Colors.redAccent,
                          width: 1.2,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        padding: const EdgeInsets.all(12),
                      ),
                      icon: const Icon(Icons.layers_clear, size: 20),
                      tooltip: 'Clear Simulation Visuals',
                      onPressed: _isLoading ? null : _clearSimulation,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatusAndResultCard(bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.all(20.0),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1124) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isDark ? const Color(0xFF1F294D) : Colors.grey.shade200,
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withOpacity(0.12)
                  : Colors.black.withOpacity(0.02),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Simulation Status & Output',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark
                    ? const Color(0xFF00E5FF)
                    : const Color(0xFF3B82F6),
                letterSpacing: 0.5,
              ),
            ),
            const SizedBox(height: 12),
            if (_isLoading && _statusMessage.isNotEmpty) ...[
              Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ] else if (_errorMessage.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _errorMessage,
                        style: const TextStyle(
                          color: Colors.redAccent,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ] else if (_statusMessage.isNotEmpty) ...[
              Row(
                children: [
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Color(0xFF00FFC2),
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF00FFC2),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            if (_simulationSummary.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.insights_rounded,
                        color: isDark
                            ? const Color(0xFF00E5FF)
                            : const Color(0xFF3B82F6),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI Simulation Summary',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? const Color(0xFF00E5FF)
                              : const Color(0xFF0F172A),
                        ),
                      ),
                    ],
                  ),
                  Consumer<TextToSpeechService>(
                    builder: (context, tts, _) {
                      final isThisSpeaking =
                          tts.isSpeaking &&
                          tts.currentUtterance == 'simulation_summary';
                      return IconButton(
                        icon: Icon(
                          isThisSpeaking
                              ? Icons.volume_up_rounded
                              : Icons.volume_mute_rounded,
                          color: isDark
                              ? const Color(0xFF00E5FF)
                              : const Color(0xFF3B82F6),
                          size: 20,
                        ),
                        tooltip: isThisSpeaking
                            ? 'Stop Speaking'
                            : 'Speak Summary',
                        onPressed: () {
                          if (isThisSpeaking) {
                            tts.stop();
                          } else {
                            tts.speak(
                              _simulationSummary,
                              utteranceId: 'simulation_summary',
                            );
                          }
                        },
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF141A35)
                      : Colors.blue.shade50.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1F294D)
                        : Colors.blue.shade100,
                  ),
                ),
                child: MarkdownBody(
                  data: _simulationSummary,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                        p: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: isDark ? Colors.grey.shade300 : Colors.black87,
                        ),
                      ),
                ),
              ),
            ],
            if (_generatedKml.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Generated KML Document',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    tooltip: 'Copy KML code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _generatedKml));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('KML copied to clipboard!'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                height: 180,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF070B19)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1F294D)
                        : Colors.grey.shade300,
                  ),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    _generatedKml,
                    style: TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: isDark
                          ? const Color(0xFF00FFC2)
                          : const Color(0xFF0F172A),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
