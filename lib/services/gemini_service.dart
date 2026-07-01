import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/config.dart';

class GeminiService {
  /// Calls Gemini API to generate a threat analysis report
  Future<String> generateThreatSummary(String prompt) async {
    final apiKey = AppConfig.geminiApiKey;
    if (apiKey.isEmpty) {
      throw Exception(
        'Gemini API Key is not configured. Please add it in Connection Settings.',
      );
    }

    final url = Uri.parse(
      'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=$apiKey',
    );

    final response = await http
        .post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'contents': [
              {
                'parts': [
                  {'text': prompt},
                ],
              },
            ],
          }),
        )
        .timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception(
        'Gemini API returned status code ${response.statusCode}: ${response.body}',
      );
    }

    final decoded = json.decode(response.body);
    try {
      final candidates = decoded['candidates'] as List;
      if (candidates.isEmpty) {
        throw Exception('No analysis returned from Gemini.');
      }
      final content = candidates[0]['content'];
      final parts = content['parts'] as List;
      if (parts.isEmpty) {
        throw Exception('Empty content returned from Gemini.');
      }
      return parts[0]['text'] ?? 'No text returned.';
    } catch (e) {
      throw Exception('Failed to parse Gemini response: $e');
    }
  }
}
