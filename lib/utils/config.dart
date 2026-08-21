import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppConfig {
  static const String mcpEndpoint = 'https://mcp.honeylabs.net/mcp';
  static const Duration pollInterval = Duration(minutes: 1);

  static String envApiKey = '';
  static String envAbuseIpDbApiKey = '';
  static String envGeminiApiKey = '';

  static String userApiKey = '';
  static String userAbuseIpDbApiKey = '';
  static String userGeminiApiKey = '';

  static String get apiKey => userApiKey;
  static String get abuseIpDbApiKey => userAbuseIpDbApiKey;
  static String get geminiApiKey => userGeminiApiKey;

  static const String _keyUserHoneyLabsApiKey = 'user_honeylabs_api_key';
  static const String _keyUserAbuseIpDbApiKey = 'user_abuseipdb_api_key';
  static const String _keyUserGeminiApiKey = 'user_gemini_api_key';

  static const _secureStorage = FlutterSecureStorage();

  /// Loads configuration values from the .env asset file and FlutterSecureStorage
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
      print('cyber visualiser Config Error: Failed to load .env file: $e');
    }

    try {
      userApiKey =
          await _secureStorage.read(key: _keyUserHoneyLabsApiKey) ?? '';
      userAbuseIpDbApiKey =
          await _secureStorage.read(key: _keyUserAbuseIpDbApiKey) ?? '';
      userGeminiApiKey =
          await _secureStorage.read(key: _keyUserGeminiApiKey) ?? '';
    } catch (e) {
      print('cyber visualiser Config Error: Failed to load user API keys: $e');
    }
  }

  /// Saves custom user API keys to FlutterSecureStorage
  static Future<void> saveUserKeys(
    String honeyLabsKey,
    String abuseIpDbKey,
    String geminiKey,
  ) async {
    userApiKey = honeyLabsKey.trim();
    userAbuseIpDbApiKey = abuseIpDbKey.trim();
    userGeminiApiKey = geminiKey.trim();

    try {
      await _secureStorage.write(
        key: _keyUserHoneyLabsApiKey,
        value: userApiKey,
      );
      await _secureStorage.write(
        key: _keyUserAbuseIpDbApiKey,
        value: userAbuseIpDbApiKey,
      );
      await _secureStorage.write(
        key: _keyUserGeminiApiKey,
        value: userGeminiApiKey,
      );
    } catch (e) {
      print('cyber visualiser Config Error: Failed to save user API keys: $e');
    }
  }
}
