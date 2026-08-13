import '../models/abuse_report_model.dart';
import '../models/attack_event.dart';
import '../features/historical/models/historical_attack.dart';

class GeminiPromptTemplate {
  /// Generates a detailed prompt to be sent to Gemini for threat intelligence summary
  static String fillAttackAnalysisTemplate(AbuseIpReport report) {
    final latestReports = report.reports.take(10).toList();

    final StringBuffer logBuffer = StringBuffer();
    for (int i = 0; i < latestReports.length; i++) {
      final item = latestReports[i];
      logBuffer.writeln('Report #${i + 1}:');
      logBuffer.writeln('  Date: ${item.reportedAt.toIso8601String()}');
      logBuffer.writeln(
        '  Country: ${item.reporterCountryName.isNotEmpty ? item.reporterCountryName : item.reporterCountryCode}',
      );
      logBuffer.writeln('  Categories: ${item.categoryNames.join(', ')}');
      logBuffer.writeln(
        '  Comment: ${item.comment.isNotEmpty ? item.comment : "No comment"}',
      );
      logBuffer.writeln('');
    }

    return '''
You are an expert cyber threat intelligence analyst. Analyse the following IP address traffic telemetry and abuse reports.
Write a clear, professional, and descriptive threat summary of this attack source, including potential malicious campaigns, attack types (e.g. brute force, port scan, botnet), and security recommendations.

--- TARGET INTEL SUMMARY ---
IP Address: ${report.ipAddress}
IP Version: IPv${report.ipVersion}
ISP: ${report.isp}
Domain: ${report.domain.isNotEmpty ? report.domain : "N/A"}
Geographic Location: ${report.countryName} (${report.countryCode})
Abuse Confidence Score: ${report.abuseConfidenceScore}%
Total Registered Abuse Reports: ${report.totalReports}
Distinct Reporters: ${report.numDistinctUsers}

--- LATEST ATTACK REPORTS / TELEMETRY LOGS (Max 10) ---
${logBuffer.isNotEmpty ? logBuffer.toString() : "No details reported."}

--- ANALYSIS INSTRUCTIONS ---
Please write a concise threat intelligence report. Use Markdown headings (e.g. '##') for each section to structure your response so it can be parsed correctly.
Follow this structure:

## Threat Profile
Provide a paragraph describing the primary attack vectors, malicious intent, and threat score assessment.

## Behavioral Assessment
Provide a paragraph analyzing the frequency, timeline, and patterns from the telemetry comments.

## Actionable Recommendations
Provide a bulleted list of specific, actionable defense measures (e.g. firewall blocking, fail2ban rules, credential updates).

Keep it professional, structured with Markdown headers and bullet points, and concise. Do not mention meta instructions or warnings in your output.
''';
  }

  /// Generates a prompt to instruct Gemini to write a step-by-step narrative script for a 3D tour.
  static String fillTourScriptPrompt(AbuseIpReport report) {
    final Map<String, List<AbuseReportItem>> reportsByCountry = {};
    for (final r in report.reports) {
      if (r.reporterCountryCode.isNotEmpty) {
        reportsByCountry.putIfAbsent(r.reporterCountryCode, () => []).add(r);
      }
    }

    final StringBuffer logBuffer = StringBuffer();
    reportsByCountry.forEach((countryCode, list) {
      final countryName = list.first.reporterCountryName.isNotEmpty
          ? list.first.reporterCountryName
          : countryCode;
      logBuffer.writeln(
        '- Region: $countryName ($countryCode) - ${list.length} report(s). Details:',
      );
      for (var item in list.take(2)) {
        logBuffer.writeln('  * Categories: ${item.categoryNames.join(", ")}');
        if (item.comment.trim().isNotEmpty) {
          logBuffer.writeln('  * Comment: ${item.comment.trim()}');
        }
      }
    });

    return '''
You are an expert cyber threat intelligence narrator. You are generating a script for a 3D audio-visual camera tour of a tracked IP on a map.
The tour consists of 3 stages:
1. Target Overview: Introduction to the malicious source IP and its general characteristics.
2. Reporter Regions: Visiting locations on the globe that reported this IP, describing their logs and comments.
3. Tour Conclusion: A summary of the threat level, attribution, and defense recommendations.

Here is the telemetry data:
- IP Address: ${report.ipAddress}
- ISP: ${report.isp}
- Domain: ${report.domain.isNotEmpty ? report.domain : "N/A"}
- Origin Country: ${report.countryName} (${report.countryCode})
- Abuse Confidence Score: ${report.abuseConfidenceScore}%
- Total Reports: ${report.totalReports}

Geographic reports submitted against this IP:
${logBuffer.isNotEmpty ? logBuffer.toString() : "No reports logged."}

INSTRUCTIONS:
Generate a clean JSON object containing the narration script for each tour step.
The output MUST be a valid JSON object only. Do NOT enclose it in markdown blocks like ```json ... ```. Just return the raw JSON text.
Ensure all quotes are escaped properly. The JSON must strictly match this schema:
{
  "overview": "Narration script for the IP overview. Introduce the IP address, ISP, origin, and threat severity.",
  "regions": [
    {
      "countryCode": "US", // Match from telemetry country codes
      "narration": "Narration script specifically discussing the attacks/reports from this region, using the details provided above."
    }
  ],
  "conclusion": "Narration script summarizing the threat level and giving recommendations."
}
''';
  }

