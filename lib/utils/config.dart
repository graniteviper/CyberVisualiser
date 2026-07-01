import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

class AppConfig {
  static const String mcpEndpoint = 'https://mcp.honeylabs.net/mcp';
  static const Duration pollInterval = Duration(minutes: 1);

  static String envApiKey = '';
  static String envAbuseIpDbApiKey = '';
  static String envGeminiApiKey = '';

  static String userApiKey = '';
  static String userAbuseIpDbApiKey = '';
  static String userGeminiApiKey = '';

  static String get apiKey => userApiKey.isNotEmpty ? userApiKey : envApiKey;
  static String get abuseIpDbApiKey =>
      userAbuseIpDbApiKey.isNotEmpty ? userAbuseIpDbApiKey : envAbuseIpDbApiKey;
  static String get geminiApiKey =>
      userGeminiApiKey.isNotEmpty ? userGeminiApiKey : envGeminiApiKey;

  static const String _keyUserHoneyLabsApiKey = 'user_honeylabs_api_key';
  static const String _keyUserAbuseIpDbApiKey = 'user_abuseipdb_api_key';
  static const String _keyUserGeminiApiKey = 'user_gemini_api_key';

  /// Loads configuration values from the .env asset file and SharedPreferences
  static Future<void> loadConfig() async {
    try {
      final envContent = await rootBundle.loadString('.env');
      final lines = envContent.split('\n');
      for (var line in lines) {
        final trimmed = line.trim();
        if (trimmed.startsWith('HONEYLAB_API_KEY')) {
          final parts = trimmed.split('=');
          if (parts.length >= 2) {
            envApiKey = parts.sublist(1).join('=').trim();
          }
        } else if (trimmed.startsWith('ABUSEIPDB_API_KEY')) {
          final parts = trimmed.split('=');
          if (parts.length >= 2) {
            envAbuseIpDbApiKey = parts.sublist(1).join('=').trim();
          }
        } else if (trimmed.startsWith('GEMINI_API_KEY')) {
          final parts = trimmed.split('=');
          if (parts.length >= 2) {
            envGeminiApiKey = parts.sublist(1).join('=').trim();
          }
        }
      }
    } catch (e) {
      // Log error, fallback remains empty
      print('HoneyVision Config Error: Failed to load .env file: $e');
    }

    try {
      final prefs = await SharedPreferences.getInstance();
      userApiKey = prefs.getString(_keyUserHoneyLabsApiKey) ?? '';
      userAbuseIpDbApiKey = prefs.getString(_keyUserAbuseIpDbApiKey) ?? '';
      userGeminiApiKey = prefs.getString(_keyUserGeminiApiKey) ?? '';
    } catch (e) {
      print('HoneyVision Config Error: Failed to load user API keys: $e');
    }
  }

  /// Saves custom user API keys to SharedPreferences
  static Future<void> saveUserKeys(
    String honeyLabsKey,
    String abuseIpDbKey,
    String geminiKey,
  ) async {
    userApiKey = honeyLabsKey.trim();
    userAbuseIpDbApiKey = abuseIpDbKey.trim();
    userGeminiApiKey = geminiKey.trim();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUserHoneyLabsApiKey, userApiKey);
      await prefs.setString(_keyUserAbuseIpDbApiKey, userAbuseIpDbApiKey);
      await prefs.setString(_keyUserGeminiApiKey, userGeminiApiKey);
    } catch (e) {
      print('HoneyVision Config Error: Failed to save user API keys: $e');
    }
  }
}
