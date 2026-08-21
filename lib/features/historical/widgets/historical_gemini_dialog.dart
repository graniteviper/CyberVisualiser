import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:provider/provider.dart';
import '../../../services/gemini_service.dart';
import '../../../services/text_to_speech_service.dart';
import '../../../templates/gemini_prompt_template.dart';
import '../models/historical_attack.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final DateTime timestamp;

  ChatMessage({
    required this.text,
    required this.isUser,
    required this.timestamp,
  });
}

class HistoricalGeminiDialog extends StatefulWidget {
  final HistoricalAttack? attack;
  final int? year;
  final String? category;
  final List<HistoricalAttack> contextAttacks;

  const HistoricalGeminiDialog({
    super.key,
    this.attack,
    this.year,
    this.category,
    required this.contextAttacks,
  });

  @override
  State<HistoricalGeminiDialog> createState() => _HistoricalGeminiDialogState();
}

class _HistoricalGeminiDialogState extends State<HistoricalGeminiDialog> {
  final List<ChatMessage> _messages = [];
  final TextEditingController _inputController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;
  late GeminiService _geminiService;
  TextToSpeechService? _ttsService;

  @override
  void initState() {
    super.initState();
    _geminiService = context.read<GeminiService>();
    _ttsService = Provider.of<TextToSpeechService>(context, listen: false);
    _addInitialGreeting();
  }

  void _addInitialGreeting() {
    String greeting = "";
    if (widget.attack != null) {
      greeting =
          "Hello! I am your Cyber Threat Intelligence assistant. I have loaded details about the attack **\"${widget.attack!.title}\"**.\n\nYou can ask me about its technical breakdown, the threat actors involved, mitigation steps, or any other details you'd like to explore!";
    } else {
      String scope = "";
      if (widget.year != null && widget.category != null) {
        scope =
            "attacks from the year **${widget.year}** categorized as **${widget.category}**";
      } else if (widget.year != null) {
        scope = "attacks from the year **${widget.year}**";
      } else if (widget.category != null) {
        scope = "attacks categorized as **${widget.category}**";
      } else {
        scope = "historical cyber attacks";
      }
      greeting =
          "Hello! I am your Cyber Threat Intelligence assistant. I have loaded context from our database containing **${widget.contextAttacks.length}** matching $scope.\n\nHow can I help you analyze this database subset? You can ask about general threat landscape summaries, common vectors, or defense recommendations!";
    }
    _messages.add(
      ChatMessage(text: greeting, isUser: false, timestamp: DateTime.now()),
    );
  }

