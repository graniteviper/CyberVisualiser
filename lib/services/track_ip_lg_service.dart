import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import '../models/abuse_report_model.dart';
import '../utils/country_coordinates.dart';
import 'lg_service.dart';

class TrackIpLgService {
  final LgService _lgService;

  TrackIpLgService(this._lgService);

  // Helper to calculate bearing in degrees between two points
  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    final lat1Rad = lat1 * math.pi / 180;
    final lat2Rad = lat2 * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;

    final y = math.sin(dLon) * math.cos(lat2Rad);
    final x = math.cos(lat1Rad) * math.sin(lat2Rad) -
        math.sin(lat1Rad) * math.cos(lat2Rad) * math.cos(dLon);

    final brng = math.atan2(y, x) * 180 / math.pi;
    return (brng + 360) % 360;
  }

  // Helper to calculate distance in meters using Haversine formula
  double _calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const r = 6371000; // Earth's radius in meters
    final dLat = (lat2 - lat1) * math.pi / 180;
    final dLon = (lon2 - lon1) * math.pi / 180;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180) * math.cos(lat2 * math.pi / 180) *
        math.sin(dLon / 2) * math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return r * c;
  }

  // Helper to generate 3D curved parabolic coordinate string
  String _generateParabolicCoordinates(double sLat, double sLon, double tLat, double tLon) {
    final List<String> coords = [];
    final steps = 30;
    final distance = _calculateDistance(sLat, sLon, tLat, tLon);
    final double maxHeight = math.min(distance * 0.15, 1200000); // 15% of distance, capped at 1,200km

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

  /// Sends the main KML displaying the tracked IP source marker, victim/reporter markers, and curved vectors.
  Future<bool> sendTrackIpKML(AbuseIpReport report) async {
    if (!_lgService.isConnected) {
      debugPrint('HoneyVision TrackIP LG: Liquid Galaxy is not connected.');
      return false;
    }

    try {
      final sCoord = CountryCoordinatesLookup.getCoordinate(report.countryCode);
      final sLat = sCoord.latitude;
      final sLon = sCoord.longitude;

      final StringBuffer placemarksBuffer = StringBuffer();

      // 1. Target Tracked IP Source Placemark
      final severityColor = report.abuseConfidenceScore > 50
          ? '#ff4a5a'
          : report.abuseConfidenceScore > 20
              ? '#ff9f43'
              : '#1dd1a1';

      final ipDescription = '''<description><![CDATA[
        <div style="font-family: 'Outfit', 'Segoe UI', Roboto, sans-serif; min-width: 300px; padding: 16px; background-color: #0f111a; color: #ffffff; border-radius: 12px; border: 1px solid #1e293b;">
          <h3 style="margin-top: 0; margin-bottom: 12px; font-size: 16px; font-weight: 700; color: #38bdf8; border-bottom: 1px solid #334155; padding-bottom: 8px; letter-spacing: 0.5px;">TRACKED IP TELEMETRY</h3>
          <table style="width: 100%; font-size: 13px; border-collapse: collapse;">
            <tr style="border-bottom: 1px solid #1e293b;">
              <td style="padding: 8px 0; font-weight: 600; color: #94a3b8; width: 100px;">IP Address:</td>
              <td style="padding: 8px 0; color: #f1f5f9; font-weight: 700; font-family: monospace;">${report.ipAddress}</td>
            </tr>
            <tr style="border-bottom: 1px solid #1e293b;">
              <td style="padding: 8px 0; font-weight: 600; color: #94a3b8;">Risk Score:</td>
              <td style="padding: 8px 0; font-weight: 700; color: $severityColor;">${report.abuseConfidenceScore}%</td>
            </tr>
            <tr style="border-bottom: 1px solid #1e293b;">
              <td style="padding: 8px 0; font-weight: 600; color: #94a3b8;">ISP / Domain:</td>
              <td style="padding: 8px 0; color: #f1f5f9;">${report.isp}<br/><span style="font-size: 11px; color: #64748b;">${report.domain}</span></td>
            </tr>
            <tr style="border-bottom: 1px solid #1e293b;">
              <td style="padding: 8px 0; font-weight: 600; color: #94a3b8;">Origin:</td>
              <td style="padding: 8px 0; color: #f1f5f9;">${report.countryName} (${report.countryCode})</td>
            </tr>
            <tr>
              <td style="padding: 8px 0; font-weight: 600; color: #94a3b8;">Total Reports:</td>
              <td style="padding: 8px 0; color: #f1f5f9; font-weight: 500;">${report.totalReports}</td>
            </tr>
          </table>
        </div>
      ]]></description>''';

      placemarksBuffer.write('''
    <Placemark>
      <name>Tracked Source: ${report.ipAddress}</name>
      $ipDescription
      <styleUrl>#trackedIpPoint</styleUrl>
      <Point>
        <coordinates>$sLon,$sLat,0</coordinates>
      </Point>
    </Placemark>''');

      // 2. Group reports by country code to prevent overlapping markers
      final Map<String, List<AbuseReportItem>> reportsByCountry = {};
      for (final r in report.reports) {
        if (r.reporterCountryCode.isNotEmpty) {
          reportsByCountry.putIfAbsent(r.reporterCountryCode, () => []).add(r);
        }
      }

      int lineId = 1;
      reportsByCountry.forEach((countryCode, list) {
        final rCoord = CountryCoordinatesLookup.getCoordinate(countryCode);
        if (rCoord.latitude == 0.0 && rCoord.longitude == 0.0) return;

        final rLat = rCoord.latitude;
        final rLon = rCoord.longitude;
        final countryName = list.first.reporterCountryName.isNotEmpty
            ? list.first.reporterCountryName
            : countryCode;

        // Compile HTML list of reports from this country (limit to 3 for balloon space)
        final StringBuffer reportsListHtml = StringBuffer();
        final displayList = list.take(3).toList();
        for (final item in displayList) {
          final cats = item.categoryNames.join(', ');
          final cleanComment = item.comment.length > 90
              ? '${item.comment.substring(0, 87)}...'
              : item.comment;
          reportsListHtml.write('''
            <div style="margin-bottom: 10px; border-bottom: 1px solid #1e293b; padding-bottom: 6px;">
              <span style="font-size: 11px; color: #64748b; font-weight: bold;">${item.reportedAt.toLocal().toString().split(' ')[0]}</span>
              <span style="font-size: 11px; color: #ff9f43; font-weight: bold; margin-left: 6px;">$cats</span>
              <p style="margin: 4px 0 0 0; color: #e2e8f0; font-size: 12px; font-style: italic;">"$cleanComment"</p>
            </div>
          ''');
        }

        if (list.length > 3) {
          reportsListHtml.write('''
            <div style="font-size: 11px; color: #38bdf8; text-align: center; margin-top: 4px;">+ ${list.length - 3} more reports from this region</div>
          ''');
        }

        final reporterDescription = '''<description><![CDATA[
          <div style="font-family: 'Outfit', 'Segoe UI', Roboto, sans-serif; min-width: 320px; max-width: 400px; padding: 16px; background-color: #0f111a; color: #ffffff; border-radius: 12px; border: 1px solid #1e293b;">
            <h3 style="margin-top: 0; margin-bottom: 8px; font-size: 16px; font-weight: 700; color: #38bdf8; border-bottom: 1px solid #334155; padding-bottom: 8px; letter-spacing: 0.5px;">REPORTER REGION: $countryName</h3>
            <p style="font-size: 13px; color: #94a3b8; margin-top: 0; margin-bottom: 12px;">This location submitted <b>${list.length}</b> report(s) against the source IP.</p>
            <div style="max-height: 220px; overflow-y: auto;">
              ${reportsListHtml.toString()}
            </div>
          </div>
        ]]></description>''';

        // Add reporter Placemark
        placemarksBuffer.write('''
    <Placemark>
      <name>Reporter Location: $countryName (${list.length} reports)</name>
      $reporterDescription
      <styleUrl>#reporterPoint</styleUrl>
      <Point>
        <coordinates>$rLon,$rLat,0</coordinates>
      </Point>
    </Placemark>''');

        // Draw parabolic curve (Attack Vector Line) from tracked IP (source) to reporter (victim target)
        final lineCoords = _generateParabolicCoordinates(sLat, sLon, rLat, rLon);
        placemarksBuffer.write('''
    <Placemark>
      <name>Vector Vector [#$lineId] to $countryCode</name>
      $reporterDescription
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
      });

      final kmlContent = '''<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>Tracked IP Attack vectors</name>
    
    <!-- Marker Style definitions -->
    <Style id="trackedIpPoint">
      <IconStyle>
        <scale>1.6</scale>
        <Icon>
          <href>http://maps.google.com/mapfiles/kml/paddle/red-square.png</href>
        </Icon>
      </IconStyle>
    </Style>
    
    <Style id="reporterPoint">
      <IconStyle>
        <scale>1.4</scale>
        <Icon>
          <href>http://maps.google.com/mapfiles/kml/paddle/wht-circle.png</href>
        </Icon>
      </IconStyle>
    </Style>
    
    <!-- Line Style definitions -->
    <Style id="attackLine">
      <LineStyle>
        <color>cc00a5ff</color> <!-- Semi-transparent orange (AABBGGRR) -->
        <width>4</width>
      </LineStyle>
    </Style>

    ${placemarksBuffer.toString()}
  </Document>
</kml>''';

      final uploadedName = await _lgService.uploadKml(kmlContent, 'track_ip.kml');
      if (uploadedName != null) {
        await _lgService.query('slave_1=http://lg1:81/$uploadedName');
      }

      // Fly to the tracked IP source centered on the screen
      final bearing = reportsByCountry.isNotEmpty
          ? _calculateBearing(sLat, sLon, reportsByCountry.values.first.first.reporterCountryCode.isNotEmpty
              ? CountryCoordinatesLookup.getCoordinate(reportsByCountry.values.first.first.reporterCountryCode).latitude
              : sLat + 15,
            reportsByCountry.values.first.first.reporterCountryCode.isNotEmpty
              ? CountryCoordinatesLookup.getCoordinate(reportsByCountry.values.first.first.reporterCountryCode).longitude
              : sLon + 15)
          : 0.0;

      final lookAt = '''<LookAt>
          <longitude>$sLon</longitude>
          <latitude>$sLat</latitude>
          <altitude>0</altitude>
          <heading>$bearing</heading>
          <tilt>45</tilt>
          <range>7000000</range>
          <gx:altitudeMode>relativeToGround</gx:altitudeMode>
        </LookAt>''';
      await _lgService.flyTo(lookAt);
      return true;
    } catch (e) {
      debugPrint('HoneyVision TrackIP LG Error: Failed to project KML: $e');
      return false;
    }
  }

  /// Writes text content directly to a remote file via SSH without touching kmls.txt.
  Future<bool> _writeFileDirectly(String content, String fileName) async {
    final command = "cat << 'EOF' > /var/www/html/$fileName\n$content\nEOF";
    return await _lgService.execute(command, 'Directly wrote file: $fileName');
  }

  /// Projects a premium dynamic text card onto the rightmost screen overlay.
  /// Generates an HTML card locally, takes a headless Chrome screenshot to output a PNG,
  /// and points a ScreenOverlay KML to that PNG. This avoids red crosses (as Google Earth does not support SVG).
  Future<bool> sendTrackIpOverlay(AbuseIpReport report) async {
    if (!_lgService.isConnected) return false;

    try {
      final rightMost = _lgService.calculateRightMostScreen(_lgService.connectionModel.screens);

      final severityColor = report.abuseConfidenceScore > 50
          ? '#ff4a5a'
          : report.abuseConfidenceScore > 20
              ? '#ff9f43'
              : '#1dd1a1';

      final badgeText = report.abuseConfidenceScore > 50
          ? 'HIGH RISK'
          : report.abuseConfidenceScore > 20
              ? 'MEDIUM RISK'
              : 'LOW RISK';

      final safeIsp = report.isp.replaceAll("'", "\\'").replaceAll('"', '\\"');
      final safeDomain = report.domain.replaceAll("'", "\\'").replaceAll('"', '\\"');
      final safeCountry = report.countryName.replaceAll("'", "\\'").replaceAll('"', '\\"');

      // 1. Generate the HTML card content
      final htmlContent = """<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <link href="https://fonts.googleapis.com/css2?family=Outfit:wght@400;700;900&display=swap" rel="stylesheet">
  <style>
    body {
      margin: 0;
      padding: 20px;
      background-color: #0f111a;
      color: #ffffff;
      font-family: 'Outfit', sans-serif;
      width: 400px;
      height: 350px;
      box-sizing: border-box;
      border: 3px solid #1e293b;
      border-radius: 16px;
      overflow: hidden;
    }
    .title {
      font-size: 16px;
      font-weight: 900;
      color: #38bdf8;
      letter-spacing: 1px;
      margin-bottom: 8px;
      text-transform: uppercase;
    }
    .divider {
      height: 1px;
      background-color: #334155;
      margin-bottom: 12px;
    }
    .ip {
      font-family: monospace;
      font-size: 24px;
      font-weight: bold;
      margin-bottom: 8px;
    }
    .badge {
      display: inline-block;
      padding: 3px 8px;
      border-radius: 4px;
      font-size: 10px;
      font-weight: bold;
      color: #ffffff;
      margin-bottom: 16px;
      text-transform: uppercase;
      text-align: center;
    }
    .info-row {
      display: flex;
      margin-bottom: 8px;
      font-size: 13px;
    }
    .info-label {
      width: 110px;
      color: #94a3b8;
      font-weight: bold;
    }
    .info-value {
      flex: 1;
      color: #f1f5f9;
    }
    .footer {
      font-size: 10px;
      color: #64748b;
      font-style: italic;
      margin-top: 15px;
    }
  </style>
</head>
<body>
  <div class="title">IP Tracker Analysis</div>
  <div class="divider"></div>
  <div class="ip">${report.ipAddress}</div>
  <div class="badge" style="background-color: $severityColor;">$badgeText</div>
  <div class="info-row">
    <div class="info-label">Country:</div>
    <div class="info-value">$safeCountry</div>
  </div>
  <div class="info-row">
    <div class="info-label">ISP:</div>
    <div class="info-value">${safeIsp.length > 30 ? safeIsp.substring(0, 27) + '...' : safeIsp}</div>
  </div>
  <div class="info-row">
    <div class="info-label">Domain:</div>
    <div class="info-value">${safeDomain.isEmpty ? 'N/A' : safeDomain}</div>
  </div>
  <div class="info-row">
    <div class="info-label">Confidence:</div>
    <div class="info-value" style="color: $severityColor; font-weight: bold;">${report.abuseConfidenceScore}%</div>
  </div>
  <div class="info-row">
    <div class="info-label">Total Reports:</div>
    <div class="info-value">${report.totalReports} reports</div>
  </div>
  <div class="footer">Close via App Controller</div>
</body>
</html>""";

      final randomNumber = DateTime.now().millisecondsSinceEpoch % 1000;
      final htmlFileName = 'track_ip_card_$randomNumber.html';
      final pngFileName = 'track_ip_card_$randomNumber.png';
      final overlayKmlName = 'track_ip_overlay_$randomNumber.kml';

      // 2. Write HTML file directly to Apache directory
      final htmlSuccess = await _writeFileDirectly(htmlContent, htmlFileName);
      if (!htmlSuccess) return false;

      // 3. Render HTML to PNG via headless Google Chrome/Chromium screenshot on the master node
      // We run in headless mode with --no-sandbox to work inside the SSH session context
      final chromeCommand = """
if command -v google-chrome &>/dev/null; then
  google-chrome --headless --no-sandbox --disable-gpu --screenshot=/var/www/html/$pngFileName --window-size=400,350 http://localhost:81/$htmlFileName
elif command -v google-chrome-stable &>/dev/null; then
  google-chrome-stable --headless --no-sandbox --disable-gpu --screenshot=/var/www/html/$pngFileName --window-size=400,350 http://localhost:81/$htmlFileName
elif command -v chromium-browser &>/dev/null; then
  chromium-browser --headless --no-sandbox --disable-gpu --screenshot=/var/www/html/$pngFileName --window-size=400,350 http://localhost:81/$htmlFileName
elif command -v chromium &>/dev/null; then
  chromium --headless --no-sandbox --disable-gpu --screenshot=/var/www/html/$pngFileName --window-size=400,350 http://localhost:81/$htmlFileName
fi
""";
      final screenshotSuccess = await _lgService.execute(chromeCommand, 'Captured card screenshot successfully');
      if (!screenshotSuccess) return false;

      // 4. Generate the ScreenOverlay KML pointing to the generated PNG
      final overlayKml = """<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Track IP Overlay</name>
    <ScreenOverlay>
      <name>Telemetry Overlay</name>
      <Icon>
        <href>http://lg1:81/$pngFileName</href>
      </Icon>
      <overlayXY x="1" y="1" xunits="fraction" yunits="fraction"/>
      <screenXY x="0.98" y="0.95" xunits="fraction" yunits="fraction"/>
      <size x="400" y="350" xunits="pixels" yunits="pixels"/>
    </ScreenOverlay>
  </Document>
</kml>""";

      // 5. Write the overlay KML directly to Apache directory
      final overlaySuccess = await _writeFileDirectly(overlayKml, overlayKmlName);
      if (!overlaySuccess) return false;

      // 6. Query the rightmost screen to point to this overlay KML
      await _lgService.query('slave_$rightMost=http://lg1:81/$overlayKmlName');

      // 7. Force screen to refresh so it loads immediately
      await _lgService.forceRefresh(rightMost);
      return true;
    } catch (e) {
      debugPrint('HoneyVision TrackIP LG Error: Failed to write overlay: $e');
      return false;
    }
  }

  /// Clears visual elements from both master map and rightmost overlay screen.
  Future<bool> clearTrackIpVisuals() async {
    if (!_lgService.isConnected) return false;

    try {
      final rightMost = _lgService.calculateRightMostScreen(_lgService.connectionModel.screens);

      const blankKml = """<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2">
  <Document>
    <name>Empty</name>
  </Document>
</kml>""";

      // 1. Clear slave 1 (master KML)
      await _lgService.query('slave_1=');

      // 2. Clear rightmost screen overlay by writing a blank KML file directly and pointing to it
      final blankKmlName = 'blank.kml';
      final success = await _writeFileDirectly(blankKml, blankKmlName);
      if (success) {
        await _lgService.query('slave_$rightMost=http://lg1:81/$blankKmlName');
      }

      // 3. Force refresh rightmost screen to apply the clear
      await _lgService.forceRefresh(rightMost);
      return true;
    } catch (e) {
      debugPrint('HoneyVision TrackIP LG Error: Failed to clear visuals: $e');
      return false;
    }
  }
}
