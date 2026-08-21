import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../models/attack_event.dart';
import '../providers/attack_provider.dart';
import '../services/gemini_service.dart';
import '../services/gemini_analysis_helper.dart';
import '../services/lg_service.dart';
import '../services/lg_adapter.dart';
import '../services/text_to_speech_service.dart';

class GeminiSummaryDialog extends StatefulWidget {
  final String category;
  final List<AttackEvent> events;
  final GeminiService geminiService;

  const GeminiSummaryDialog({
    super.key,
    required this.category,
    required this.events,
    required this.geminiService,
  });

  @override
  State<GeminiSummaryDialog> createState() => _GeminiSummaryDialogState();
}

class _ScrollBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    return child;
  }
}

class _GeminiSummaryDialogState extends State<GeminiSummaryDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _summaryText;
  TextToSpeechService? _ttsService;

  @override
  void initState() {
    super.initState();
    _ttsService = Provider.of<TextToSpeechService>(context, listen: false);
    _fetchSummary();
  }

  @override
  void dispose() {
    _ttsService?.stop();
    // Stop tour playback on exit
    final provider = Provider.of<AttackProvider>(context, listen: false);
    final lgService = Provider.of<LgService>(context, listen: false);
    provider.stopTour(_ttsService!, lgService);
    provider.clearTourState();
    super.dispose();
  }

  Future<void> _fetchSummary() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final summary = await fetchCategoryThreatSummary(
        geminiService: widget.geminiService,
        category: widget.category,
        events: widget.events,
      );
      if (mounted) {
        setState(() {
          _summaryText = summary;
          _isLoading = false;
        });

        // Query LgService to send insights overlay popup to rightmost screen
        final lgService = context.read<LgService>();
        if (lgService.isConnected) {
          lgService
              .sendCategoryInsightsOverlay(
                category: widget.category,
                markdownText: summary,
              )
              .catchError((e) {
                debugPrint(
                  'Failed to send category insights overlay to LG: $e',
                );
              });
        }
      }
    } catch (e) {
      if (mounted) {
        final error = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _errorMessage = error;
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gemini Summary Error: $error'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? Colors.cyanAccent : Colors.indigo;
    final lgService = Provider.of<LgService>(context, listen: false);
    final lgAdapter = Provider.of<LgAdapter>(context, listen: false);

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F111A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: accentColor.withOpacity(0.5), width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 600),
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
                        Icon(Icons.psychology, color: accentColor, size: 26),
                        const SizedBox(width: 8),
                        Text(
                          'GEMINI INSIGHTS',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.0,
                            color: isDark
                                ? Colors.cyanAccent
                                : Colors.indigo.shade900,
                          ),
                        ),
                      ],
                    ),
                    Row(
                      children: [
                        if (_summaryText != null && !provider.isTourPlaying)
                          IconButton(
                            icon: Icon(
                              _ttsService?.isSpeaking == true &&
                                      _ttsService?.currentUtterance ==
                                          widget.category
                                  ? Icons.volume_up_rounded
                                  : Icons.volume_mute_rounded,
                              color: accentColor,
                            ),
                            tooltip:
                                _ttsService?.isSpeaking == true &&
                                    _ttsService?.currentUtterance ==
                                        widget.category
                                ? 'Stop Speaking'
                                : 'Listen to Report',
                            onPressed: () {
                              setState(() {
                                if (_ttsService?.isSpeaking == true &&
                                    _ttsService?.currentUtterance ==
                                        widget.category) {
                                  _ttsService?.stop();
                                } else {
                                  _ttsService?.speak(
                                    _summaryText!,
                                    utteranceId: widget.category,
                                  );
                                }
                              });
                            },
                          ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                  ],
                ),
                const Divider(height: 20),

                // Content Area
                Flexible(
                  child: ScrollConfiguration(
                    behavior: _ScrollBehavior(),
                    child: _buildContent(context, isDark, accentColor),
                  ),
                ),

                // 3D Tour Overlay controls inside dialog
                if (provider.isTourScriptLoading ||
                    provider.isTourPlaying ||
                    provider.isVisualized) ...[
                  const Divider(height: 20),
                  _buildTourPlaybackPanel(
                    provider,
                    accentColor,
                    isDark,
                    lgService,
                  ),
                ],

                const Divider(height: 24),

                // Footer / Action Row
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Close'),
                    ),
                    if (_errorMessage != null) ...[
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: _fetchSummary,
                        icon: const Icon(Icons.refresh, size: 16),
                        label: const Text('Retry'),
                      ),
                    ],
                    if (_summaryText != null &&
                        !provider.isTourScriptLoading &&
                        !provider.isTourPlaying &&
                        !provider.isVisualized &&
                        lgService.isConnected) ...[
                      const SizedBox(width: 12),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accentColor,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                        ),
                        onPressed: () {
                          provider.generateCategoryTour(
                            categoryName: widget.category,
                            events: widget.events,
                            geminiService: widget.geminiService,
                            lgService: lgService,
                            adapter: lgAdapter,
                          );
                        },
                        icon: const Icon(Icons.explore_rounded, size: 16),
                        label: const Text('GENERATE 3D TOUR'),
                      ),
                    ],
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildTourPlaybackPanel(
    AttackProvider provider,
    Color accentColor,
    bool isDark,
    LgService lgService,
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
      final currentStep = provider.tourSteps[provider.currentTourStepIndex];
      final totalSteps = provider.tourSteps.length;
      final narration = currentStep['narration'] ?? '';
      final title = currentStep['title'] ?? 'Tour Step';

      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: totalSteps == 0
                  ? 0.0
                  : (provider.currentTourStepIndex + 1) / totalSteps,
              backgroundColor: isDark
                  ? Colors.blueGrey.shade900
                  : Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(accentColor),
              minHeight: 3,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '3D CATEGORY VOICE TOUR',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                  color: accentColor,
                  letterSpacing: 0.5,
                ),
              ),
              Text(
                'Step ${provider.currentTourStepIndex + 1} of $totalSteps',
                style: const TextStyle(fontSize: 10, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            constraints: const BoxConstraints(maxHeight: 70),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF141A35) : Colors.grey.shade50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark ? const Color(0xFF1F294D) : Colors.grey.shade100,
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
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.skip_previous_rounded, size: 24),
                onPressed: provider.currentTourStepIndex == 0
                    ? null
                    : () => provider.previousStep(_ttsService!, lgService),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                radius: 20,
                backgroundColor: accentColor,
                child: IconButton(
                  icon: Icon(
                    provider.isTourPaused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    size: 24,
                    color: isDark ? Colors.black : Colors.white,
                  ),
                  onPressed: () {
                    if (provider.isTourPaused) {
                      provider.resumeTour(_ttsService!, lgService);
                    } else {
                      provider.pauseTour(_ttsService!);
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: Icon(
                  provider.currentTourStepIndex == totalSteps - 1
                      ? Icons.check_rounded
                      : Icons.skip_next_rounded,
                  size: 24,
                ),
                onPressed: () => provider.nextStep(_ttsService!, lgService),
              ),
              const SizedBox(width: 20),
              IconButton.filled(
                style: IconButton.styleFrom(
                  backgroundColor: Colors.redAccent.withOpacity(0.15),
                  foregroundColor: Colors.redAccent,
                  padding: const EdgeInsets.all(8),
                ),
                icon: const Icon(Icons.stop_rounded, size: 18),
                onPressed: () => provider.stopTour(_ttsService!, lgService),
              ),
            ],
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
                backgroundColor: accentColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
                minimumSize: const Size.fromHeight(40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              icon: const Icon(Icons.play_arrow_rounded, size: 20),
              label: const Text(
                'START TOUR',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
              ),
              onPressed: () => provider.startTour(_ttsService!, lgService),
            ),
          ),
          const SizedBox(width: 12),
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.redAccent,
              side: const BorderSide(color: Colors.redAccent),
              minimumSize: const Size(100, 40),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            icon: const Icon(Icons.clear, size: 16),
            label: const Text('CLEAR', style: TextStyle(fontSize: 12)),
            onPressed: () {
              provider.clearTourState();
              lgService.cleanKML();
            },
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildContent(BuildContext context, bool isDark, Color accentColor) {
    if (_isLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Analyzing category: ${widget.category}...',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Querying Gemini Threat Intelligence model...',
                style: TextStyle(color: Colors.grey, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.redAccent, size: 44),
            const SizedBox(height: 12),
            const Text(
              'Failed to generate analysis',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.redAccent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    if (_summaryText == null || _summaryText!.trim().isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24.0),
        child: Center(child: Text('No summary text was generated.')),
      );
    }

    final baseStyleSheet = MarkdownStyleSheet.fromTheme(Theme.of(context));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              'Category: ${widget.category.toUpperCase()} (${widget.events.length} Detections)',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: accentColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          MarkdownBody(
            data: _summaryText!,
            selectable: true,
            styleSheet: baseStyleSheet.copyWith(
              p: baseStyleSheet.p?.copyWith(
                color: isDark ? Colors.grey.shade300 : Colors.black87,
                fontSize: 13,
                height: 1.5,
              ),
              h1: baseStyleSheet.h1?.copyWith(
                color: isDark ? Colors.teal.shade200 : Colors.teal.shade800,
                fontSize: 15,
                fontWeight: FontWeight.bold,
              ),
              h2: baseStyleSheet.h2?.copyWith(
                color: isDark ? Colors.cyan.shade300 : Colors.indigo.shade800,
                fontSize: 14,
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
              h1Padding: const EdgeInsets.only(top: 14.0, bottom: 6.0),
              h2Padding: const EdgeInsets.only(top: 12.0, bottom: 4.0),
              listIndent: 16.0,
            ),
          ),
        ],
      ),
    );
  }
}