  @override
  void dispose() {
    _inputController.dispose();
    _scrollController.dispose();
    _ttsService?.stop();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage(String text) async {
    if (text.trim().isEmpty) return;

    setState(() {
      _messages.add(
        ChatMessage(text: text, isUser: true, timestamp: DateTime.now()),
      );
      _isLoading = true;
    });
    _inputController.clear();
    _scrollToBottom();

    try {
      String prompt = "";
      if (widget.attack != null) {
        prompt = GeminiPromptTemplate.fillHistoricalAttackPrompt(
          widget.attack!,
          text,
        );
      } else {
        prompt = GeminiPromptTemplate.fillHistoricalContextPrompt(
          year: widget.year,
          category: widget.category,
          contextAttacks: widget.contextAttacks.take(15).toList(),
          userQuestion: text,
        );
      }

      final response = await _geminiService.generateThreatSummary(prompt);

      if (mounted) {
        setState(() {
          _messages.add(
            ChatMessage(
              text: response,
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        final error = e.toString().replaceAll('Exception: ', '');
        setState(() {
          _messages.add(
            ChatMessage(
              text:
                  "Sorry, I encountered an error generating details:\n\n*$error*",
              isUser: false,
              timestamp: DateTime.now(),
            ),
          );
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gemini Assistant Error: $error'),
            backgroundColor: Colors.red.shade800,
          ),
        );
        _scrollToBottom();
      }
    }
  }

  List<String> _getSuggestionChips() {
    if (widget.attack != null) {
      return [
        "Technical Breakdown",
        "Threat Actor Profile",
        "Mitigation Guide",
      ];
    } else {
      return [
        "Landscape Summary",
        "Common Attack Vectors",
        "Defense Recommendations",
      ];
    }
  }

  String _getPromptForChip(String chipText) {
    if (widget.attack != null) {
      switch (chipText) {
        case "Technical Breakdown":
          return "Provide a detailed technical breakdown of this attack, how it likely worked, and the vulnerability targeted.";
        case "Threat Actor Profile":
          return "What threat group or type of attacker was likely behind this, and what are their typical motives and TTPs?";
        case "Mitigation Guide":
          return "What specific security controls and mitigation measures would prevent or detect such an attack?";
        default:
          return chipText;
      }
    } else {
      switch (chipText) {
        case "Landscape Summary":
          return "Summarize the cyber threat landscape for these incidents, including main trends and impacts.";
        case "Common Attack Vectors":
          return "What were the most common attack vectors and targets observed in these incidents?";
        case "Defense Recommendations":
          return "Provide global cybersecurity defense recommendations to protect organizations from these types of threats.";
        default:
          return chipText;
      }
    }
  }

  String _getScopeTitle() {
    if (widget.attack != null) {
      return "Incident: ${widget.attack!.title}";
    }
    List<String> parts = [];
    if (widget.year != null) parts.add("Year: ${widget.year}");
    if (widget.category != null) parts.add("Category: ${widget.category}");
    if (parts.isEmpty) parts.add("Historical Context");
    return parts.join(" | ");
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
        side: BorderSide(color: accentColor.withOpacity(0.4), width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.95,
        height: MediaQuery.of(context).size.height * 0.8,
        constraints: const BoxConstraints(maxWidth: 650),
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Header Row
            Row(
              children: [
                Icon(Icons.psychology, color: accentColor, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'GEMINI HISTORICAL INTEL',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.2,
                          color: isDark ? Colors.white : Colors.indigo.shade900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getScopeTitle(),
                        style: TextStyle(
                          fontSize: 11,
                          color: isDark ? Colors.cyanAccent : Colors.indigo,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  onPressed: () {
                    _ttsService?.stop();
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const Divider(height: 16),

            // Message History Thread
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  return _buildMessageBubble(
                    msg,
                    theme,
                    isDark,
                    accentColor,
                    index,
                  );
                },
              ),
            ),

            if (_isLoading) ...[
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(left: 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF161925)
                            : Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isDark
                              ? Colors.blueGrey.shade900
                              : Colors.grey.shade300,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Consulting Gemini models...',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),

            // Predefined Quick Suggestions Bar
            if (!_isLoading) ...[
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: _getSuggestionChips().map((chip) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4.0),
                      child: ActionChip(
                        label: Text(
                          chip,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.cyanAccent
                                : Colors.indigo.shade800,
                          ),
                        ),
                        backgroundColor: isDark
                            ? Colors.cyan.withOpacity(0.08)
                            : Colors.indigo.withOpacity(0.05),
                        side: BorderSide(
                          color: isDark
                              ? Colors.cyanAccent.withOpacity(0.3)
                              : Colors.indigo.withOpacity(0.2),
                        ),
                        onPressed: () => _sendMessage(_getPromptForChip(chip)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
            ],

            // Input Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161925) : Colors.grey.shade100,
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark
                      ? Colors.blueGrey.shade900
                      : Colors.grey.shade300,
                ),
              ),
              child: Row(
                children: [
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _inputController,
                      style: const TextStyle(fontSize: 13),
                      decoration: const InputDecoration(
                        hintText: 'Ask Gemini about these attacks...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      onSubmitted: _sendMessage,
                    ),
                  ),
                  ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _inputController,
                    builder: (context, value, child) {
                      final hasText = value.text.trim().isNotEmpty;
                      return IconButton(
                        icon: Icon(
                          Icons.send_rounded,
                          color: hasText ? accentColor : Colors.grey,
                          size: 20,
                        ),
                        onPressed: hasText
                            ? () => _sendMessage(_inputController.text)
                            : null,
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBubble(
    ChatMessage msg,
    ThemeData theme,
    bool isDark,
    Color accentColor,
    int index,
  ) {
    final isUser = msg.isUser;
    final alignment = isUser
        ? CrossAxisAlignment.end
        : CrossAxisAlignment.start;
    final bubbleColor = isUser
        ? (isDark ? const Color(0xFF263238) : Colors.indigo.shade50)
        : (isDark ? const Color(0xFF161925) : Colors.grey.shade50);

    final border = isUser
        ? BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: const Radius.circular(16),
            bottomRight: Radius.circular(index == 0 ? 16 : 4),
          )
        : BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(index == 0 ? 16 : 4),
            bottomRight: const Radius.circular(16),
          );

    final baseStyleSheet = MarkdownStyleSheet.fromTheme(theme);
    final mdStyle = baseStyleSheet.copyWith(
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
      h1Padding: const EdgeInsets.only(top: 10.0, bottom: 4.0),
      h2Padding: const EdgeInsets.only(top: 8.0, bottom: 2.0),
      listIndent: 16.0,
    );

    final utteranceId = msg.timestamp.toIso8601String();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Column(
        crossAxisAlignment: alignment,
        children: [
          Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!isUser) ...[
                CircleAvatar(
                  radius: 12,
                  backgroundColor: accentColor.withOpacity(0.2),
                  child: Icon(Icons.psychology, size: 14, color: accentColor),
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: bubbleColor,
                    borderRadius: border,
                    border: Border.all(
                      color: isUser
                          ? (isDark
                                ? Colors.cyan.withOpacity(0.3)
                                : Colors.indigo.shade100)
                          : (isDark
                                ? Colors.blueGrey.shade900
                                : Colors.grey.shade200),
                    ),
                  ),
                  child: isUser
                      ? Text(
                          msg.text,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        )
                      : MarkdownBody(
                          data: msg.text,
                          selectable: true,
                          styleSheet: mdStyle,
                        ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                CircleAvatar(
                  radius: 12,
                  backgroundColor: Colors.grey.shade400.withOpacity(0.2),
                  child: Icon(
                    Icons.person,
                    size: 14,
                    color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                  ),
                ),
              ],
            ],
          ),
          if (!isUser) ...[
            Padding(
              padding: const EdgeInsets.only(left: 32.0, top: 2.0),
              child: Consumer<TextToSpeechService>(
                builder: (context, tts, _) {
                  final isThisSpeaking =
                      tts.isSpeaking && tts.currentUtterance == utteranceId;
                  return InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      if (isThisSpeaking) {
                        tts.stop();
                      } else {
                        tts.speak(msg.text, utteranceId: utteranceId);
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8.0,
                        vertical: 4.0,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isThisSpeaking
                                ? Icons.stop_circle_outlined
                                : Icons.volume_up_outlined,
                            size: 14,
                            color: isThisSpeaking
                                ? Colors.redAccent
                                : accentColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            isThisSpeaking ? 'Stop Speaking' : 'Read Aloud',
                            style: TextStyle(
                              fontSize: 10,
                              color: isThisSpeaking
                                  ? Colors.redAccent
                                  : Colors.grey,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