  /// Generates a prompt to instruct Gemini to write a step-by-step narrative script for a simulation 3D tour.
  static String fillSimulationTourScriptPrompt(Map<String, dynamic> simData) {
    final String scenarioName = simData['scenarioName'] ?? 'Attack Simulation';
    final String summary = simData['summary'] ?? '';
    final Map<String, dynamic> target = simData['target'] ?? {};
    final List<dynamic> attackers = simData['attackers'] ?? [];

    final StringBuffer attackersBuffer = StringBuffer();
    for (var attacker in attackers) {
      if (attacker is Map<String, dynamic>) {
        attackersBuffer.writeln(
          '- Attacker: ${attacker['name']} (${attacker['locationName']})',
        );
        attackersBuffer.writeln('  * IP: ${attacker['ip']}');
        attackersBuffer.writeln(
          '  * Threat: ${attacker['threatType']} (${attacker['severity']})',
        );
        attackersBuffer.writeln('  * Details: ${attacker['description']}');
      }
    }

    return '''
You are an expert cyber threat intelligence narrator. You are generating a script for a 3D audio-visual camera tour of a simulated cyber attack scenario.
The tour stages:
1. Target Infrastructure: Introduction to the victim server/infrastructure.
2. Attacker Nodes: Visiting each individual attacker node on the globe, describing their threat details.
3. Summary & Mitigation: A conclusion explaining the final outcome and recommendations.

Here is the simulation data:
- Scenario: $scenarioName
- Scenario Summary: $summary
- Target Server: ${target['name']} (${target['locationName']})
  * IP: ${target['ip']}
  * Description: ${target['description']}

Attacker Nodes:
${attackersBuffer.toString()}

INSTRUCTIONS:
Generate a clean JSON object containing the narration script for each tour step.
The output MUST be a valid JSON object only. Do NOT enclose it in markdown blocks like ```json ... ```. Just return the raw JSON text.
Ensure all quotes are escaped properly. The JSON must strictly match this schema:
{
  "overview": "Narration script for the target server and scenario overview. Introduce the target server, its location, and the general attack threat.",
  "attackers": [
    {
      "nodeName": "Attacker Node 1", // Match from attackers name in simulation data
      "narration": "Narration script discussing the attack vector from this specific node, using details from the simulation data."
    }
  ],
  "conclusion": "Narration script summarizing the overall scenario and security recommendation."
}
''';
  }

