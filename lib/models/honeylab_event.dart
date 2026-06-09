class HoneyLabEvent {
  final DateTime timestamp;
  final String eventId;
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
  final String urlDomain;

  HoneyLabEvent({
    required this.timestamp,
    required this.eventId,
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
    required this.urlDomain,
  });

  factory HoneyLabEvent.fromJson(Map<String, dynamic> json) {
    DateTime parsedTime;
    try {
      parsedTime = DateTime.parse(json['timestamp'] ?? '');
    } catch (_) {
      parsedTime = DateTime.now();
    }

    return HoneyLabEvent(
      timestamp: parsedTime,
      eventId: json['event_id'] ?? '',
      sourceIp: json['source_ip'] ?? '',
      sourcePort: json['source_port'] is int ? json['source_port'] : int.tryParse(json['source_port']?.toString() ?? '') ?? 0,
      sourceDomain: json['source_domain'] ?? '',
      countryCode: json['country_code'] ?? '',
      countryName: json['country_name'] ?? '',
      cityName: json['city_name'] ?? '',
      asnNumber: json['asn_number'] is int ? json['asn_number'] : int.tryParse(json['asn_number']?.toString() ?? '') ?? 0,
      asnOrg: json['asn_org'] ?? '',
      destPort: json['dest_port'] is int ? json['dest_port'] : int.tryParse(json['dest_port']?.toString() ?? '') ?? 0,
      networkProtocol: json['network_protocol'] ?? '',
      httpMethod: json['http_method'] ?? '',
      userAgent: json['user_agent'] ?? '',
      urlPath: json['url_path'] ?? '',
      urlDomain: json['url_domain'] ?? '',
    );
  }

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

  String get displayTitle {
    if (httpMethod.isNotEmpty && urlPath.isNotEmpty) {
      return '$httpMethod $urlPath';
    }
    if (networkProtocol.isNotEmpty) {
      return '${networkProtocol.toUpperCase()} probe on port $destPort';
    }
    return 'Probe on port $destPort';
  }
}
