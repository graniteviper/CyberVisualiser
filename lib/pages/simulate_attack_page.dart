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

class _SimulateAttackPageState extends State<SimulateAttackPage> {
  final _formKey = GlobalKey<FormState>();
  final _promptController = TextEditingController();

  bool _isLoading = false;
  String _statusMessage = '';
  String _generatedKml = '';
  String _errorMessage = '';
  bool _isVisualized = false;
  String _simulationSummary = '';
  TextToSpeechService? _ttsService;

  final List<String> _presets = [
    'show me a ddos attack from multiple locations to a server based in usa',
    'brute-force ssh attack from china and russia on a server in germany',
    'sql injection exploit from east europe targeting a database in brazil',
    'botnet spam wave from south america and africa directed at a server in japan',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ttsService = Provider.of<TextToSpeechService>(context, listen: false);
  }

  @override
  void dispose() {
    _promptController.dispose();
    _ttsService?.stop();
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
            _buildHeaderBanner(isDark),
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

  Widget _buildHeaderBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F111A) : Colors.indigo.shade900,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.blue.shade900.withOpacity(0.5)
                : Colors.indigo.shade800,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Open navigation drawer',
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.psychology_outlined,
            color: isDark ? Colors.cyanAccent : Colors.amberAccent,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'ATTACK SIMULATOR',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
                Text(
                  'Simulate future cyber threats on Liquid Galaxy using Gemini AI',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.white70,
                    fontWeight: FontWeight.w400,
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
    final statusColor = lgService.isConnected ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF141622) : Colors.grey.shade200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Rig Server: ${lgService.isConnected ? "CONNECTED" : "DISCONNECTED"} (${lgService.connectionModel.ip}:${lgService.connectionModel.port})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          Text(
            lgService.isConnected
                ? 'Visualization Ready'
                : 'Visualization Offline',
            style: TextStyle(
              fontSize: 11,
              color: lgService.isConnected ? Colors.green : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIntroCard(bool isDark) {
    final cardBgColor = isDark
        ? const Color(0xFF1A1C29)
        : Colors.blue.shade50.withOpacity(0.5);
    final borderColor = isDark
        ? Colors.blue.shade900.withOpacity(0.3)
        : Colors.blue.shade100;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.info_outline_rounded,
            color: isDark ? Colors.cyanAccent : Colors.indigo.shade800,
            size: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'How it works',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.indigo.shade900,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Describe a cybersecurity attack scenario in natural language. Gemini AI will interpret the locations, attack type, and intensity, generate a corresponding KML file, project it on the screens, and fly your Liquid Galaxy viewport straight to the center of the action.',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? Colors.grey.shade300 : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(LgService lgService, bool isDark) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
              ? Colors.blueGrey.shade900.withOpacity(0.5)
              : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
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
                  color: isDark ? Colors.blue.shade200 : Colors.indigo.shade800,
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
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Quick Presets (Tap to populate):',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presets.map((preset) {
                  return ActionChip(
                    label: Text(
                      preset.length > 35
                          ? '${preset.substring(0, 35)}...'
                          : preset,
                      style: const TextStyle(fontSize: 11),
                    ),
                    backgroundColor: isDark
                        ? const Color(0xFF1F2235)
                        : Colors.grey.shade100,
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
                        backgroundColor: isDark
                            ? Colors.cyan.shade900
                            : Colors.indigo.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
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
                          : const Icon(Icons.play_arrow_rounded),
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
                        backgroundColor: Colors.red.shade900.withOpacity(0.8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(14),
                      ),
                      icon: const Icon(Icons.layers_clear),
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
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
              ? Colors.blueGrey.shade900.withOpacity(0.5)
              : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Simulation Status & Output',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.blue.shade200 : Colors.indigo.shade800,
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
                  color: Colors.red.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      color: Colors.redAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
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
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _statusMessage,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.green,
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
                        color: isDark ? Colors.cyanAccent : Colors.indigo,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'AI Simulation Summary',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: isDark
                              ? Colors.cyanAccent
                              : Colors.indigo.shade900,
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
                          color: isDark ? Colors.cyanAccent : Colors.indigo,
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
                      ? const Color(0xFF141622)
                      : Colors.blue.shade50.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? Colors.blue.shade900.withOpacity(0.2)
                        : Colors.blue.shade100,
                  ),
                ),
                child: MarkdownBody(
                  data: _simulationSummary,
                  styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                      .copyWith(
                        p: TextStyle(
                          fontSize: 13.5,
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
                    icon: const Icon(Icons.copy, size: 18),
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
                      ? const Color(0xFF0F111A)
                      : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isDark
                        ? Colors.blueGrey.shade900
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
                          ? Colors.cyan.shade200
                          : Colors.indigo.shade900,
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
