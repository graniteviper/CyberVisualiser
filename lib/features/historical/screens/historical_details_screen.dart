import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cyber_visualiser/services/gemini_service.dart';
import 'package:cyber_visualiser/services/lg_service.dart';
import 'package:cyber_visualiser/services/text_to_speech_service.dart';
import '../models/historical_attack.dart';
import '../providers/historical_provider.dart';
import '../widgets/historical_gemini_dialog.dart';

/// Screen displaying the full details of a specific historical cyber incident.
class HistoricalDetailsScreen extends StatefulWidget {
  final HistoricalAttack attack;

  const HistoricalDetailsScreen({super.key, required this.attack});

  @override
  State<HistoricalDetailsScreen> createState() =>
      _HistoricalDetailsScreenState();
}

class _HistoricalDetailsScreenState extends State<HistoricalDetailsScreen> {
  late final TextToSpeechService _ttsService;
  late final LgService _lgService;
  late final HistoricalProvider _provider;

  @override
  void initState() {
    super.initState();
    _ttsService = Provider.of<TextToSpeechService>(context, listen: false);
    _lgService = Provider.of<LgService>(context, listen: false);
    _provider = Provider.of<HistoricalProvider>(context, listen: false);
  }

  @override
  void dispose() {
    // Stop tour playback on exit
    _provider.stopTour(_ttsService, _lgService);
    super.dispose();
  }

  /// Helper to return a semantic color corresponding to severity.
  Color _getSeverityColor(int severity) {
    if (severity >= 9) return const Color(0xFFD32F2F); // Critical (Red)
    if (severity >= 7) return const Color(0xFFF57C00); // High (Orange)
    if (severity >= 4) return const Color(0xFFFBC02D); // Medium (Yellow)
    return const Color(0xFF388E3C); // Low (Green)
  }

