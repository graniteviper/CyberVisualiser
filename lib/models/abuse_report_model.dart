class AbuseReportItem {
  final DateTime reportedAt;
  final String comment;
  final List<int> categories;
  final int reporterId;
  final String reporterCountryCode;
  final String reporterCountryName;

  static const Map<int, String> categoryMap = {
    1: 'DNS Compromise',
    2: 'DNS Poisoning',
    3: 'Fraud Orders',
    4: 'DDoS Attack',
    5: 'FTP Brute-Force',
    6: 'Ping of Death',
    7: 'Phishing',
    8: 'Fraud VoIP',
    9: 'Open Proxy',
    10: 'Web Spam',
    11: 'Email Spam',
    12: 'Blog Spam',
    13: 'VPN IP',
    14: 'Port Scan',
    15: 'Hacking',
    16: 'SQL Injection',
    17: 'Spoofing',
    18: 'Brute-Force',
    19: 'Bad Web Bot',
    20: 'Exploited Host',
    21: 'Web App Attack',
    22: 'SSH',
    23: 'IoT Targeted',
  };

  List<String> get categoryNames =>
      categories.map((c) => categoryMap[c] ?? 'Category $c').toList();

  AbuseReportItem({
    required this.reportedAt,
    required this.comment,
    required this.categories,
    required this.reporterId,
    required this.reporterCountryCode,
    required this.reporterCountryName,
  });

  factory AbuseReportItem.fromJson(Map<String, dynamic> json) {
    return AbuseReportItem(
      reportedAt: DateTime.tryParse(json['reportedAt'] ?? '') ?? DateTime.now(),
      comment: json['comment'] ?? '',
      categories: List<int>.from(json['categories'] ?? []),
      reporterId: json['reporterId'] ?? 0,
      reporterCountryCode: json['reporterCountryCode'] ?? '',
      reporterCountryName: json['reporterCountryName'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'reportedAt': reportedAt.toIso8601String(),
      'comment': comment,
      'categories': categories,
      'reporterId': reporterId,
      'reporterCountryCode': reporterCountryCode,
      'reporterCountryName': reporterCountryName,
    };
  }
}

class AbuseIpReport {
  final String ipAddress;
  final bool isPublic;
  final int ipVersion;
  final bool isWhitelisted;
  final int abuseConfidenceScore;
  final String countryCode;
  final String countryName;
  final String usageType;
  final String isp;
  final String domain;
  final int totalReports;
  final int numDistinctUsers;
  final DateTime? lastReportedAt;
  final List<AbuseReportItem> reports;

  AbuseIpReport({
    required this.ipAddress,
    required this.isPublic,
    required this.ipVersion,
    required this.isWhitelisted,
    required this.abuseConfidenceScore,
    required this.countryCode,
    required this.countryName,
    required this.usageType,
    required this.isp,
    required this.domain,
    required this.totalReports,
    required this.numDistinctUsers,
    this.lastReportedAt,
    required this.reports,
  });

  factory AbuseIpReport.fromJson(Map<String, dynamic> json) {
    final reportsList = (json['reports'] as List?)
            ?.map((e) => AbuseReportItem.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];

    return AbuseIpReport(
      ipAddress: json['ipAddress'] ?? '',
      isPublic: json['isPublic'] ?? false,
      ipVersion: json['ipVersion'] ?? 4,
      isWhitelisted: json['isWhitelisted'] ?? false,
      abuseConfidenceScore: json['abuseConfidenceScore'] ?? 0,
      countryCode: json['countryCode'] ?? '',
      countryName: json['countryName'] ?? '',
      usageType: json['usageType'] ?? '',
      isp: json['isp'] ?? '',
      domain: json['domain'] ?? '',
      totalReports: json['totalReports'] ?? 0,
      numDistinctUsers: json['numDistinctUsers'] ?? 0,
      lastReportedAt: DateTime.tryParse(json['lastReportedAt'] ?? ''),
      reports: reportsList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ipAddress': ipAddress,
      'isPublic': isPublic,
      'ipVersion': ipVersion,
      'isWhitelisted': isWhitelisted,
      'abuseConfidenceScore': abuseConfidenceScore,
      'countryCode': countryCode,
      'countryName': countryName,
      'usageType': usageType,
      'isp': isp,
      'domain': domain,
      'totalReports': totalReports,
      'numDistinctUsers': numDistinctUsers,
      'lastReportedAt': lastReportedAt?.toIso8601String(),
      'reports': reports.map((e) => e.toJson()).toList(),
    };
  }
}
