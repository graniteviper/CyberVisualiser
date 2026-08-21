import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/attack_event.dart';
import '../providers/attack_provider.dart';
import '../services/gemini_service.dart';
import '../services/lg_service.dart';
import '../services/lg_adapter.dart';
import '../services/text_to_speech_service.dart';

class EventDetailsPanel extends StatefulWidget {
  final AttackEvent event;
  final LgAdapter lgAdapter;
  final bool isLgConnected;
  final Function(AttackEvent) onVisualize;

  const EventDetailsPanel({
    super.key,
    required this.event,
    required this.lgAdapter,
    required this.isLgConnected,
    required this.onVisualize,
  });

  @override
  State<EventDetailsPanel> createState() => _EventDetailsPanelState();
}

class _EventDetailsPanelState extends State<EventDetailsPanel> {
  late final TextToSpeechService _ttsService;
  late final LgService _lgService;
  late final AttackProvider _provider;

  @override
  void initState() {
    super.initState();
    _ttsService = Provider.of<TextToSpeechService>(context, listen: false);
    _lgService = Provider.of<LgService>(context, listen: false);
    _provider = Provider.of<AttackProvider>(context, listen: false);
  }

  @override
  void dispose() {
    // Clear and stop tour playback on dialog close
    _provider.stopTour(_ttsService, _lgService);
    _provider.clearTourState();
    super.dispose();
  }

