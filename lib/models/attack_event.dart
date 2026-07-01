class AttackEvent {
  final String eventId;
  final DateTime timestamp;
  final String sourceIp;
  final int sourcePort;
  final String sourceDomain;
  final String countryCode;
  final String countryName;
  final String cityName;
  final int asnNumber;
  final String asnOrg;
  final int destPort;
  final String networkProtocol;
  final String httpMethod;
  final String userAgent;
  final String urlPath;
  final String communityId;

  AttackEvent({
    required this.eventId,
    required this.timestamp,
    required this.sourceIp,
    required this.sourcePort,
    required this.sourceDomain,
    required this.countryCode,
    required this.countryName,
    required this.cityName,
    required this.asnNumber,
    required this.asnOrg,
    required this.destPort,
    required this.networkProtocol,
    required this.httpMethod,
    required this.userAgent,
    required this.urlPath,
    required this.communityId,
  });

  factory AttackEvent.fromJson(Map<String, dynamic> json) {
    DateTime parsedTime;
    try {
      parsedTime = DateTime.parse(json['timestamp'] ?? '');
    } catch (_) {
      parsedTime = DateTime.now();
    }

    int parseInt(dynamic value) {
      if (value is int) return value;
      if (value == null) return 0;
      return int.tryParse(value.toString()) ?? 0;
    }

    return AttackEvent(
      eventId: json['event_id'] ?? json['eventId'] ?? '',
      timestamp: parsedTime,
      sourceIp: json['source_ip'] ?? json['sourceIp'] ?? '',
      sourcePort: parseInt(json['source_port'] ?? json['sourcePort']),
      sourceDomain: json['source_domain'] ?? json['sourceDomain'] ?? '',
      countryCode: json['country_code'] ?? json['countryCode'] ?? '',
      countryName: json['country_name'] ?? json['countryName'] ?? '',
      cityName: json['city_name'] ?? json['cityName'] ?? '',
      asnNumber: parseInt(json['asn_number'] ?? json['asnNumber']),
      asnOrg: json['asn_org'] ?? json['asnOrg'] ?? '',
      destPort: parseInt(json['dest_port'] ?? json['destPort']),
      networkProtocol:
          json['network_protocol'] ?? json['networkProtocol'] ?? '',
      httpMethod: json['http_method'] ?? json['httpMethod'] ?? '',
      userAgent: json['user_agent'] ?? json['userAgent'] ?? '',
      urlPath: json['url_path'] ?? json['urlPath'] ?? '',
      communityId: json['community_id'] ?? json['communityId'] ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'event_id': eventId,
      'timestamp': timestamp.toIso8601String(),
      'source_ip': sourceIp,
      'source_port': sourcePort,
      'source_domain': sourceDomain,
      'country_code': countryCode,
      'country_name': countryName,
      'city_name': cityName,
      'asn_number': asnNumber,
      'asn_org': asnOrg,
      'dest_port': destPort,
      'network_protocol': networkProtocol,
      'http_method': httpMethod,
      'user_agent': userAgent,
      'url_path': urlPath,
      'community_id': communityId,
    };
  }

  /// Categorize severity level based on the target destination port
  String get severity {
    switch (destPort) {
      case 22:
      case 23:
      case 445:
      case 3389:
        return 'Critical';
      case 80:
      case 443:
      case 8080:
      case 8443:
        return 'High';
      default:
        return 'Medium';
    }
  }

  /// A user-friendly title representing the specific attack vector
  String get displayTitle {
    if (httpMethod.isNotEmpty && urlPath.isNotEmpty) {
      return '$httpMethod $urlPath';
    }
    if (networkProtocol.isNotEmpty) {
      return '${networkProtocol.toUpperCase()} probe on port $destPort';
    }
    return 'Probe on port $destPort';
  }

  /// Categorizes this attack event into one of the 5 categories
  String get attackCategory {
    final title = displayTitle.toLowerCase();
    final protocol = networkProtocol.toLowerCase();
    final url = urlPath.toLowerCase();
    final userAgentStr = userAgent.toLowerCase();

    // 1. SSH attacks
    if (destPort == 22 || protocol.contains('ssh') || title.contains('ssh')) {
      return 'SSH attacks';
    }

    // 2. DDOS attacks
    if (title.contains('ddos') ||
        url.contains('ddos') ||
        protocol == 'udp' ||
        protocol == 'icmp') {
      return 'DDOS attacks';
    }

    // 3. brute force
    if (title.contains('brute') ||
        title.contains('force') ||
        destPort == 23 || // Telnet
        destPort == 3389 || // RDP
        url.contains('login') ||
        url.contains('wp-login') ||
        url.contains('admin')) {
      return 'brute force';
    }

    // 4. malware
    if (title.contains('malware') ||
        url.contains('.sh') ||
        url.contains('.exe') ||
        url.contains('.php') ||
        url.contains('/bin/') ||
        userAgentStr.contains('mirai') ||
        userAgentStr.contains('malware')) {
      return 'malware';
    }

    // 5. other
    return 'other';
  }
}
