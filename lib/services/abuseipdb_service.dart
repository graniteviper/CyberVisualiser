import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/abuse_report_model.dart';
import '../utils/config.dart';

class AbuseIpDbService {
  /// Queries AbuseIPDB v2 check API endpoint for a given IP address.
  /// verbose flag is enabled to retrieve detailed reports listing comments.
  Future<AbuseIpReport> fetchIpReport({
    required String ipAddress,
    required int maxAgeInDays,
  }) async {
    final apiKey = AppConfig.abuseIpDbApiKey;
    if (apiKey.isEmpty) {
      throw Exception(
        'AbuseIPDB API Key is not loaded. Please verify .env configuration.',
      );
    }

    final uri = Uri.parse(
      'https://api.abuseipdb.com/api/v2/check?ipAddress=$ipAddress&maxAgeInDays=$maxAgeInDays&verbose=true',
    );

    final response = await http
        .get(uri, headers: {'Key': apiKey, 'Accept': 'application/json'})
        .timeout(const Duration(seconds: 15));

    if (response.statusCode != 200) {
      try {
        final decodedError = json.decode(response.body);
        if (decodedError['errors'] != null &&
            decodedError['errors'] is List &&
            decodedError['errors'].isNotEmpty) {
          final errorMsg =
              decodedError['errors'][0]['detail'] ??
              'AbuseIPDB request failed.';
          throw Exception(errorMsg);
        }
      } catch (_) {
        // Fallback if parsing error response fails
      }
      throw Exception(
        'AbuseIPDB API returned HTTP Status Code ${response.statusCode}',
      );
    }

    final decoded = json.decode(response.body);
    if (decoded['data'] == null) {
      throw Exception('Malformed response received from AbuseIPDB API.');
    }

    return AbuseIpReport.fromJson(decoded['data'] as Map<String, dynamic>);
  }
}
