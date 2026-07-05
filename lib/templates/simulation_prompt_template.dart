class SimulationPromptTemplate {
  /// Generates a prompt guiding Gemini to output only valid KML for simulating attack scenarios.
  static String buildSimulationPrompt(String userPrompt) {
    return '''
You are an expert GIS and Cyber Security visualization assistant.
Your task is to generate a valid KML (Keyhole Markup Language) file that simulates a cyber attack scenario based on the user's description.

User request: "$userPrompt"

### INSTRUCTIONS:
1. Generate a valid KML file wrapped in a markdown XML block:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<kml xmlns="http://www.opengis.net/kml/2.2" xmlns:gx="http://www.google.com/kml/ext/2.2">
  <Document>
    <name>Attack Simulation</name>
    <LookAt>
      <longitude>[target_longitude]</longitude>
      <latitude>[target_latitude]</latitude>
      <altitude>0</altitude>
      <heading>0</heading>
      <tilt>45</tilt>
      <range>8000000</range>
      <gx:altitudeMode>relativeToGround</gx:altitudeMode>
    </LookAt>
    <!-- Add styles and placemarks here -->
  </Document>
</kml>
```
2. The KML must contain:
   - A `<LookAt>` tag inside `<Document>` pointing to the coordinates of the target/victim of the attack, so that Google Earth zooms in on it automatically.
   - Appropriate Style definitions for:
     - Target node: e.g. blue/white square or circle icon (`http://maps.google.com/mapfiles/kml/paddle/wht-circle.png` or `http://maps.google.com/mapfiles/kml/paddle/blu-circle.png`).
     - Attacker nodes: e.g. red square or circle icon (`http://maps.google.com/mapfiles/kml/paddle/red-circle.png` or `http://maps.google.com/mapfiles/kml/paddle/red-square.png`).
     - Attack lines/vectors: e.g. red/orange styled LineString (`<LineStyle><color>cc00a5ff</color><width>4</width></LineStyle>`).
   - Placemarks for:
     - The target (victim server) positioned at the destination coordinates.
     - Multiple attackers (sources) positioned at the coordinates representing the origin locations of the attack.
     - LineString placemarks connecting each attacker to the target, representing attack paths (lines from attacker to target).
3. Translate location names from the user prompt into real/approximate geographic coordinates. For example, "a server based in usa" should place the target in the USA (e.g. longitude -95.7129, latitude 37.0902). If no location is specified, choose logical locations.
4. Ensure the coordinates are valid longitude,latitude,altitude (e.g. -95.7129,37.0902,0). Note that KML uses `longitude,latitude,altitude` order. Do not mix up longitude and latitude.
5. Do not include any explanations, introduction, markdown descriptions, or warnings. Return ONLY the xml block.
''';
  }
}