  /// Generates a detailed prompt to summarize recent events of a specific attack category using Gemini
  static String fillCategoryAnalysisTemplate(
    String category,
    List<AttackEvent> events,
  ) {
    final StringBuffer logBuffer = StringBuffer();
    for (int i = 0; i < events.length; i++) {
      final event = events[i];
      logBuffer.writeln('Event #${i + 1}:');
      logBuffer.writeln('  Time: ${event.timestamp.toIso8601String()}');
      logBuffer.writeln('  Source IP: ${event.sourceIp}');
      logBuffer.writeln(
        '  Location: ${event.cityName.isNotEmpty ? "${event.cityName}, " : ""}${event.countryName.isNotEmpty ? event.countryName : (event.countryCode.isNotEmpty ? event.countryCode : "Unknown")}',
      );
      logBuffer.writeln('  ASN: AS${event.asnNumber} (${event.asnOrg})');
      logBuffer.writeln('  Target Port: ${event.destPort}');
      logBuffer.writeln('  Protocol: ${event.networkProtocol.toUpperCase()}');
      if (event.httpMethod.isNotEmpty)
        logBuffer.writeln('  HTTP Method: ${event.httpMethod}');
      if (event.urlPath.isNotEmpty)
        logBuffer.writeln('  URL Path: ${event.urlPath}');
      if (event.userAgent.isNotEmpty)
        logBuffer.writeln('  User Agent: ${event.userAgent}');
      logBuffer.writeln('  Severity: ${event.severity}');
      logBuffer.writeln('');
    }

    return '''
You are an expert cyber threat intelligence analyst. You are provided with the top ${events.length} recent cyber attack events categorized under the "$category" type of attack.
Analyze these events and write a structured, professional, and clear threat intelligence summary.

--- EVENT TELEMETRY LOGS ---
${logBuffer.isNotEmpty ? logBuffer.toString() : "No events recorded."}

--- ANALYSIS INSTRUCTIONS ---
Please write a concise threat intelligence report. Use Markdown headings (e.g. '##') for each section to structure your response.
Follow this structure exactly:

## Executive Summary
Provide a high-level overview of the activity in the "$category" category, detailing the scale, frequency, and severity of the observed threats.

## Geographic & Network Analysis
Identify geographic concentrations (countries, regions) and ISP/ASN networks responsible for these attacks. Mention target ports/protocols and highlight any suspicious patterns or commonalities.

## Actionable Recommendations
Provide a list of specific, actionable defense measures (such as firewall rules, rate limiting, port configuration, or updates) to mitigate this activity.

Keep the tone highly professional, concise, and structured with Markdown headers and bullet points. Do not output meta-commentary, introductory filler, or AI boilerplate.
''';
  }

  /// Generates a detailed prompt to ask Gemini about a specific historical attack incident.
  static String fillHistoricalAttackPrompt(
    HistoricalAttack attack,
    String userQuestion,
  ) {
    return '''
You are an expert cyber threat intelligence analyst. You are assisting a security operations center team with information on a specific historical cyber security incident from our database.

Here are the details of the attack:
- Title: ${attack.title}
- Date: ${attack.month} ${attack.year} (${attack.date})
- Victim: ${attack.victim.name} (Country: ${attack.victim.country}, Sector: ${attack.attack.targetSector})
- Attacker: ${attack.attacker.name} (Type: ${attack.attacker.type})
- Attack Category: ${attack.attack.category} (Severity: ${attack.attack.severity}/10)
- Summary: ${attack.summary}
- Source: ${attack.source.name} (Year: ${attack.source.year})
- Tags: ${attack.tags.join(', ')}

The user has the following question or request:
"$userQuestion"

Please write a structured, informative, and professional answer based on this incident. Use Markdown headings (e.g. '##') and bullet points where appropriate. Keep the response concise, authoritative, and helpful. Do not output meta instructions or AI boilerplate.
''';
  }

  /// Generates a prompt to ask Gemini about attacks in a particular year, category, or general historical data.
  static String fillHistoricalContextPrompt({
    int? year,
    String? category,
    required List<HistoricalAttack> contextAttacks,
    required String userQuestion,
  }) {
    final StringBuffer logBuffer = StringBuffer();
    for (int i = 0; i < contextAttacks.length; i++) {
      final item = contextAttacks[i];
      logBuffer.writeln('Incident #${i + 1}:');
      logBuffer.writeln('  Title: ${item.title}');
      logBuffer.writeln('  Date: ${item.month} ${item.year}');
      logBuffer.writeln(
        '  Victim: ${item.victim.name} (Country: ${item.victim.country}, Sector: ${item.attack.targetSector})',
      );
      logBuffer.writeln(
        '  Attacker: ${item.attacker.name} (${item.attacker.type})',
      );
      logBuffer.writeln(
        '  Category: ${item.attack.category} (Severity: ${item.attack.severity}/10)',
      );
      logBuffer.writeln('  Summary: ${item.summary}');
      logBuffer.writeln('');
    }

    String scopeText = "";
    if (year != null && category != null) {
      scopeText =
          "attacks that happened in the year $year and categorized as $category";
    } else if (year != null) {
      scopeText = "attacks that happened in the year $year";
    } else if (category != null) {
      scopeText = "attacks of type $category";
    } else {
      scopeText = "historical cyber attacks";
    }

    return '''
You are an expert cyber threat intelligence analyst. You are assisting a security analyst by answering questions about $scopeText.
Here is the context representing relevant cyber incidents from our database:

--- DATABASE INCIDENTS (Max 10) ---
${logBuffer.isNotEmpty ? logBuffer.toString() : "No matching database records found."}

The user has the following question/request:
"$userQuestion"

Please synthesize your reply using both the provided database incidents and your general threat intelligence knowledge. Provide a clear, professional, and structured analysis of the cyber security landscape regarding this query.
Use Markdown formatting (e.g., '##' headers, bullet points, bold text). Keep it concise, professional, and action-oriented. Do not include AI helper commentary or meta explanations.
''';
  }

