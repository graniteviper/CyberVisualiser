import 'package:flutter/material.dart';
import '../models/attack_event.dart';
import '../services/lg_adapter.dart';

class EventDetailsPanel extends StatelessWidget {
  final AttackEvent event;
  final LgAdapter lgAdapter;
  final bool isLgConnected;
  final Function(AttackEvent) onVisualize;

  const EventDetailsPanel({
    super.key,
    required this.event,
    required this.lgAdapter,
    required this.isLgConnected,
    required this.onVisualize,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sevColor = event.severity == 'Critical'
        ? Colors.redAccent
        : event.severity == 'High'
            ? Colors.orangeAccent
            : Colors.yellowAccent;

    return Dialog(
      backgroundColor: isDark ? const Color(0xFF0F111A) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: sevColor.withOpacity(0.5), width: 1.5),
      ),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 550),
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(Icons.shield_outlined, color: sevColor, size: 24),
                    const SizedBox(width: 8),
                    Text(
                      'ATTACK TELEMETRY',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.0,
                        color: isDark ? Colors.blue.shade200 : Colors.indigo.shade900,
                      ),
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const Divider(height: 20),

            // Content scroll area
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSectionHeader('EVENT METRIC'),
                    _buildInfoRow('Event ID', event.eventId, isMonospace: true),
                    _buildInfoRow('Timestamp (UTC)', event.timestamp.toIso8601String()),
                    _buildInfoRow('Severity', event.severity, valueColor: sevColor, isBold: true),

                    _buildSectionHeader('SOURCE INFO'),
                    _buildInfoRow('Source IP', event.sourceIp, isMonospace: true),
                    _buildInfoRow('Source Port', event.sourcePort.toString()),
                    if (event.sourceDomain.isNotEmpty)
                      _buildInfoRow('Source Domain', event.sourceDomain),
                    _buildInfoRow('Country', '${event.countryName} (${event.countryCode})'),
                    if (event.cityName.isNotEmpty)
                      _buildInfoRow('City Name', event.cityName),
                    _buildInfoRow('ASN Profile', 'AS${event.asnNumber} (${event.asnOrg})'),

                    _buildSectionHeader('TARGET INFO'),
                    _buildInfoRow('Target Port', event.destPort.toString(), isBold: true),
                    if (event.networkProtocol.isNotEmpty)
                      _buildInfoRow('Protocol', event.networkProtocol.toUpperCase()),
                    if (event.httpMethod.isNotEmpty)
                      _buildInfoRow('HTTP Method', event.httpMethod),
                    if (event.urlPath.isNotEmpty)
                      _buildInfoRow('Request Path', event.urlPath, isMonospace: true),
                    if (event.userAgent.isNotEmpty)
                      _buildInfoRow('User Agent', event.userAgent),
                    if (event.communityId.isNotEmpty)
                      _buildInfoRow('Corelight Flow Hash', event.communityId, isMonospace: true),
                  ],
                ),
              ),
            ),
            const Divider(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Close Details'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.send_rounded, size: 16),
                    label: const Text('VISUALIZE ON LG'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isLgConnected ? sevColor : Colors.grey,
                      foregroundColor: isLgConnected ? Colors.black : Colors.white,
                      elevation: 2,
                    ),
                    onPressed: isLgConnected
                        ? () {
                            Navigator.of(context).pop();
                            onVisualize(event);
                          }
                        : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: Colors.grey,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, {Color? valueColor, bool isMonospace = false, bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontFamily: isMonospace ? 'monospace' : null,
                fontWeight: isBold ? FontWeight.bold : null,
                color: valueColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