  Color _getSeverityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
        return Colors.redAccent.shade400;
      case 'high':
        return Colors.orangeAccent;
      default:
        return Colors.yellowAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sevColor = _getSeverityColor(widget.event.severity);
    final geminiService = Provider.of<GeminiService>(context, listen: false);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F111A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: sevColor.withOpacity(0.5), width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 550),
        padding: const EdgeInsets.all(20),
        child: Consumer<AttackProvider>(
          builder: (context, provider, _) {
            return Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.shield_outlined, color: sevColor, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          'ATTACK TELEMETRY',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: isDark
                                ? Colors.blue.shade200
                                : Colors.indigo.shade900,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Content scroll area (hidden or squished if tour is playing to give space)
                if (!provider.isTourPlaying)
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSectionHeader('EVENT METRIC'),
                          _buildInfoRow(
                            'Event ID',
                            widget.event.eventId,
                            isMonospace: true,
                          ),
                          _buildInfoRow(
                            'Timestamp (UTC)',
                            widget.event.timestamp.toIso8601String(),
                          ),
                          _buildInfoRow(
                            'Severity',
                            widget.event.severity,
                            valueColor: sevColor,
                            isBold: true,
                          ),

                          _buildSectionHeader('SOURCE INFO'),
                          _buildInfoRow(
                            'Source IP',
                            widget.event.sourceIp,
                            isMonospace: true,
                          ),
                          _buildInfoRow(
                            'Source Port',
                            widget.event.sourcePort.toString(),
                          ),
                          if (widget.event.sourceDomain.isNotEmpty)
                            _buildInfoRow(
                              'Source Domain',
                              widget.event.sourceDomain,
                            ),
                          _buildInfoRow(
                            'Country',
                            '${widget.event.countryName} (${widget.event.countryCode})',
                          ),
                          if (widget.event.cityName.isNotEmpty)
                            _buildInfoRow('City Name', widget.event.cityName),
                          _buildInfoRow(
                            'ASN Profile',
                            'AS${widget.event.asnNumber} (${widget.event.asnOrg})',
                          ),

                          _buildSectionHeader('TARGET INFO'),
                          _buildInfoRow(
                            'Target Port',
                            widget.event.destPort.toString(),
                            isBold: true,
                          ),
                          if (widget.event.networkProtocol.isNotEmpty)
                            _buildInfoRow(
                              'Protocol',
                              widget.event.networkProtocol.toUpperCase(),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  // Large Tour playback presentation inside dialog
                  Flexible(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16.0),
                      child: _buildActiveTourLayout(provider, isDark, sevColor),
                    ),
                  ),

                const Divider(height: 24),

                // Action Buttons / Tour Controls
                _buildActionArea(provider, geminiService, sevColor, isDark),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActiveTourLayout(
    AttackProvider provider,
    bool isDark,
    Color sevColor,
  ) {
    final currentStep = provider.tourSteps[provider.currentTourStepIndex];
    final totalSteps = provider.tourSteps.length;
    final narration = currentStep['narration'] ?? '';
    final title = currentStep['title'] ?? 'Tour Step';

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Progress Track
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: totalSteps == 0
                ? 0.0
                : (provider.currentTourStepIndex + 1) / totalSteps,
            backgroundColor: isDark
                ? Colors.blueGrey.shade900
                : Colors.grey.shade200,
            valueColor: AlwaysStoppedAnimation<Color>(sevColor),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '3D GEOGRAPHIC VOICE TOUR',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: sevColor,
                letterSpacing: 0.5,
              ),
            ),
            Text(
              'Step ${provider.currentTourStepIndex + 1} of $totalSteps',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          title,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.white : Colors.black87,
          ),
        ),
        const SizedBox(height: 12),
        // Narration Subtitle Box
        Container(
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(maxHeight: 120),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF141A35) : Colors.grey.shade50,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isDark ? const Color(0xFF1F294D) : Colors.grey.shade100,
            ),
          ),
          child: SingleChildScrollView(
            child: Text(
              narration,
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: isDark ? Colors.grey.shade300 : Colors.black87,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionArea(
    AttackProvider provider,
    GeminiService geminiService,
    Color sevColor,
    bool isDark,
  ) {
    if (provider.isTourScriptLoading) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF141A35) : Colors.grey.shade50,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                provider.statusMessage,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      );
    }

    if (provider.isTourPlaying) {
      final totalSteps = provider.tourSteps.length;
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: const Icon(Icons.skip_previous_rounded, size: 28),
            onPressed: provider.currentTourStepIndex == 0
                ? null
                : () => provider.previousStep(_ttsService, _lgService),
          ),
          const SizedBox(width: 16),
          CircleAvatar(
            radius: 24,
            backgroundColor: sevColor,
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
                  provider.resumeTour(_ttsService, _lgService);
                } else {
                  provider.pauseTour(_ttsService);
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
              size: 28,
            ),
            onPressed: () => provider.nextStep(_ttsService, _lgService),
          ),
          const SizedBox(width: 24),
          IconButton.filled(
            style: IconButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.15),
              foregroundColor: Colors.redAccent,
            ),
            icon: const Icon(Icons.stop_rounded),
            onPressed: () => provider.stopTour(_ttsService, _lgService),
          ),
        ],
      );
    }

    if (provider.isVisualized) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: sevColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
                minimumSize: const Size.fromHeight(46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text(
                'START 3D TOUR',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              onPressed: () => provider.startTour(_ttsService, _lgService),
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
              _lgService.cleanKML();
            },
          ),
        ],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.send_rounded, size: 16),
                label: const Text('VISUALIZE ON LG'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isLgConnected
                      ? sevColor
                      : Colors.grey,
                  foregroundColor: widget.isLgConnected
                      ? Colors.black
                      : Colors.white,
                  minimumSize: const Size.fromHeight(45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: widget.isLgConnected
                    ? () {
                        widget.onVisualize(widget.event);
                      }
                    : null,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                icon: const Icon(Icons.auto_awesome, size: 16),
                label: const Text('GENERATE 3D TOUR'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: widget.isLgConnected
                      ? Colors.cyanAccent.shade700
                      : Colors.grey,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(45),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: widget.isLgConnected
                    ? () {
                        provider.generateSingleAttackTour(
                          event: widget.event,
                          geminiService: geminiService,
                          lgService: _lgService,
                          adapter: widget.lgAdapter,
                        );
                      }
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInfoRow(
    String label,
    String value, {
    Color? valueColor,
    bool isMonospace = false,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: isMonospace ? 'monospace' : null,
                fontWeight: isBold ? FontWeight.bold : null,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
