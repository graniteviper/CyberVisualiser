import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../models/attack_event.dart';
import '../services/gemini_service.dart';
import '../services/gemini_analysis_helper.dart';

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

class _GeminiSummaryDialogState extends State<GeminiSummaryDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  String? _summaryText;

  @override
  void initState() {
    super.initState();
    _fetchSummary();
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
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accentColor = isDark ? Colors.cyanAccent : Colors.indigo;

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
        child: Column(
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
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            // Content Area
            Flexible(child: _buildContent(context, isDark, accentColor)),

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
              ],
            ),
          ],
        ),
      ),
    );
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
