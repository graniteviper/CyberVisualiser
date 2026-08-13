import 'dart:convert';
import 'dart:math' as math;

class HistoricalKmlGenerator {
  /// Generates a valid KML file for a single historical cyber attack.
  static String generateSingleAttackKml(Map<String, dynamic> data) {
    final Map<String, dynamic>? attacker = data['attacker'];
    final Map<String, dynamic>? victim = data['victim'];
    final String summary = data['summary'] ?? '';

    if (attacker == null || victim == null) {
      throw Exception('JSON response is missing attacker or victim coordinates.');
    }

    final String attackerName = attacker['name'] ?? 'Threat Actor';
    final String attackerLocation = attacker['locationName'] ?? 'Unknown';
    final double attackerLat = _toDouble(attacker['latitude']);
    final double attackerLon = _toDouble(attacker['longitude']);
    final String attackerDesc = attacker['description'] ?? '';

    final String victimName = victim['name'] ?? 'Target Entity';
    final String victimLocation = victim['locationName'] ?? 'Unknown';
    final double victimLat = _toDouble(victim['latitude']);
    final double victimLon = _toDouble(victim['longitude']);
    final String victimDesc = victim['description'] ?? '';

    final StringBuffer placemarksBuffer = StringBuffer();

    // Attacker Placemark
    final attackerBalloon = _buildBalloonHtml(
      title: 'THREAT ACTOR ORIGIN',
      name: attackerName,
      location: attackerLocation,
      details: attackerDesc,
      isAttacker: true,
    );
    placemarksBuffer.write('''
    <Placemark>
      <name>Attacker: $attackerName</name>
      <description><![CDATA[$attackerBalloon]]></description>
      <styleUrl>#attackerNode</styleUrl>
      <Point>
        <coordinates>$attackerLon,$attackerLat,0</coordinates>
      </Point>
    </Placemark>''');

    // Victim Placemark
    final victimBalloon = _buildBalloonHtml(
      title: 'VICTIM TARGET',
      name: victimName,
      location: victimLocation,
      details: victimDesc,
      isAttacker: false,
    );
    placemarksBuffer.write('''
    <Placemark>
      <name>Victim: $victimName</name>
      <description><![CDATA[$victimBalloon]]></description>
      <styleUrl>#victimNode</styleUrl>
      <Point>
        <coordinates>$victimLon,$victimLat,0</coordinates>
      </Point>
    </Placemark>''');

    // Parabolic Curve representing the attack vector
    final lineCoords = _generateParabolicCoordinates(
      attackerLat,
      attackerLon,
      victimLat,
      victimLon,
    );
    placemarksBuffer.write('''
    <Placemark>
      <name>Attack Vector: $attackerName to $victimName</name>
      <description><![CDATA[$victimBalloon]]></description>
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

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>Historical Incident: $victimName</name>
    <LookAt>
      <longitude>$victimLon</longitude>
      <latitude>$victimLat</latitude>
      <altitude>0</altitude>
      <heading>0</heading>
      <tilt>45</tilt>
      <range>5000000</range>
      <gx:altitudeMode>relativeToGround</gx:altitudeMode>
    </LookAt>
    <Style id="attackerNode">
      <IconStyle>
        <scale>1.6</scale>
        <Icon>
          <href>http://maps.google.com/mapfiles/kml/paddle/red-square.png</href>
        </Icon>
      </IconStyle>
      <BalloonStyle>
        <bgColor>ff1a1c29</bgColor>
        <textColor>ffffffff</textColor>
      </BalloonStyle>
    </Style>
    <Style id="victimNode">
      <IconStyle>
        <scale>1.6</scale>
        <Icon>
          <href>http://maps.google.com/mapfiles/kml/paddle/wht-circle.png</href>
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
        <width>5</width>
      </LineStyle>
    </Style>
    ${placemarksBuffer.toString()}
  </Document>
</kml>''';
  }

  /// Generates a valid KML file for a category of historical attacks (top 10 attacks).
  static String generateCategoryAttackKml(Map<String, dynamic> data) {
    final String scenarioName = data['scenarioName'] ?? 'Category Attack Tour';
    final List<dynamic> attacksList = data['attacks'] ?? [];

    final StringBuffer placemarksBuffer = StringBuffer();
    double centerLat = 0.0;
    double centerLon = 0.0;
    int count = 0;

    int lineId = 1;
    for (final attack in attacksList) {
      if (attack is! Map<String, dynamic>) continue;

      final String title = attack['title'] ?? 'Incident';
      final Map<String, dynamic>? attacker = attack['attacker'];
      final Map<String, dynamic>? victim = attack['victim'];

      if (attacker == null || victim == null) continue;

      final String attackerName = attacker['name'] ?? 'Threat Actor';
      final String attackerLocation = attacker['locationName'] ?? 'Unknown';
      final double attackerLat = _toDouble(attacker['latitude']);
      final double attackerLon = _toDouble(attacker['longitude']);
      final String attackerDesc = attacker['description'] ?? '';

      final String victimName = victim['name'] ?? 'Target Entity';
      final String victimLocation = victim['locationName'] ?? 'Unknown';
      final double victimLat = _toDouble(victim['latitude']);
      final double victimLon = _toDouble(victim['longitude']);
      final String victimDesc = victim['description'] ?? '';

      centerLat += victimLat;
      centerLon += victimLon;
      count++;

      // Attacker node
      final attackerBalloon = _buildBalloonHtml(
        title: 'THREAT ACTOR ORIGIN',
        name: attackerName,
        location: attackerLocation,
        details: '$attackerDesc (Part of incident: $title)',
        isAttacker: true,
      );
      placemarksBuffer.write('''
    <Placemark>
      <name>Attacker: $attackerName ($title)</name>
      <description><![CDATA[$attackerBalloon]]></description>
      <styleUrl>#attackerNode</styleUrl>
      <Point>
        <coordinates>$attackerLon,$attackerLat,0</coordinates>
      </Point>
    </Placemark>''');

      // Victim node
      final victimBalloon = _buildBalloonHtml(
        title: 'VICTIM TARGET',
        name: victimName,
        location: victimLocation,
        details: '$victimDesc (Incident: $title)',
        isAttacker: false,
      );
      placemarksBuffer.write('''
    <Placemark>
      <name>Victim: $victimName ($title)</name>
      <description><![CDATA[$victimBalloon]]></description>
      <styleUrl>#victimNode</styleUrl>
      <Point>
        <coordinates>$victimLon,$victimLat,0</coordinates>
      </Point>
    </Placemark>''');

      // Attack vector line
      final lineCoords = _generateParabolicCoordinates(
        attackerLat,
        attackerLon,
        victimLat,
        victimLon,
      );
      placemarksBuffer.write('''
    <Placemark>
      <name>Vector #$lineId: $attackerName to $victimName</name>
      <description><![CDATA[$victimBalloon]]></description>
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

    if (count > 0) {
      centerLat /= count;
      centerLon /= count;
    }

    return '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>$scenarioName</name>
    <LookAt>
      <longitude>$centerLon</longitude>
      <latitude>$centerLat</latitude>
      <altitude>0</altitude>
      <heading>0</heading>
      <tilt>30</tilt>
      <range>8000000</range>
      <gx:altitudeMode>relativeToGround</gx:altitudeMode>
    </LookAt>
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
    <Style id="victimNode">
      <IconStyle>
        <scale>1.4</scale>
        <Icon>
          <href>http://maps.google.com/mapfiles/kml/paddle/wht-circle.png</href>
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

  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const r = 6371000;
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

  static String _generateParabolicCoordinates(
    double sLat,
    double sLon,
    double tLat,
    double tLon,
  ) {
    final List<String> coords = [];
    final steps = 30;
    final distance = _calculateDistance(sLat, sLon, tLat, tLon);
    final double maxHeight = math.min(distance * 0.15, 1200000);

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

  static String _buildBalloonHtml({
    required String title,
    required String name,
    required String location,
    required String details,
    required bool isAttacker,
  }) {
    final primaryColor = isAttacker ? '#ff4a5a' : '#38bdf8';
    return '''
<div style="font-family: 'Outfit', 'Segoe UI', Roboto, sans-serif; min-width: 300px; padding: 16px; background-color: #0f111a; color: #ffffff; border-radius: 12px; border: 1px solid #1e293b;">
  <h3 style="margin-top: 0; margin-bottom: 12px; font-size: 16px; font-weight: 700; color: $primaryColor; border-bottom: 1px solid #334155; padding-bottom: 8px; letter-spacing: 0.5px;">$title</h3>
  <table style="width: 100%; font-size: 13px; border-collapse: collapse;">
    <tr style="border-bottom: 1px solid #1e293b;">
      <td style="padding: 8px 0; font-weight: 600; color: #94a3b8; width: 100px;">Name:</td>
      <td style="padding: 8px 0; color: #f1f5f9; font-weight: 700;">$name</td>
    </tr>
    <tr style="border-bottom: 1px solid #1e293b;">
      <td style="padding: 8px 0; font-weight: 600; color: #94a3b8;">Location:</td>
      <td style="padding: 8px 0; color: #f1f5f9;">$location</td>
    </tr>
    <tr>
      <td style="padding: 8px 0; font-weight: 600; color: #94a3b8;">Details:</td>
      <td style="padding: 8px 0; color: #cbd5e1; font-style: italic;">$details</td>
    </tr>
  </table>
</div>
''';
  }
}
