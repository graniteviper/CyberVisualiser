class SimulationPromptTemplate {
  /// Generates a prompt guiding Gemini to output structured JSON for simulating attack scenarios.
  static String buildSimulationPrompt(String userPrompt) {
    return '''
You are an expert GIS and Cyber Security simulation intelligence agent.
Your task is to generate a structured JSON object representing a cyber attack scenario based on the user's description.

User request: "$userPrompt"

### JSON SCHEMA:
Return a single JSON object with the following structure:
{
  "scenarioName": "string (A short, descriptive name for the simulation, e.g., 'SYN Flood DDoS from East Asia')",
  "target": {
    "name": "string (name of the target server/infrastructure, e.g., 'US Central DB Server')",
    "locationName": "string (country or city name of target)",
    "latitude": number (floating point latitude of the target),
    "longitude": number (floating point longitude of the target),
    "ip": "string (a realistic IP address for the target, e.g., 198.51.100.42)",
    "description": "string (brief description of the target server, e.g., 'Main database server hosting client accounts')"
  },
  "attackers": [
    {
      "name": "string (name/label for this attacker node, e.g., 'Attacker Node 1')",
      "locationName": "string (country or city name of the attacker location)",
      "latitude": number (floating point latitude),
      "longitude": number (floating point longitude),
      "ip": "string (a realistic source IP address, e.g., 203.0.113.8)",
      "threatType": "string (e.g., 'DDoS traffic', 'SSH Brute-Force', 'SQL Injection exploit')",
      "severity": "string (LOW, MEDIUM, HIGH, or CRITICAL)",
      "description": "string (brief description of this specific attack vector, e.g., 'Botnet SYN flooding at 10 Gbps')"
    }
  ]
}

### GEOGRAPHIC COORDS REFERENCE GUIDE:
Translate location names from the user prompt into real or approximate coordinates:
- United States / USA: latitude 37.0902, longitude -95.7129
- China: latitude 35.8617, longitude 104.1954
- Russia: latitude 61.5240, longitude 105.3188
- Germany: latitude 51.1657, longitude 10.4515
- India: latitude 20.5937, longitude 78.9629
- Brazil: latitude -14.2350, longitude -51.9253
- United Kingdom / UK: latitude 55.3781, longitude -3.4360
- France: latitude 46.2276, longitude 2.2137
- Japan: latitude 36.2048, longitude 138.2529
- Canada: latitude 56.1304, longitude -106.3468
- Australia: latitude -25.2744, longitude 133.7751
- South Africa: latitude -30.5595, longitude 22.9375
- South America: (e.g. Brazil -14.2350, -51.9253)
- East Europe: (e.g. Ukraine 48.3794, 31.1656)
- Africa: (e.g. Kenya -1.2921, 36.8219 or Nigeria 9.0820, 8.6753)

If no location is specified or you need to select coordinates, pick logical geographic locations.
Always ensure latitude is within [-90.0, 90.0] and longitude is within [-180.0, 180.0]. Note that longitude and latitude must not be swapped.

### CONSTRAINTS:
1. Generate between 2 to 5 attacker nodes to make the simulation visually rich and interesting on the map.
2. Output ONLY the JSON block wrapped in a markdown code block:
```json
{ ... }
```
Do not include any explanations, introduction, markdown descriptions, or warnings. Return ONLY the json block.
''';
  }
}
