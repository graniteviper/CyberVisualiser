import 'package:flutter_test/flutter_test.dart';
import 'package:cyber_visualiser/models/abuse_report_model.dart';
import 'package:cyber_visualiser/services/abuseipdb_service.dart';
import 'package:cyber_visualiser/repositories/track_ip_repository.dart';

class StubAbuseIpDbService extends AbuseIpDbService {
  AbuseIpReport? stubbedReport;

  @override
  Future<AbuseIpReport> fetchIpReport({
    required String ipAddress,
    required int maxAgeInDays,
  }) async {
    if (stubbedReport != null) {
      return stubbedReport!;
    }
    throw Exception('No stub report configured.');
  }
}

void main() {
  group('AbuseIpReport Model Parsing Tests', () {
    test('Should parse check API response JSON correctly', () {
      final json = {
        'ipAddress': '213.209.159.227',
        'isPublic': true,
        'ipVersion': 4,
        'isWhitelisted': false,
        'abuseConfidenceScore': 85,
        'countryCode': 'NL',
        'countryName': 'Netherlands',
        'usageType': 'Data Center/Web Hosting/Transit',
        'isp': 'Interactive 3D B.V.',
        'domain': 'i3d.net',
        'totalReports': 1420,
        'numDistinctUsers': 34,
        'lastReportedAt': '2026-06-12T10:15:30+00:00',
        'reports': [
          {
            'reportedAt': '2026-06-12T10:15:30+00:00',
            'comment': 'SSH brute force attempt',
            'categories': [18, 22],
            'reporterId': 489,
            'reporterCountryCode': 'US',
            'reporterCountryName': 'United States',
          },
          {
            'reportedAt': '2026-06-11T20:30:12+00:00',
            'comment': 'Exploit probe on port 80',
            'categories': [21],
            'reporterId': 512,
            'reporterCountryCode': 'DE',
            'reporterCountryName': 'Germany',
          }
        ]
      };

      final report = AbuseIpReport.fromJson(json);

      expect(report.ipAddress, '213.209.159.227');
      expect(report.abuseConfidenceScore, 85);
      expect(report.countryCode, 'NL');
      expect(report.isp, 'Interactive 3D B.V.');
      expect(report.reports.length, 2);

      // Verify individual report item
      final item1 = report.reports[0];
      expect(item1.comment, 'SSH brute force attempt');
      expect(item1.reporterCountryCode, 'US');
      expect(item1.categories, containsAll([18, 22]));

      // Test category translation
      expect(item1.categoryNames, containsAll(['Brute-Force', 'SSH']));
      
      final item2 = report.reports[1];
      expect(item2.categoryNames, contains('Web App Attack'));
    });
  });

  group('TrackIpRepository Tests', () {
    test('Should delegate fetching to service successfully', () async {
      final stubService = StubAbuseIpDbService();
      final repository = TrackIpRepository(stubService);

      final dummyReport = AbuseIpReport(
        ipAddress: '1.1.1.1',
        isPublic: true,
        ipVersion: 4,
        isWhitelisted: false,
        abuseConfidenceScore: 10,
        countryCode: 'US',
        countryName: 'United States',
        usageType: 'DNS',
        isp: 'Cloudflare',
        domain: 'cloudflare.com',
        totalReports: 5,
        numDistinctUsers: 2,
        reports: [],
      );

      stubService.stubbedReport = dummyReport;

      final result = await repository.getIpReport('1.1.1.1', 5);

      expect(result.ipAddress, '1.1.1.1');
      expect(result.totalReports, 5);
      expect(result.abuseConfidenceScore, 10);
    });
  });
}
