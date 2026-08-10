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
      logBuffer.writeln('- Region: $countryName ($countryCode) - ${list.length} report(s). Details:');
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
}
