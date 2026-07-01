import '../models/abuse_report_model.dart';

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
}
