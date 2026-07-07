import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

class TextToSpeechService extends ChangeNotifier {
  final FlutterTts _flutterTts = FlutterTts();
  bool _isSpeaking = false;

  bool get isSpeaking => _isSpeaking;

  TextToSpeechService() {
    _initTts();
  }

  void _initTts() {
    _flutterTts.setStartHandler(() {
      _isSpeaking = true;
      notifyListeners();
    });

    _flutterTts.setCompletionHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });

    _flutterTts.setCancelHandler(() {
      _isSpeaking = false;
      notifyListeners();
    });

    _flutterTts.setErrorHandler((msg) {
      _isSpeaking = false;
      notifyListeners();
    });
  }

  Future<void> speak(String text) async {
    // Clean text by stripping markdown symbols to make speech sound natural
    final cleanText = text
        .replaceAll(RegExp(r'[\*#_`~>]'), '') // remove markdown symbols
        .replaceAll(RegExp(r'\[.*?\]\(.*?\)'), '') // remove links
        .trim();

    if (cleanText.isEmpty) return;

    await _flutterTts.stop(); // Stop any current speech before starting new
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.55);
    await _flutterTts.speak(cleanText);
  }

  Future<void> stop() async {
    await _flutterTts.stop();
    _isSpeaking = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _flutterTts.stop();
    super.dispose();
  }
}
