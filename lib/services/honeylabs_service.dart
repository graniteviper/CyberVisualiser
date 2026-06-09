import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/config.dart';

class HoneyLabsService {
  /// Calls the HoneyLabs MCP endpoint using search_events_tool JSON-RPC method
  Future<List<Map<String, dynamic>>> fetchRawEvents({
    required DateTime since,
    required DateTime until,
    int limit = 100,
  }) async {
    final apiKey = AppConfig.apiKey;
    if (apiKey.isEmpty) {
      throw Exception('HoneyLabs API Key is not loaded. Please verify .env configuration.');
    }

    // Format timestamps as ISO-8601 UTC strings
    String formatUtc(DateTime dt) {
      final utc = dt.toUtc();
      return '${utc.toIso8601String().split('.')[0]}Z';
    }

    final sinceStr = formatUtc(since);
    final untilStr = formatUtc(until);

    final requestBody = json.encode({
      'jsonrpc': '2.0',
      'id': 1,
      'method': 'tools/call',
      'params': {
        'name': 'search_events_tool',
        'arguments': {
          'since': sinceStr,
          'until': untilStr,
          'limit': limit,
        }
      }
    });

    final response = await http.post(
      Uri.parse(AppConfig.mcpEndpoint),
      headers: {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json, text/event-stream',
      },
      body: requestBody,
    ).timeout(const Duration(seconds: 10));

    if (response.statusCode != 200) {
      throw Exception('HoneyLabs API returned HTTP Status Code ${response.statusCode}');
    }

    final body = response.body.trim();
    String dataJson = '';

    // Handle SSE (Server-Sent Events) formatting if present in the response
    final lines = body.split('\n');
    for (var line in lines) {
      if (line.startsWith('data: ')) {
        dataJson = line.substring(6).trim();
        break;
      } else if (line.startsWith('data:')) {
        dataJson = line.substring(5).trim();
        break;
      }
    }

    if (dataJson.isEmpty) {
      dataJson = body;
    }

    final decoded = json.decode(dataJson);
    if (decoded['error'] != null) {
      final err = decoded['error'];
      throw Exception(err['message'] ?? 'JSON-RPC call failed.');
    }

    final resultObj = decoded['result'];
    if (resultObj == null) {
      return [];
    }

    List<dynamic> eventsRaw = [];
    if (resultObj['structuredContent'] != null &&
        resultObj['structuredContent']['result'] != null) {
      eventsRaw = resultObj['structuredContent']['result'];
    } else if (resultObj['content'] != null &&
        resultObj['content'] is List &&
        resultObj['content'].isNotEmpty) {
      final textContent = resultObj['content'][0]['text'];
      if (textContent != null && textContent is String) {
        eventsRaw = json.decode(textContent);
      }
    }

    // Log the data returned by honeylabs for 5 attacks
    final logLimit = eventsRaw.length < 5 ? eventsRaw.length : 5;
    print('--- LOGGING $logLimit HONEYLABS ATTACKS ---');
    for (int i = 0; i < logLimit; i++) {
      print('HoneyLabs Attack Event ${i + 1}: ${json.encode(eventsRaw[i])}');
    }
    print('--- END OF HONEYLABS ATTACK LOGS ---');

    return eventsRaw.map((e) => Map<String, dynamic>.from(e)).toList();
  }
}