  /// Generates a prompt for a single historical cyber attack visualization and tour.
  static String fillHistoricalAttackTourPrompt(HistoricalAttack attack) {
    return '''
You are an expert GIS and Cyber Security simulation intelligence agent.
Your task is to generate a structured JSON object representing a 3D tour and visualization payload for the following historical cyber attack:

Attack Details:
- Title: ${attack.title}
- Date: ${attack.month} ${attack.year}
- Victim: ${attack.victim.name} (Country: ${attack.victim.country}, Location: ${attack.victim.latitude}, ${attack.victim.longitude})
- Attacker: ${attack.attacker.name} (Type: ${attack.attacker.type})
- Category: ${attack.attack.category} (Severity: ${attack.attack.severity}/10)
- Summary: ${attack.summary}

Since the attacker's coordinates are not specified in our database, please determine a realistic geographical origin (latitude and longitude) for the attacker '${attack.attacker.name}' based on their threat profile, origin records, or general attribution.

### JSON SCHEMA:
Return a single JSON object with this exact structure:
{
  "attacker": {
    "name": "string (Attacker Group name, e.g. ${attack.attacker.name})",
    "locationName": "string (Attacker country or region name)",
    "latitude": number (floating point latitude),
    "longitude": number (floating point longitude),
    "description": "string (brief description of this threat actor)"
  },
  "victim": {
    "name": "string (Victim name, e.g. ${attack.victim.name})",
    "locationName": "string (${attack.victim.country})",
    "latitude": ${attack.victim.latitude},
    "longitude": ${attack.victim.longitude},
    "description": "string (brief description of the victim)"
  },
  "summary": "string (concise summary of the attack event)",
  "tour": {
    "overview": "string (audio narration text summarizing the attack, victim, and threat actor)",
    "steps": [
      {
        "title": "string (Title of the step, e.g. 'Threat Actor Origin')",
        "latitude": number (latitude of camera focus),
        "longitude": number (longitude of camera focus),
        "range": number (camera altitude range in meters, e.g. 1500000),
        "tilt": number (camera tilt in degrees, e.g. 45),
        "narration": "string (narration text spoken for this step)"
      }
    ],
    "conclusion": "string (final narration summarizing mitigations and security takeaways)"
  }
}

### TOUR STEPS INSTRUCTIONS:
Create exactly 3 steps for the tour:
1. Step 1: Fly to and focus on the attacker's location, narrating details about the threat group and their history.
2. Step 2: Fly to the midpoint between the attacker and victim, narrating the mechanism of attack (e.g. category: ${attack.attack.category}) and how the compromise occurred.
3. Step 3: Fly to and focus on the victim's location, narrating the impact, recovery efforts, and severity of the incident.

### CONSTRAINTS:
1. Output ONLY the JSON block wrapped in a markdown code block:
```json
{ ... }
```
Do not include any explanation or intro text outside the markdown code block.
''';
  }