  void _openGeminiAssistant(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => HistoricalGeminiDialog(
        attack: widget.attack,
        contextAttacks: [widget.attack],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final severityColor = _getSeverityColor(widget.attack.attack.severity);
    final geminiService = Provider.of<GeminiService>(context, listen: false);

    final activeColor = isDark
        ? const Color(0xFF00E5FF)
        : Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text('INCIDENT DETAILS'),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.auto_awesome),
            tooltip: 'Ask Gemini',
            onPressed: () => _openGeminiAssistant(context),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Text(
              widget.attack.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Date, Category, and Severity Badges
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Date Chip
                _buildInfoBadge(
                  context,
                  icon: Icons.calendar_today_outlined,
                  label: '${widget.attack.month} ${widget.attack.year}',
                  color: isDark ? Colors.cyanAccent : Colors.indigo,
                ),
                // Category Chip
                _buildInfoBadge(
                  context,
                  icon: Icons.category_outlined,
                  label: widget.attack.attack.category,
                  color: Colors.orange,
                ),
                // Severity Chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: severityColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: severityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Severity ${widget.attack.attack.severity}/10',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: severityColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // Victim Profile Section
            _buildSectionHeader(context, 'Victim Information', Icons.business),
            const SizedBox(height: 12),
            _buildInfoCard(
              context,
              isDark: isDark,
              children: [
                _buildDetailsRow('Organization', widget.attack.victim.name),
                _buildDetailsRow('Country', widget.attack.victim.country),
                _buildDetailsRow(
                  'Country Code',
                  widget.attack.victim.countryCode,
                ),
                _buildDetailsRow(
                  'Location',
                  'Lat: ${widget.attack.victim.latitude.toStringAsFixed(4)}, Lon: ${widget.attack.victim.longitude.toStringAsFixed(4)}',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Attacker Profile Section
            _buildSectionHeader(
              context,
              'Attacker Information',
              Icons.person_outline,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              context,
              isDark: isDark,
              children: [
                _buildDetailsRow('Attacker Name', widget.attack.attacker.name),
                _buildDetailsRow('Attacker Type', widget.attack.attacker.type),
              ],
            ),
            const SizedBox(height: 24),

            // Attack Profile Details
            _buildSectionHeader(
              context,
              'Incident Profile',
              Icons.analytics_outlined,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              context,
              isDark: isDark,
              children: [
                _buildDetailsRow(
                  'Target Sector',
                  widget.attack.attack.targetSector,
                ),
                _buildDetailsRow(
                  'Impact Severity',
                  '${widget.attack.attack.severity} / 10',
                ),
                _buildDetailsRow(
                  'Categorization',
                  widget.attack.attack.category,
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Incident Summary Narrative
            _buildSectionHeader(
              context,
              'Narrative Summary',
              Icons.description_outlined,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161925) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.blueGrey.shade900.withOpacity(0.5)
                      : Colors.grey.shade200,
                ),
              ),
              child: Text(
                widget.attack.summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: isDark ? Colors.grey.shade300 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 12),

            // Gemini Action Card
            Card(
              color: isDark ? const Color(0xFF1F2336) : Colors.indigo.shade50,
              margin: EdgeInsets.zero,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: BorderSide(
                  color: isDark
                      ? Colors.blueGrey.shade800
                      : Colors.indigo.shade200,
                ),
              ),
              child: InkWell(
                onTap: () => _openGeminiAssistant(context),
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      Icon(
                        Icons.psychology,
                        color: isDark ? Colors.cyanAccent : Colors.indigo,
                        size: 32,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Analyze with Gemini AI',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: isDark
                                    ? Colors.white
                                    : Colors.indigo.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Get technical breakdowns, threat actor insights, and custom Q&A.',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark
                                    ? Colors.grey.shade400
                                    : Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward_ios,
                        size: 14,
                        color: isDark ? Colors.cyanAccent : Colors.indigo,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tags Section
            if (widget.attack.tags.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'Identified Tags',
                Icons.local_offer_outlined,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: widget.attack.tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    labelStyle: const TextStyle(fontSize: 12),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: isDark
                        ? const Color(0xFF1F2336)
                        : Colors.grey.shade100,
                    side: BorderSide(
                      color: isDark
                          ? Colors.blueGrey.shade800
                          : Colors.grey.shade300,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Source Attribution
            _buildSectionHeader(
              context,
              'Source Attribution',
              Icons.source_outlined,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              context,
              isDark: isDark,
              children: [
                _buildDetailsRow(
                  'Provider / Source',
                  widget.attack.source.name,
                ),
                _buildDetailsRow(
                  'Year Reported',
                  widget.attack.source.year.toString(),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Consumer<HistoricalProvider>(
          builder: (context, provider, _) {
            return _buildTourControlPanel(
              context,
              provider,
              _ttsService,
              _lgService,
              isDark,
              activeColor,
              geminiService,
            );
          },
        ),
      ),
    );
  }

  Widget _buildTourControlPanel(
    BuildContext context,
    HistoricalProvider provider,
    TextToSpeechService ttsService,
    LgService lgService,
    bool isDark,
    Color activeColor,
    GeminiService geminiService,
  ) {
    if (provider.isTourScriptLoading) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor: AlwaysStoppedAnimation<Color>(activeColor),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                provider.statusMessage,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (provider.isTourPlaying) {
      final currentStep = provider.tourSteps[provider.currentTourStepIndex];
      final totalSteps = provider.tourSteps.length;
      final narration = currentStep['narration'] ?? '';
      final title = currentStep['title'] ?? 'Tour Step';

      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0F172A) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          border: Border.all(
            color: isDark ? const Color(0xFF1F294D) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 15,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: totalSteps == 0
                    ? 0.0
                    : (provider.currentTourStepIndex + 1) / totalSteps,
                backgroundColor: isDark
                    ? Colors.blueGrey.shade900
                    : Colors.grey.shade200,
                valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '3D GEOGRAPHIC TOUR',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: activeColor,
                    letterSpacing: 0.5,
                  ),
                ),
                Text(
                  'Step ${provider.currentTourStepIndex + 1} of $totalSteps',
                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            const SizedBox(height: 8),
            // Narration Subtitle
            Container(
              padding: const EdgeInsets.all(12),
              constraints: const BoxConstraints(maxHeight: 70),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF141A35) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1F294D)
                      : Colors.grey.shade100,
                ),
              ),
              child: SingleChildScrollView(
                child: Text(
                  narration,
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.4,
                    color: isDark ? Colors.grey.shade300 : Colors.black87,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            // Playback buttons row
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.skip_previous_rounded, size: 24),
                  color: isDark ? Colors.white70 : Colors.black87,
                  onPressed: provider.currentTourStepIndex == 0
                      ? null
                      : () => provider.previousStep(ttsService, lgService),
                ),
                const SizedBox(width: 16),
                CircleAvatar(
                  radius: 24,
                  backgroundColor: activeColor,
                  child: IconButton(
                    icon: Icon(
                      provider.isTourPaused
                          ? Icons.play_arrow_rounded
                          : Icons.pause_rounded,
                      size: 28,
                      color: isDark ? Colors.black : Colors.white,
                    ),
                    onPressed: () {
                      if (provider.isTourPaused) {
                        provider.resumeTour(ttsService, lgService);
                      } else {
                        provider.pauseTour(ttsService);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 16),
                IconButton(
                  icon: Icon(
                    provider.currentTourStepIndex == totalSteps - 1
                        ? Icons.check_rounded
                        : Icons.skip_next_rounded,
                    size: 24,
                  ),
                  color: isDark ? Colors.white70 : Colors.black87,
                  onPressed: () => provider.nextStep(ttsService, lgService),
                ),
                const SizedBox(width: 24),
                IconButton.filled(
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.redAccent.withOpacity(0.15),
                    foregroundColor: Colors.redAccent,
                  ),
                  icon: const Icon(Icons.stop_rounded, size: 20),
                  onPressed: () => provider.stopTour(ttsService, lgService),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (provider.isVisualized) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1124) : Colors.white,
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(20),
            topRight: Radius.circular(20),
          ),
          border: Border.all(
            color: isDark ? const Color(0xFF1F294D) : Colors.grey.shade200,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeColor,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  minimumSize: const Size.fromHeight(46),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text(
                  'START TOUR',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                onPressed: () => provider.startTour(ttsService, lgService),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.redAccent,
                side: const BorderSide(color: Colors.redAccent),
                minimumSize: const Size(120, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.clear),
              label: const Text('CLEAR'),
              onPressed: () {
                provider.clearTourState();
                lgService.cleanKML();
              },
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: Theme.of(context).colorScheme.primary,
          foregroundColor: Theme.of(context).colorScheme.onPrimary,
          elevation: 4,
          shadowColor: Theme.of(context).colorScheme.primary.withOpacity(0.4),
          minimumSize: const Size.fromHeight(50),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.language_rounded),
        label: const Text(
          'VISUALIZE ON GLOBE',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
        ),
        onPressed: () async {
          await provider.generateSingleAttackTour(
            widget.attack,
            geminiService,
            lgService,
          );
          if (provider.tourError != null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Failed to generate tour: ${provider.tourError}'),
                backgroundColor: Colors.red.shade800,
              ),
            );
          }
        },
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? Colors.cyanAccent
        : Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Icon(icon, size: 20, color: primaryColor),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161925) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.blueGrey.shade900.withOpacity(0.5)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
