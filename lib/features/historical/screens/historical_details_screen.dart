import 'package:flutter/material.dart';
import '../models/historical_attack.dart';

/// Screen displaying the full details of a specific historical cyber incident.
class HistoricalDetailsScreen extends StatelessWidget {
  final HistoricalAttack attack;

  const HistoricalDetailsScreen({super.key, required this.attack});

  /// Helper to return a semantic color corresponding to severity.
  Color _getSeverityColor(int severity) {
    if (severity >= 9) return const Color(0xFFD32F2F); // Critical (Red)
    if (severity >= 7) return const Color(0xFFF57C00); // High (Orange)
    if (severity >= 4) return const Color(0xFFFBC02D); // Medium (Yellow)
    return const Color(0xFF388E3C); // Low (Green)
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final severityColor = _getSeverityColor(attack.attack.severity);

    return Scaffold(
      appBar: AppBar(title: const Text('INCIDENT DETAILS'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Text(
              attack.title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),

            // Date, Category, and Severity Badges
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                // Date Chip
                _buildInfoBadge(
                  context,
                  icon: Icons.calendar_today_outlined,
                  label: '${attack.month} ${attack.year}',
                  color: isDark ? Colors.cyanAccent : Colors.indigo,
                ),
                // Category Chip
                _buildInfoBadge(
                  context,
                  icon: Icons.category_outlined,
                  label: attack.attack.category,
                  color: Colors.orange,
                ),
                // Severity Chip
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: severityColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: severityColor.withOpacity(0.4)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: severityColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Severity ${attack.attack.severity}/10',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: severityColor,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 32),

            // Victim Profile Section
            _buildSectionHeader(context, 'Victim Information', Icons.business),
            const SizedBox(height: 12),
            _buildInfoCard(
              context,
              isDark: isDark,
              children: [
                _buildDetailsRow('Organization', attack.victim.name),
                _buildDetailsRow('Country', attack.victim.country),
                _buildDetailsRow('Country Code', attack.victim.countryCode),
                _buildDetailsRow(
                  'Location',
                  'Lat: ${attack.victim.latitude.toStringAsFixed(4)}, Lon: ${attack.victim.longitude.toStringAsFixed(4)}',
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Attacker Profile Section
            _buildSectionHeader(
              context,
              'Attacker Information',
              Icons.person_outline,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              context,
              isDark: isDark,
              children: [
                _buildDetailsRow('Attacker Name', attack.attacker.name),
                _buildDetailsRow('Attacker Type', attack.attacker.type),
              ],
            ),
            const SizedBox(height: 24),

            // Attack Profile Details
            _buildSectionHeader(
              context,
              'Incident Profile',
              Icons.analytics_outlined,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              context,
              isDark: isDark,
              children: [
                _buildDetailsRow('Target Sector', attack.attack.targetSector),
                _buildDetailsRow(
                  'Impact Severity',
                  '${attack.attack.severity} / 10',
                ),
                _buildDetailsRow('Categorization', attack.attack.category),
              ],
            ),
            const SizedBox(height: 24),

            // Incident Summary Narrative
            _buildSectionHeader(
              context,
              'Narrative Summary',
              Icons.description_outlined,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF161925) : Colors.grey.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? Colors.blueGrey.shade900.withOpacity(0.5)
                      : Colors.grey.shade200,
                ),
              ),
              child: Text(
                attack.summary,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  height: 1.5,
                  color: isDark ? Colors.grey.shade300 : Colors.black87,
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Tags Section
            if (attack.tags.isNotEmpty) ...[
              _buildSectionHeader(
                context,
                'Identified Tags',
                Icons.local_offer_outlined,
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: attack.tags.map((tag) {
                  return Chip(
                    label: Text(tag),
                    labelStyle: const TextStyle(fontSize: 12),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    backgroundColor: isDark
                        ? const Color(0xFF1F2336)
                        : Colors.grey.shade100,
                    side: BorderSide(
                      color: isDark
                          ? Colors.blueGrey.shade800
                          : Colors.grey.shade300,
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
            ],

            // Source Attribution
            _buildSectionHeader(
              context,
              'Source Attribution',
              Icons.source_outlined,
            ),
            const SizedBox(height: 12),
            _buildInfoCard(
              context,
              isDark: isDark,
              children: [
                _buildDetailsRow('Provider / Source', attack.source.name),
                _buildDetailsRow(
                  'Year Reported',
                  attack.source.year.toString(),
                ),
              ],
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              elevation: 4,
              shadowColor: Theme.of(
                context,
              ).colorScheme.primary.withOpacity(0.4),
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            icon: const Icon(Icons.language_rounded),
            label: const Text(
              'VISUALIZE ON GLOBE',
              style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 1.2),
            ),
            onPressed: () {
              // Empty callback per requirements
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context,
    String title,
    IconData icon,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark
        ? Colors.cyanAccent
        : Theme.of(context).colorScheme.primary;

    return Row(
      children: [
        Icon(icon, size: 20, color: primaryColor),
        const SizedBox(width: 8),
        Text(
          title.toUpperCase(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: primaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoBadge(
    BuildContext context, {
    required IconData icon,
    required String label,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard(
    BuildContext context, {
    required bool isDark,
    required List<Widget> children,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF161925) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isDark
              ? Colors.blueGrey.shade900.withOpacity(0.5)
              : Colors.grey.shade200,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildDetailsRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
