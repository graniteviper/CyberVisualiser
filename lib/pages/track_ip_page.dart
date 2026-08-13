import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/track_ip_provider.dart';
import '../services/lg_service.dart';
import '../services/track_ip_lg_service.dart';
import '../services/gemini_service.dart';
import '../services/text_to_speech_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

class TrackIpPage extends StatefulWidget {
  const TrackIpPage({super.key});

  @override
  State<TrackIpPage> createState() => _TrackIpPageState();
}

class _TrackIpPageState extends State<TrackIpPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  double _maxAgeInDays = 5.0;
  TextToSpeechService? _ttsService;
  late final AnimationController _pulseController;

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
    _ipController.dispose();
    _ttsService?.stop();
    _pulseController.dispose();
    super.dispose();
  }

  String? _validateIp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an IP address';
    }
    final ipTrimmed = value.trim();
    // Regular expression for validating IPv4
    final ipv4Reg = RegExp(r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$');
    // Regular expression for validating IPv6
    final ipv6Reg = RegExp(
      r'^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$',
    );

    if (!ipv4Reg.hasMatch(ipTrimmed) && !ipv6Reg.hasMatch(ipTrimmed)) {
      return 'Please enter a valid IPv4 or IPv6 address';
    }
    return null;
  }

  void _submitSearch(TrackIpProvider provider, TrackIpLgService lgService) {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      provider.fetchIpDetails(
        ipAddress: _ipController.text.trim(),
        maxAgeInDays: _maxAgeInDays.toInt(),
        lgService: lgService,
      );
    }
  }

  void _submitGeminiAnalysis(
    TrackIpProvider provider,
    TrackIpLgService lgService,
    GeminiService geminiService,
  ) async {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      final ipAddress = _ipController.text.trim();
      final maxAge = _maxAgeInDays.toInt();

      final tts = Provider.of<TextToSpeechService>(context, listen: false);
      await tts.stop();

      if (provider.report != null && provider.report!.ipAddress == ipAddress) {
        await provider.analyzeWithGemini(geminiService);
      } else {
        await provider.trackAndAnalyze(
          ipAddress: ipAddress,
          maxAgeInDays: maxAge,
          geminiService: geminiService,
          lgService: lgService,
        );
      }

      if (!mounted) return;
      if (provider.geminiSummary != null) {
        await tts.speak(provider.geminiSummary!);
      }
    }
  }

  Color _getSeverityColor(int score) {
    if (score > 50) {
      return Colors.redAccent.shade400;
    } else if (score > 20) {
      return Colors.orangeAccent;
    } else {
      return Colors.greenAccent.shade400;
    }
  }

  String _getBadgeText(int score) {
    if (score > 50) return 'HIGH RISK';
    if (score > 20) return 'MEDIUM RISK';
    return 'LOW RISK';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrackIpProvider>();
    final lgService = context.watch<LgService>();
    final trackLgService = context.watch<TrackIpLgService>();
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
                    _buildFormCard(provider, trackLgService, isDark),
                    const SizedBox(height: 16),
                    _buildResultsSection(provider, trackLgService, isDark),
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
              Icons.location_on_rounded,
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
                  'IP TRACKER',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                    letterSpacing: 2.0,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Threat Intel Profiler & Geolocator',
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

  Widget _buildFormCard(
    TrackIpProvider provider,
    TrackIpLgService trackLgService,
    bool isDark,
  ) {
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
                'IP Intel Search Parameters',
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
                controller: _ipController,
                validator: _validateIp,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: InputDecoration(
                  labelText: 'Target IP Address',
                  hintText: 'e.g. 213.209.159.227',
                  prefixIcon: Icon(
                    Icons.search_rounded,
                    color: isDark
                        ? const Color(0xFF00E5FF).withOpacity(0.7)
                        : const Color(0xFF3B82F6),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Search Window (Days):',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF00E5FF).withOpacity(0.12)
                          : const Color(0xFF3B82F6).withOpacity(0.08),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '${_maxAgeInDays.toInt()} Days',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? const Color(0xFF00E5FF)
                            : const Color(0xFF3B82F6),
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _maxAgeInDays,
                min: 1.0,
                max: 30.0,
                divisions: 29,
                activeColor: activeColor,
                inactiveColor: isDark
                    ? Colors.blueGrey.shade800
                    : Colors.grey.shade300,
                label: '${_maxAgeInDays.toInt()} days',
                onChanged: provider.isLoading
                    ? null
                    : (val) {
                        setState(() {
                          _maxAgeInDays = val;
                        });
                      },
              ),
              const SizedBox(height: 12),
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
                      onPressed: provider.isLoading
                          ? null
                          : () => _submitSearch(provider, trackLgService),
                      icon: provider.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.location_searching_rounded,
                              size: 20,
                            ),
                      label: const Text(
                        'Track IP Address',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                  if (provider.isVisualized) ...[
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
                      tooltip: 'Clear KML from Liquid Galaxy',
                      onPressed: provider.isLoading
                          ? null
                          : () => provider.clearLGVisuals(trackLgService),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: isDark
                      ? const Color(0xFF8A2BE2).withOpacity(0.12)
                      : Colors.indigo.shade50,
                  foregroundColor: isDark
                      ? const Color(0xFFE040FB)
                      : Colors.indigo,
                  side: BorderSide(
                    color: isDark
                        ? const Color(0xFF8A2BE2).withOpacity(0.3)
                        : Colors.indigo.shade200,
                  ),
                  minimumSize: const Size(0, 48),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                onPressed: (provider.isLoading || provider.isAnalyzing)
                    ? null
                    : () => _submitGeminiAnalysis(
                        provider,
                        trackLgService,
                        context.read<GeminiService>(),
                      ),
                icon: provider.isAnalyzing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.psychology_rounded, size: 20),
                label: const Text(
                  'Analyse with Gemini',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsSection(
    TrackIpProvider provider,
    TrackIpLgService trackLgService,
    bool isDark,
  ) {
    if (provider.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60.0),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Fetching records & generating KML maps...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.errorMessage != null) {
      return Card(
        color: Colors.red.shade900.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.red.shade900.withOpacity(0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 36,
              ),
              const SizedBox(height: 8),
              const Text(
                'Intel Query Error',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.red.shade200),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.report == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.radar_rounded, color: Colors.grey, size: 48),
              SizedBox(height: 12),
              Text(
                'No active tracked IP.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Enter an IP above to lookup threat logs and visualize them.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final report = provider.report!;
    final sevColor = _getSeverityColor(report.abuseConfidenceScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Premium App Summary Card representing overlay visual content
        Card(
          elevation: 4,
          color: const Color(0xFF0F111A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.blueGrey.shade800, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'IP TRACKER ANALYSIS',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.blue.shade400,
                        letterSpacing: 1.0,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Close Card and Clear Visuals',
                      onPressed: () => provider.clearState(
                        lgService: trackLgService,
                        ttsService: context.read<TextToSpeechService>(),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16, color: Colors.blueGrey),
                Text(
                  report.ipAddress,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: sevColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getBadgeText(report.abuseConfidenceScore),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (provider.isVisualized)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade900.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue, width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tv_rounded,
                              size: 10,
                              color: Colors.cyanAccent,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Visualizing on LG',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyanAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCardInfoRow(
                  'Country',
                  report.countryName.isNotEmpty
                      ? report.countryName
                      : report.countryCode,
                ),
                _buildCardInfoRow('ISP', report.isp),
                _buildCardInfoRow(
                  'Domain',
                  report.domain.isEmpty ? 'N/A' : report.domain,
                ),
                _buildCardInfoRow(
                  'Confidence',
                  '${report.abuseConfidenceScore}%',
                  valColor: sevColor,
                  isBold: true,
                ),
                _buildCardInfoRow(
                  'Total Reports',
                  '${report.totalReports} reports',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildTourPlayerCard(provider, trackLgService, isDark),
        if (provider.isAnalyzing)
          Card(
            elevation: 2,
            margin: const EdgeInsets.only(top: 16.0),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Gemini is analyzing IP threat intelligence...',
                    style: TextStyle(
                      color: isDark ? Colors.cyanAccent : Colors.indigo,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          )
        else if (provider.geminiError != null)
          Card(
            color: Colors.red.shade900.withOpacity(0.15),
            margin: const EdgeInsets.only(top: 16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
              side: BorderSide(color: Colors.red.shade900.withOpacity(0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(
                        Icons.error_outline,
                        color: Colors.redAccent,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Gemini Analysis Failed',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.redAccent,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    provider.geminiError!,
                    style: TextStyle(color: Colors.red.shade200, fontSize: 12),
                  ),
                ],
              ),
            ),
          )
        else if (provider.geminiSummary != null)
          Card(
            elevation: 4,
            color: isDark
                ? const Color(0xFF131622)
                : Colors.teal.shade50.withValues(alpha: 0.2),
            margin: const EdgeInsets.only(top: 16.0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: isDark ? Colors.teal.shade900 : Colors.teal.shade200,
                width: 1.5,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.teal.shade900.withValues(alpha: 0.4)
                              : Colors.teal.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? Colors.teal.shade800
                                : Colors.teal.shade200,
                            width: 1,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.psychology_rounded,
                              color: isDark
                                  ? Colors.teal.shade300
                                  : Colors.teal.shade800,
                              size: 16,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'GEMINI AI THREAT REPORT',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w900,
                                color: isDark
                                    ? Colors.teal.shade300
                                    : Colors.teal.shade800,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Consumer<TextToSpeechService>(
                        builder: (context, tts, _) {
                          return IconButton(
                            tooltip: tts.isSpeaking
                                ? 'Stop Speaking'
                                : 'Listen to Report',
                            icon: Icon(
                              tts.isSpeaking
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_mute_rounded,
                              color: isDark
                                  ? Colors.teal.shade300
                                  : Colors.teal.shade800,
                            ),
                            onPressed: () {
                              if (tts.isSpeaking) {
                                tts.stop();
                              } else {
                                tts.speak(provider.geminiSummary!);
                              }
                            },
                          );
                        },
                      ),
                    ],
                  ),
                  const Divider(height: 20, color: Colors.transparent),
                  GeminiReportRenderer(text: provider.geminiSummary!),
                ],
              ),
            ),
          ),
        const SizedBox(height: 20),
        Text(
          'THREAT LOG DETAILS (${report.reports.length})',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.blue.shade200 : Colors.indigo.shade800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        if (report.reports.isEmpty)
          Card(
            color: isDark ? const Color(0xFF141622) : Colors.grey.shade100,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
              child: Center(
                child: Text(
                  'No reports returned within the search window.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: report.reports.length,
            itemBuilder: (context, index) {
              final item = report.reports[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isDark
                        ? Colors.blueGrey.shade900
                        : Colors.grey.shade300,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.reportedAt.toLocal().toString().split(
                                  ' ',
                                )[0],
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade800.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.reporterCountryName.isNotEmpty
                                  ? item.reporterCountryName
                                  : item.reporterCountryCode,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (item.categoryNames.isNotEmpty) ...[
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: item.categoryNames.map((name) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.red.shade900.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent.shade100,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        item.comment.trim().isEmpty
                            ? 'No comment provided.'
                            : item.comment.trim(),
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: item.comment.trim().isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: isDark ? Colors.grey.shade300 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTourPlayerCard(
    TrackIpProvider provider,
    TrackIpLgService trackLgService,
    bool isDark,
  ) {
    final ttsService = context.watch<TextToSpeechService>();
    final activeColor = isDark ? const Color(0xFF00E5FF) : const Color(0xFF3B82F6);
    final cardBg = isDark ? const Color(0xFF0D1124) : Colors.white;
    final borderColor = isDark ? const Color(0xFF1F294D) : Colors.grey.shade200;

    return Container(
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: provider.isTourPlaying ? activeColor.withOpacity(0.5) : borderColor,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: provider.isTourPlaying
                ? activeColor.withOpacity(0.08)
                : Colors.black.withOpacity(0.02),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: provider.isTourPlaying
                      ? activeColor.withOpacity(0.12)
                      : (isDark ? Colors.blueGrey.shade900 : Colors.grey.shade100),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.explore_rounded,
                  color: provider.isTourPlaying ? activeColor : Colors.grey,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '3D GEOGRAPHIC TOUR',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w900,
                        color: provider.isTourPlaying ? activeColor : (isDark ? Colors.white70 : Colors.black87),
                        letterSpacing: 1.2,
                      ),
                    ),
                    if (provider.isTourPlaying)
                      Text(
                        'Step ${provider.currentTourStepIndex + 1} of ${provider.tourSteps.length}: ${provider.tourSteps[provider.currentTourStepIndex]['title']}',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          fontWeight: FontWeight.w500,
                        ),
                      )
                    else
                      Text(
                        'Narrated Liquid Galaxy Tour',
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.grey.shade500 : Colors.grey.shade500,
                        ),
                      ),
                  ],
                ),
              ),
              if (provider.isTourPlaying) ...[
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: provider.isTourPaused ? Colors.amber : Colors.redAccent,
                        shape: BoxShape.circle,
                        boxShadow: [
                          if (!provider.isTourPaused)
                            BoxShadow(
                              color: Colors.redAccent.withOpacity(0.6 * _pulseController.value),
                              blurRadius: 6 * _pulseController.value,
                              spreadRadius: 1 * _pulseController.value,
                            ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 8),
                Text(
                  provider.isTourPaused ? 'PAUSED' : 'LIVE',
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.bold,
                    color: provider.isTourPaused ? Colors.amber : Colors.redAccent,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 16),

          // Loading State
          if (provider.isTourScriptLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20.0),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(
                      strokeWidth: 3,
                      valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Gemini is scripting your 3D tour narration...',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            )

          // Script Not Generated Yet State
          else if (provider.tourSteps.isEmpty) ...[
            Text(
              'Explore the cyber threat intelligence coordinates interactively. '
              'Gemini will formulate a customized narration script linking origin networks and targets, '
              'while Liquid Galaxy dynamically flies and orbits around each reporting region.',
              style: TextStyle(
                fontSize: 13,
                color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: activeColor.withOpacity(0.12),
                foregroundColor: activeColor,
                side: BorderSide(color: activeColor.withOpacity(0.3), width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              onPressed: () => provider.generateTour(context.read<GeminiService>()),
              icon: const Icon(Icons.auto_awesome, size: 18),
              label: const Text(
                'Generate 3D Audio Tour',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ]

          // Tour Ready (Not Playing) State
          else if (!provider.isTourPlaying) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141A33) : Colors.blue.shade50.withOpacity(0.3),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF232D5C) : Colors.blue.shade100,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.check_circle_outline_rounded, color: activeColor, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '3D Tour script generated successfully with ${provider.tourSteps.length} stops.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? Colors.grey.shade300 : Colors.blue.shade900,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
                    onPressed: () => provider.startTour(ttsService, trackLgService),
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: const Text(
                      'Start 3D Tour',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.12),
                    foregroundColor: Colors.redAccent,
                    side: const BorderSide(color: Colors.redAccent, width: 1.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    padding: const EdgeInsets.all(14),
                  ),
                  icon: const Icon(Icons.refresh, size: 20),
                  tooltip: 'Regenerate Tour',
                  onPressed: () => provider.generateTour(context.read<GeminiService>()),
                ),
              ],
            ),
          ]

          // Active Tour Player
          else ...[
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: (provider.currentTourStepIndex + 1) / provider.tourSteps.length,
                backgroundColor: isDark ? Colors.blueGrey.shade900 : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                minHeight: 5,
              ),
            ),
            const SizedBox(height: 16),

            // Subtitle Card / Narration Text
            Container(
              padding: const EdgeInsets.all(16),
              constraints: const BoxConstraints(minHeight: 80),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF13172E) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isDark ? const Color(0xFF1E264D) : Colors.grey.shade200,
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
                          color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          letterSpacing: 1.0,
                        ),
                      ),
                      if (ttsService.isSpeaking && !provider.isTourPaused)
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
                    provider.tourSteps[provider.currentTourStepIndex]['narration'],
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

            // Player Controllers
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Back
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.blueGrey.shade900 : Colors.grey.shade100,
                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: const Icon(Icons.skip_previous_rounded, size: 20),
                  onPressed: provider.currentTourStepIndex == 0
                      ? null
                      : () => provider.previousStep(ttsService, trackLgService),
                ),
                const SizedBox(width: 14),

                // Play / Pause Toggle
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
                    provider.isTourPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    size: 30,
                  ),
                  onPressed: () {
                    if (provider.isTourPaused) {
                      provider.resumeTour(ttsService, trackLgService);
                    } else {
                      provider.pauseTour(ttsService);
                    }
                  },
                ),
                const SizedBox(width: 14),

                // Next
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: isDark ? Colors.blueGrey.shade900 : Colors.grey.shade100,
                    foregroundColor: isDark ? Colors.white70 : Colors.black87,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    padding: const EdgeInsets.all(12),
                  ),
                  icon: Icon(
                    provider.currentTourStepIndex == provider.tourSteps.length - 1
                        ? Icons.check_rounded
                        : Icons.skip_next_rounded,
                    size: 20,
                  ),
                  onPressed: () => provider.nextStep(ttsService, trackLgService),
                ),
                const SizedBox(width: 24),

                // Stop
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
                  onPressed: () => provider.stopTour(ttsService),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCardInfoRow(
    String label,
    String val, {
    Color? valColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              val,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: valColor ?? Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GeminiReportRenderer extends StatelessWidget {
  final String text;

  const GeminiReportRenderer({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final baseStyleSheet = MarkdownStyleSheet.fromTheme(Theme.of(context));

    return MarkdownBody(
      data: text,
      selectable: true,
      styleSheet: baseStyleSheet.copyWith(
        p: baseStyleSheet.p?.copyWith(
          color: isDark ? Colors.grey.shade300 : Colors.black87,
          fontSize: 13,
          height: 1.5,
        ),
        h1: baseStyleSheet.h1?.copyWith(
          color: isDark ? Colors.teal.shade200 : Colors.teal.shade800,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        h2: baseStyleSheet.h2?.copyWith(
          color: isDark ? Colors.blue.shade200 : Colors.indigo.shade800,
          fontSize: 14,
          fontWeight: FontWeight.bold,
        ),
        h3: baseStyleSheet.h3?.copyWith(
          color: isDark ? Colors.blue.shade200 : Colors.indigo.shade800,
          fontSize: 13,
          fontWeight: FontWeight.bold,
        ),
        listBullet: baseStyleSheet.listBullet?.copyWith(
          color: isDark ? Colors.teal.shade300 : Colors.teal.shade700,
          fontSize: 13,
        ),
        strong: baseStyleSheet.strong?.copyWith(
          fontWeight: FontWeight.bold,
          color: isDark ? Colors.white : Colors.black,
        ),
        h1Padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
        h2Padding: const EdgeInsets.only(top: 14.0, bottom: 6.0),
        h3Padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
        listIndent: 20.0,
      ),
    );
  }
}
