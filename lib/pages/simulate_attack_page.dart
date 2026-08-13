import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../services/lg_service.dart';
import '../services/gemini_service.dart';
import '../services/text_to_speech_service.dart';
import '../templates/simulation_prompt_template.dart';
import '../templates/simulation_kml_generator.dart';

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
    _promptController.dispose();
    _ttsService?.stop();
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
      try {
        final decodedJson = json.decode(jsonBlock);
        summary = decodedJson['summary'] ?? '';
      } catch (e) {
        debugPrint('Failed to extract summary from JSON: $e');
      }

      setState(() {
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

  Future<void> _clearSimulation() async {
    final lgService = context.read<LgService>();
    _ttsService?.stop();
    setState(() {
      _isLoading = true;
      _statusMessage = 'Clearing Liquid Galaxy visuals...';
    });

    try {
      await lgService.cleanKML();
      setState(() {
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
