import 'dart:convert';
import 'dart:math' as math;

class SimulationKmlGenerator {
  /// Parses the Gemini JSON response and generates a valid, standard-compliant KML file.
  static String generateKmlFromJson(String jsonContent) {
    final Map<String, dynamic> data = json.decode(jsonContent);
    final String scenarioName = data['scenarioName'] ?? 'Attack Simulation';

    final Map<String, dynamic>? targetData = data['target'];
    if (targetData == null) {
      throw Exception('JSON response is missing target data.');
    }

    final String targetName = targetData['name'] ?? 'Target Server';
    final double targetLat = _toDouble(targetData['latitude']);
    final double targetLon = _toDouble(targetData['longitude']);
    final String targetIp = targetData['ip'] ?? '0.0.0.0';
    final String targetDesc = targetData['description'] ?? '';
    final String targetLocationName = targetData['locationName'] ?? 'Unknown';

    final List<dynamic> attackersList = data['attackers'] ?? [];

    final StringBuffer placemarksBuffer = StringBuffer();

    // 1. Generate target placemark HTML balloon description
    final targetDescription = _buildTargetBalloonHtml(
      name: targetName,
      ip: targetIp,
      locationName: targetLocationName,
      description: targetDesc,
    );

    // Target Placemark
    placemarksBuffer.write('''
    <Placemark>
      <name>Target: $targetName</name>
      <description><![CDATA[$targetDescription]]></description>
      <styleUrl>#targetNode</styleUrl>
      <Point>
        <coordinates>$targetLon,$targetLat,0</coordinates>
      </Point>
    </Placemark>''');

    // 2. Generate attacker nodes and vector lines
    int lineId = 1;
    for (final attackerData in attackersList) {
      if (attackerData is! Map<String, dynamic>) continue;

      final String attackerName = attackerData['name'] ?? 'Attacker Node';
      final double attackerLat = _toDouble(attackerData['latitude']);
      final double attackerLon = _toDouble(attackerData['longitude']);
      final String attackerIp = attackerData['ip'] ?? '0.0.0.0';
      final String threatType =
          attackerData['threatType'] ?? 'Unknown Cyber Threat';
      final String severity = attackerData['severity'] ?? 'HIGH';
      final String attackerDesc = attackerData['description'] ?? '';
      final String attackerLocationName =
          attackerData['locationName'] ?? 'Unknown';

      final attackerDescription = _buildAttackerBalloonHtml(
        name: attackerName,
        ip: attackerIp,
        locationName: attackerLocationName,
        threatType: threatType,
        severity: severity,
        description: attackerDesc,
      );

      // Attacker Placemark
      placemarksBuffer.write('''
    <Placemark>
      <name>$attackerName ($attackerLocationName)</name>
      <description><![CDATA[$attackerDescription]]></description>
      <styleUrl>#attackerNode</styleUrl>
      <Point>
        <coordinates>$attackerLon,$attackerLat,0</coordinates>
      </Point>
    </Placemark>''');

      // Parabolic Curve coordinate generation
      final lineCoords = _generateParabolicCoordinates(
        attackerLat,
        attackerLon,
        targetLat,
        targetLon,
      );

      // Attack Vector Line Placemark
      placemarksBuffer.write('''
    <Placemark>
      <name>Attack Vector #$lineId to target</name>
      <description><![CDATA[$attackerDescription]]></description>
      <styleUrl>#attackLine</styleUrl>
      <LineString>
        <tessellate>0</tessellate>
        <extrude>0</extrude>
        <altitudeMode>relativeToGround</altitudeMode>
        <coordinates>
          $lineCoords
        </coordinates>
      </LineString>
    </Placemark>''');
      lineId++;
    }

    // Build the final KML
    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>$scenarioName</name>
    <LookAt>
      <longitude>$targetLon</longitude>
      <latitude>$targetLat</latitude>
      <altitude>0</altitude>
      <heading>0</heading>
      <tilt>45</tilt>
      <range>8000000</range>
      <gx:altitudeMode>relativeToGround</gx:altitudeMode>
    </LookAt>
    <Style id="targetNode">
      <IconStyle>
        <scale>1.8</scale>
        <Icon>
          <href>http://maps.google.com/mapfiles/kml/paddle/wht-circle.png</href>
        </Icon>
      </IconStyle>
      <BalloonStyle>
        <bgColor>ff1a1c29</bgColor>
        <textColor>ffffffff</textColor>
      </BalloonStyle>
    </Style>
    <Style id="attackerNode">
      <IconStyle>
        <scale>1.4</scale>
        <Icon>
          <href>http://maps.google.com/mapfiles/kml/paddle/red-circle.png</href>
        </Icon>
      </IconStyle>
      <BalloonStyle>
        <bgColor>ff1a1c29</bgColor>
        <textColor>ffffffff</textColor>
      </BalloonStyle>
    </Style>
    <Style id="attackLine">
      <LineStyle>
        <color>cc00a5ff</color> <!-- semi-transparent orange/red -->
        <width>4</width>
      </LineStyle>
    </Style>
    ${placemarksBuffer.toString()}
  </Document>
</kml>''';
  }

  static double _toDouble(dynamic val) {
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val) ?? 0.0;
    return 0.0;
  }

  // Helper to calculate distance in meters using Haversine formula
  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000; // Earth's radius in meters
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a =
        math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) *
            math.cos(lat2 * math.pi / 180) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  // Helper to generate 3D curved parabolic coordinate string
  static String _generateParabolicCoordinates(
    double sLat,
    double sLon,
    double tLat,
    double tLon,
  ) {
    final List<String> coords = [];
    final steps = 30;
    final distance = _calculateDistance(sLat, sLon, tLat, tLon);
    final double maxHeight = math.min(
      distance * 0.15,
      1200000,
    ); // 15% of distance, capped at 1,200km

    for (int i = 0; i <= steps; i++) {
      final t = i / steps;
      final lat = sLat + (tLat - sLat) * t;

      double diffLon = tLon - sLon;
      if (diffLon > 180) {
        diffLon -= 360;
      } else if (diffLon < -180) {
        diffLon += 360;
      }
      double lon = sLon + diffLon * t;
      if (lon > 180) {
        lon -= 360;
      } else if (lon < -180) {
        lon += 360;
      }

      final alt = maxHeight * 4 * t * (1 - t);
      coords.add('$lon,$lat,$alt');
    }
    return coords.join('\n          ');
  }

  static String _buildTargetBalloonHtml({
    required String name,
    required String ip,
    required String locationName,
    required String description,
  }) {
    return '''
<div style="font-family: 'Outfit', 'Segoe UI', Roboto, sans-serif; min-width: 300px; padding: 16px; background-color: #0f111a; color: #ffffff; border-radius: 12px; border: 1px solid #1e293b;">
  <h3 style="margin-top: 0; margin-bottom: 12px; font-size: 16px; font-weight: 700; color: #38bdf8; border-bottom: 1px solid #334155; padding-bottom: 8px; letter-spacing: 0.5px;">TARGET INFRASTRUCTURE</h3>
  <table style="width: 100%; font-size: 13px; border-collapse: collapse;">
    <tr style="border-bottom: 1px solid #1e293b;">
      <td style="padding: 8px 0; font-weight: 600; color: #94a3b8; width: 100px;">Name:</td>
      <td style="padding: 8px 0; color: #f1f5f9; font-weight: 700;">$name</td>
    </tr>
    <tr style="border-bottom: 1px solid #1e293b;">
      <td style="padding: 8px 0; font-weight: 600; color: #94a3b8;">IP Address:</td>
      <td style="padding: 8px 0; color: #f1f5f9; font-family: monospace; font-weight: 700;">$ip</td>
    </tr>
    <tr style="border-bottom: 1px solid #1e293b;">
      <td style="padding: 8px 0; font-weight: 600; color: #94a3b8;">Location:</td>
      <td style="padding: 8px 0; color: #f1f5f9;">$locationName</td>
    </tr>
    <tr>
      <td style="padding: 8px 0; font-weight: 600; color: #94a3b8;">Details:</td>
      <td style="padding: 8px 0; color: #cbd5e1; font-style: italic;">$description</td>
    </tr>
  </table>
</div>
''';
  }

  static String _buildAttackerBalloonHtml({
    required String name,
    required String ip,
    required String locationName,
    required String threatType,
    required String severity,
    required String description,
  }) {
    final severityColor =
        severity.toUpperCase() == 'CRITICAL' || severity.toUpperCase() == 'HIGH'
        ? '#ff4a5a'
        : severity.toUpperCase() == 'MEDIUM'
        ? '#ff9f43'
        : '#1dd1a1';

    return '''
<div style="font-family: 'Outfit', 'Segoe UI', Roboto, sans-serif; min-width: 320px; max-width: 400px; padding: 16px; background-color: #0f111a; color: #ffffff; border-radius: 12px; border: 1px solid #1e293b;">
  <h3 style="margin-top: 0; margin-bottom: 12px; font-size: 16px; font-weight: 700; color: #ff4a5a; border-bottom: 1px solid #334155; padding-bottom: 8px; letter-spacing: 0.5px;">ATTACK THREAT NODE</h3>
  <table style="width: 100%; font-size: 13px; border-collapse: collapse;">
    <tr style="border-bottom: 1px solid #1e293b;">
      <td style="padding: 8px 0; font-weight: 600; color: #94a3b8; width: 100px;">Node ID:</td>
      <td style="padding: 8px 0; color: #f1f5f9; font-weight: 700;">$name</td>
    </tr>
    <tr style="border-bottom: 1px solid #1e293b;">
      <td style="padding: 8px 0; font-weight: 600; color: #94a3b8;">Source IP:</td>
      <td style="padding: 8px 0; color: #f1f5f9; font-family: monospace; font-weight: 700;">$ip</td>
    </tr>
    <tr style="border-bottom: 1px solid #1e293b;">
      <td style="padding: 8px 0; font-weight: 600; color: #94a3b8;">Origin:</td>
      <td style="padding: 8px 0; color: #f1f5f9;">$locationName</td>
    </tr>
    <tr style="border-bottom: 1px solid #1e293b;">
      <td style="padding: 8px 0; font-weight: 600; color: #94a3b8;">Threat Type:</td>
      <td style="padding: 8px 0; color: #38bdf8; font-weight: 700;">$threatType</td>
    </tr>
    <tr style="border-bottom: 1px solid #1e293b;">
      <td style="padding: 8px 0; font-weight: 600; color: #94a3b8;">Severity:</td>
      <td style="padding: 8px 0; font-weight: 700; color: $severityColor;">$severity</td>
    </tr>
    <tr>
      <td style="padding: 8px 0; font-weight: 600; color: #94a3b8;">Details:</td>
      <td style="padding: 8px 0; color: #cbd5e1; font-style: italic;">$description</td>
    </tr>
  </table>
</div>
''';
  }
}
