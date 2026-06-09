import 'package:flutter/services.dart' show rootBundle;

class AppConfig {
  static const String mcpEndpoint = 'https://mcp.honeylabs.net/mcp';
  static const Duration pollInterval = Duration(minutes: 1);

  static String apiKey = '';

  /// Loads configuration values from the .env asset file
  static Future<void> loadConfig() async {
    try {
      final envContent = await rootBundle.loadString('.env');
      final lines = envContent.split('\n');
      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('HONEYLAB_API_KEY')) {
          final parts = trimmed.split('=');
          if (parts.length >= 2) {
            apiKey = parts.sublist(1).join('=').trim();
            break;
          }
        }
      }
    } catch (e) {
      // Log error, fallback remains empty
      print('HoneyVision Config Error: Failed to load .env file: $e');
    }
  }
}