  /// Generates a prompt for a category of historical attacks (top 10).
  static String fillHistoricalCategoryTourPrompt(
    String categoryName,
    List<HistoricalAttack> attacks,
  ) {
    final latestAttacks = attacks.take(10).toList();
    final StringBuffer logBuffer = StringBuffer();
    for (int i = 0; i < latestAttacks.length; i++) {
      final a = latestAttacks[i];
      logBuffer.writeln('Incident #${i + 1}:');
      logBuffer.writeln('  Title: ${a.title}');
      logBuffer.writeln('  Date: ${a.month} ${a.year}');
      logBuffer.writeln(
        '  Victim: ${a.victim.name} (Country: ${a.victim.country}, Coordinates: ${a.victim.latitude}, ${a.victim.longitude})',
      );
      logBuffer.writeln(
        '  Attacker: ${a.attacker.name} (Type: ${a.attacker.type})',
      );
      logBuffer.writeln(
        '  Category: ${a.attack.category} (Severity: ${a.attack.severity}/10)',
      );
      logBuffer.writeln('  Summary: ${a.summary}');
      logBuffer.writeln('');
    }

    return '''
You are an expert GIS and Cyber Security simulation intelligence agent.
Your task is to generate a structured JSON object representing a 3D tour and combined visualization payload for a category of historical cyber attacks.

Category Context / Query: "$categoryName"

Here are the details of the top ${latestAttacks.length} cyber attacks in this category:
${logBuffer.toString()}

Please determine a realistic geographical origin (latitude and longitude) for each attack's attacker based on their threat profile or historical records.

### JSON SCHEMA:
Return a single JSON object with this exact structure:
{
  "scenarioName": "string (A descriptive name, e.g. 'Historical Tour: $categoryName')",
  "summary": "string (A concise summary of the attacks in this category, explicitly mentioning that this tour is generated using the top ${latestAttacks.length} attacks to optimize token usage.)",
  "attacks": [
    {
      "title": "string (matching the attack title)",
      "attacker": {
        "name": "string (Attacker group name)",
        "locationName": "string (Attacker country or region)",
        "latitude": number (floating point latitude),
        "longitude": number (floating point longitude),
        "description": "string (brief description of threat group)"
      },
      "victim": {
        "name": "string (Victim name)",
        "locationName": "string (Victim country)",
        "latitude": number (victim latitude),
        "longitude": number (victim longitude),
        "description": "string (brief description of victim)"
      }
    }
  ],
  "tour": {
    "overview": "string (audio narration introducing this category tour, explicitly stating that it walks through ${latestAttacks.length} selected attacks to stay within token limits)",
    "steps": [
      {
        "title": "string (e.g. 'Compromise of [Victim]')",
        "latitude": number (latitude to focus camera, e.g. victim or attacker latitude),
        "longitude": number (longitude to focus camera),
        "range": number (camera range, e.g. 2000000),
        "tilt": number (camera tilt, e.g. 45),
        "narration": "string (speech narration for this step, summarizing the specific attack)"
      }
    ],
    "conclusion": "string (final narration summarizing the threat landscape and general defense recommendations for this category)"
  }
}

### TOUR STEPS INSTRUCTIONS:
1. Provide an overview step that focuses on a global view (latitude 0, longitude 0, range 8000000, tilt 0).
2. Generate one step for each of the ${latestAttacks.length} attacks, focusing on either the victim or the midpoint, narrating the specifics of that incident.
3. Provide a conclusion step.

### CONSTRAINTS:
1. Output ONLY the JSON block wrapped in a markdown code block:
```json
{ ... }
```
Do not include any explanation or intro text outside the markdown code block.
''';
  }

  /// Generates a prompt for a single live threat event visualization and tour.
  static String fillLiveAttackTourPrompt({
    required AttackEvent event,
    required double sourceLat,
    required double sourceLon,
    required double targetLat,
    required double targetLon,
    required String targetCountry,
  }) {
    return '''
You are an expert GIS and Cyber Security simulation intelligence agent.
Your task is to generate a structured JSON object representing a 3D tour and visualization payload for the following live cyber attack event:

Attack Details:
- Event ID: ${event.eventId}
- Timestamp: ${event.timestamp.toIso8601String()}
- Source IP: ${event.sourceIp}
- Attacker Location: ${event.cityName.isNotEmpty ? event.cityName + ", " : ""}${event.countryName} ($sourceLat, $sourceLon)
- Target Location: $targetCountry ($targetLat, $targetLon)
- Target Port: ${event.destPort} (Protocol: ${event.networkProtocol})
- Severity: ${event.severity}

### JSON SCHEMA:
Return a single JSON object with this exact structure:
{
  "attacker": {
    "name": "string (Attacker Node / Group name, e.g. 'Threat Node ${event.countryCode}')",
    "locationName": "string (${event.countryName})",
    "latitude": $sourceLat,
    "longitude": $sourceLon,
    "description": "string (brief description of this attacker origin)"
  },
  "victim": {
    "name": "string (Target Server name)",
    "locationName": "string ($targetCountry)",
    "latitude": $targetLat,
    "longitude": $targetLon,
    "description": "string (brief description of the target, e.g., destination port ${event.destPort} hosting ${event.networkProtocol})"
  },
  "summary": "string (concise summary of the attack event)",
  "tour": {
    "overview": "string (audio narration text summarizing the attack source, destination port, and threat severity)",
    "steps": [
      {
        "title": "string (Title of the step, e.g. 'Threat Source')",
        "latitude": number (latitude of camera focus),
        "longitude": number (longitude of camera focus),
        "range": number (camera altitude range in meters, e.g. 2000000),
        "tilt": number (camera tilt in degrees, e.g. 45),
        "narration": "string (narration text spoken for this step)"
      }
    ],
    "conclusion": "string (final narration summarizing mitigations and security takeaways)"
  }
}

### TOUR STEPS INSTRUCTIONS:
Create exactly 3 steps for the tour:
1. Step 1: Fly to and focus on the attacker's location, narrating details about the threat origin.
2. Step 2: Fly to the midpoint between the attacker and victim, narrating the attack mechanism (e.g. port ${event.destPort} over protocol ${event.networkProtocol}).
3. Step 3: Fly to and focus on the victim's location, narrating the severity: ${event.severity} and recommendations.

### CONSTRAINTS:
1. Output ONLY the JSON block wrapped in a markdown code block:
```json
{ ... }
```
Do not include any explanation or intro text outside the markdown code block.
''';
  }

