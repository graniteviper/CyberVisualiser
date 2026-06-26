import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cyber_visualiser/models/attack_event.dart';
import 'package:cyber_visualiser/services/honeylabs_service.dart';
import 'package:cyber_visualiser/repositories/attack_repository.dart';
import 'package:cyber_visualiser/utils/country_coordinates.dart';
import 'package:cyber_visualiser/utils/config.dart';

class StubHoneyLabsService extends HoneyLabsService {
  List<Map<String, dynamic>> stubbedEvents = [];

  @override
  Future<List<Map<String, dynamic>>> fetchRawEvents({
    required DateTime since,
    required DateTime until,
    int limit = 100,
  }) async {
    return stubbedEvents;
  }
}

void main() {
  group('CountryCoordinatesLookup Tests', () {
    test('Should return correct coordinates for valid country code', () {
      final us = CountryCoordinatesLookup.getCoordinate('US');
      expect(us.latitude, 37.0902);
      expect(us.longitude, -95.7129);

      final inCoord = CountryCoordinatesLookup.getCoordinate('IN');
      expect(inCoord.latitude, 20.5937);
      expect(inCoord.longitude, 78.9629);
    });

    test('Should return default coordinates (0.0, 0.0) for unknown country code', () {
      final unknown = CountryCoordinatesLookup.getCoordinate('XX');
      expect(unknown.latitude, 0.0);
      expect(unknown.longitude, 0.0);
    });
  });

  group('AttackEvent Model Tests', () {
    test('Should parse JSON correctly', () {
      final json = {
        'timestamp': '2026-06-07T05:19:59',
        'event_id': 'test-id-123',
        'source_ip': '1.2.3.4',
        'source_port': 80,
        'source_domain': 'test.domain',
        'country_code': 'US',
        'country_name': 'United States',
        'city_name': 'New York',
        'asn_number': 12345,
        'asn_org': 'Test Org',
        'dest_port': 22,
        'network_protocol': 'ssh',
        'http_method': '',
        'user_agent': 'Mozilla/5.0',
        'url_path': '',
        'url_domain': 'honeypot',
      };

      final event = AttackEvent.fromJson(json);

      expect(event.eventId, 'test-id-123');
      expect(event.sourceIp, '1.2.3.4');
      expect(event.destPort, 22);
      expect(event.severity, 'Critical');
      expect(event.displayTitle, 'SSH probe on port 22');
    });

    test('Should calculate correct severity based on port', () {
      final e1 = AttackEvent.fromJson({'dest_port': 22});
      expect(e1.severity, 'Critical');

      final e2 = AttackEvent.fromJson({'dest_port': 80});
      expect(e2.severity, 'High');

      final e3 = AttackEvent.fromJson({'dest_port': 443});
      expect(e3.severity, 'High');

      final e4 = AttackEvent.fromJson({'dest_port': 9780});
      expect(e4.severity, 'Medium');
    });
  });

  group('AttackRepository Deduplication Tests', () {
    test('Should filter out events with duplicate event IDs', () async {
      final stubService = StubHoneyLabsService();
      final repository = AttackRepository(stubService);

      stubService.stubbedEvents = [
        {
          'event_id': 'evt-1',
          'timestamp': '2026-06-07T05:19:59',
          'source_ip': '1.1.1.1',
          'dest_port': 80,
        },
        {
          'event_id': 'evt-1', // Duplicate ID
          'timestamp': '2026-06-07T05:20:00',
          'source_ip': '1.1.1.1',
          'dest_port': 80,
        },
        {
          'event_id': 'evt-2',
          'timestamp': '2026-06-07T05:20:01',
          'source_ip': '2.2.2.2',
          'dest_port': 443,
        }
      ];

      final newEvents = await repository.fetchNewEvents(
        since: DateTime.now().subtract(const Duration(minutes: 5)),
        until: DateTime.now(),
      );

      // Should only contain the 2 unique events
      expect(newEvents.length, 2);
      expect(newEvents[0].eventId, 'evt-1');
      expect(newEvents[1].eventId, 'evt-2');

      // Subsequent fetch with same stub should return 0 new events since they are cached
      final subsequent = await repository.fetchNewEvents(
        since: DateTime.now().subtract(const Duration(minutes: 5)),
        until: DateTime.now(),
      );
      expect(subsequent, isEmpty);
    });
  });

  group('AppConfig API Keys and Fallback Tests', () {
    test('Should fall back to env key if user key is empty', () {
      AppConfig.envApiKey = 'env-hl-key';
      AppConfig.envAbuseIpDbApiKey = 'env-abuse-key';
      AppConfig.userApiKey = '';
      AppConfig.userAbuseIpDbApiKey = '';

      expect(AppConfig.apiKey, 'env-hl-key');
      expect(AppConfig.abuseIpDbApiKey, 'env-abuse-key');
    });

    test('Should prioritize user custom keys if provided', () {
      AppConfig.envApiKey = 'env-hl-key';
      AppConfig.envAbuseIpDbApiKey = 'env-abuse-key';
      AppConfig.userApiKey = 'custom-hl-key';
      AppConfig.userAbuseIpDbApiKey = 'custom-abuse-key';

      expect(AppConfig.apiKey, 'custom-hl-key');
      expect(AppConfig.abuseIpDbApiKey, 'custom-abuse-key');
    });

    test('Should save user keys to preferences and update fields', () async {
      SharedPreferences.setMockInitialValues({});
      
      await AppConfig.saveUserKeys('new-user-hl-key', 'new-user-abuse-key');
      
      expect(AppConfig.userApiKey, 'new-user-hl-key');
      expect(AppConfig.userAbuseIpDbApiKey, 'new-user-abuse-key');
      expect(AppConfig.apiKey, 'new-user-hl-key');
      expect(AppConfig.abuseIpDbApiKey, 'new-user-abuse-key');

      // Verify stored keys in mock prefs
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('user_honeylabs_api_key'), 'new-user-hl-key');
      expect(prefs.getString('user_abuseipdb_api_key'), 'new-user-abuse-key');
    });
  });
}