  /// Generates a prompt for a category group of live threat events (top 10).
  static String fillLiveCategoryTourPrompt({
    required String categoryName,
    required List<AttackEvent> events,
    required double targetLat,
    required double targetLon,
    required String targetCountry,
  }) {
    final latestEvents = events.take(10).toList();
    final StringBuffer logBuffer = StringBuffer();
    for (int i = 0; i < latestEvents.length; i++) {
      final e = latestEvents[i];
      logBuffer.writeln('Event #${i + 1}:');
      logBuffer.writeln('  Source IP: ${e.sourceIp}');
      logBuffer.writeln(
        '  Location: ${e.cityName.isNotEmpty ? e.cityName + ", " : ""}${e.countryName} (${e.countryCode})',
      );
      logBuffer.writeln(
        '  Target Port: ${e.destPort} (Protocol: ${e.networkProtocol})',
      );
      logBuffer.writeln('  Severity: ${e.severity}');
      logBuffer.writeln('');
    }

    return '''
You are an expert GIS and Cyber Security simulation intelligence agent.
Your task is to generate a structured JSON object representing a 3D tour and combined visualization payload for a category of live cyber attack events.

Category Context: "$categoryName"
Target Destination: $targetCountry ($targetLat, $targetLon)

Here are the details of the top ${latestEvents.length} events in this category:
${logBuffer.toString()}

### JSON SCHEMA:
Return a single JSON object with this exact structure:
{
  "scenarioName": "string (A descriptive name, e.g. 'Live Tour: $categoryName')",
  "summary": "string (A concise summary of the attacks in this category, explicitly mentioning that this tour uses only the top ${latestEvents.length} attacks to optimize token usage.)",
  "attacks": [
    {
      "title": "string (matching the attack title, e.g. 'Threat from ${latestEvents.first.countryCode}')",
      "attacker": {
        "name": "string (Attacker node name)",
        "locationName": "string (Attacker country)",
        "latitude": number (floating point latitude),
        "longitude": number (floating point longitude),
        "description": "string (brief description of threat)"
      },
      "victim": {
        "name": "string (Target server)",
        "locationName": "string ($targetCountry)",
        "latitude": $targetLat,
        "longitude": $targetLon,
        "description": "string (brief description of target)"
      }
    }
  ],
  "tour": {
    "overview": "string (audio narration introducing this category tour, explicitly stating that it walks through ${latestEvents.length} selected attacks to stay within token limits)",
    "steps": [
      {
        "title": "string (e.g. 'Threat from [Location]')",
        "latitude": number (latitude to focus camera),
        "longitude": number (longitude to focus camera),
        "range": number (camera range, e.g. 2000000),
        "tilt": number (camera tilt, e.g. 45),
        "narration": "string (speech narration for this step, summarizing the specific attack)"
      }
    ],
    "conclusion": "string (final narration summarizing the threat landscape and general defense recommendations for this category)"
  }
}

### TOUR STEPS INSTRUCTIONS:
1. Provide an overview step that focuses on a global view (latitude 0, longitude 0, range 8000000, tilt 0).
2. Generate one step for each of the ${latestEvents.length} attacks, focusing on the attacker or the victim, narrating the details of that incident.
3. Provide a conclusion step.

### CONSTRAINTS:
1. Output ONLY the JSON block wrapped in a markdown code block:
```json
{ ... }
```
Do not include any explanation or intro text outside the markdown code block.
''';
  }
}
