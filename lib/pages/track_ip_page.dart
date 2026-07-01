import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/track_ip_provider.dart';
import '../services/lg_service.dart';
import '../services/track_ip_lg_service.dart';

class TrackIpPage extends StatefulWidget {
  const TrackIpPage({super.key});

  @override
  State<TrackIpPage> createState() => _TrackIpPageState();
}

class _TrackIpPageState extends State<TrackIpPage> {
  final _formKey = GlobalKey<FormState>();
  final _ipController = TextEditingController();
  double _maxAgeInDays = 5.0;

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  String? _validateIp(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter an IP address';
    }
    final ipTrimmed = value.trim();
    // Regular expression for validating IPv4
    final ipv4Reg = RegExp(r'^((25[0-5]|(2[0-4]|1\d|[1-9]|)\d)\.?\b){4}$');
    // Regular expression for validating IPv6
    final ipv6Reg = RegExp(
      r'^(([0-9a-fA-F]{1,4}:){7,7}[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,7}:|([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}|([0-9a-fA-F]{1,4}:){1,5}(:[0-9a-fA-F]{1,4}){1,2}|([0-9a-fA-F]{1,4}:){1,4}(:[0-9a-fA-F]{1,4}){1,3}|([0-9a-fA-F]{1,4}:){1,3}(:[0-9a-fA-F]{1,4}){1,4}|([0-9a-fA-F]{1,4}:){1,2}(:[0-9a-fA-F]{1,4}){1,5}|[0-9a-fA-F]{1,4}:((:[0-9a-fA-F]{1,4}){1,6})|:((:[0-9a-fA-F]{1,4}){1,7}|:)|fe80:(:[0-9a-fA-F]{0,4}){0,4}%[0-9a-zA-Z]{1,}|::(ffff(:0{1,4}){0,1}:){0,1}((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])|([0-9a-fA-F]{1,4}:){1,4}:((25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9])\.){3,3}(25[0-5]|(2[0-4]|1{0,1}[0-9]){0,1}[0-9]))$',
    );

    if (!ipv4Reg.hasMatch(ipTrimmed) && !ipv6Reg.hasMatch(ipTrimmed)) {
      return 'Please enter a valid IPv4 or IPv6 address';
    }
    return null;
  }

  void _submitSearch(TrackIpProvider provider, TrackIpLgService lgService) {
    if (_formKey.currentState!.validate()) {
      FocusScope.of(context).unfocus();
      provider.fetchIpDetails(
        ipAddress: _ipController.text.trim(),
        maxAgeInDays: _maxAgeInDays.toInt(),
        lgService: lgService,
      );
    }
  }

  Color _getSeverityColor(int score) {
    if (score > 50) {
      return Colors.redAccent.shade400;
    } else if (score > 20) {
      return Colors.orangeAccent;
    } else {
      return Colors.greenAccent.shade400;
    }
  }

  String _getBadgeText(int score) {
    if (score > 50) return 'HIGH RISK';
    if (score > 20) return 'MEDIUM RISK';
    return 'LOW RISK';
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TrackIpProvider>();
    final lgService = context.watch<LgService>();
    final trackLgService = context.watch<TrackIpLgService>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderBanner(isDark),
            _buildRigConnectionBar(lgService, isDark),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildFormCard(provider, trackLgService, isDark),
                    const SizedBox(height: 16),
                    _buildResultsSection(provider, trackLgService, isDark),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F111A) : Colors.indigo.shade900,
        border: Border(
          bottom: BorderSide(
            color: isDark
                ? Colors.blue.shade900.withOpacity(0.5)
                : Colors.indigo.shade800,
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.menu, color: Colors.white),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            onPressed: () => Scaffold.of(context).openDrawer(),
            tooltip: 'Open navigation drawer',
          ),
          const SizedBox(width: 12),
          Icon(
            Icons.location_on_rounded,
            color: isDark ? Colors.cyanAccent : Colors.amberAccent,
            size: 32,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'IP TRACKER',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 2.0,
                  ),
                ),
                Text(
                  'Query AbuseIPDB threat intel and project attack vectors',
                  style: TextStyle(
                    fontSize: 11,
                    color: isDark ? Colors.grey.shade400 : Colors.white70,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRigConnectionBar(LgService lgService, bool isDark) {
    final statusColor = lgService.isConnected ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isDark ? const Color(0xFF141622) : Colors.grey.shade200,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: statusColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Rig Server: ${lgService.isConnected ? "CONNECTED" : "DISCONNECTED"} (${lgService.connectionModel.ip}:${lgService.connectionModel.port})',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          if (!lgService.isConnected)
            const Text(
              'Visualization Offline',
              style: TextStyle(
                fontSize: 11,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            )
          else
            const Text(
              'Visualization Ready',
              style: TextStyle(
                fontSize: 11,
                color: Colors.green,
                fontWeight: FontWeight.bold,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildFormCard(
    TrackIpProvider provider,
    TrackIpLgService trackLgService,
    bool isDark,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isDark
              ? Colors.blueGrey.shade900.withOpacity(0.5)
              : Colors.grey.shade300,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'IP Intel Search Parameters',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.blue.shade200 : Colors.indigo.shade800,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _ipController,
                validator: _validateIp,
                keyboardType: TextInputType.url,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Target IP Address',
                  hintText: 'e.g. 213.209.159.227',
                  prefixIcon: Icon(Icons.search_rounded),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Search Window (Days):',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.blue.shade900.withOpacity(0.3)
                          : Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${_maxAgeInDays.toInt()} Days',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _maxAgeInDays,
                min: 1.0,
                max: 30.0,
                divisions: 29,
                label: '${_maxAgeInDays.toInt()} days',
                onChanged: provider.isLoading
                    ? null
                    : (val) {
                        setState(() {
                          _maxAgeInDays = val;
                        });
                      },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        backgroundColor: isDark
                            ? Colors.blue.shade900
                            : Colors.indigo.shade700,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: provider.isLoading
                          ? null
                          : () => _submitSearch(provider, trackLgService),
                      icon: provider.isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.location_searching_rounded),
                      label: const Text(
                        'Track IP Address',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                  if (provider.isVisualized) ...[
                    const SizedBox(width: 12),
                    IconButton.filled(
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.red.shade900.withOpacity(0.8),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.all(12),
                      ),
                      icon: const Icon(Icons.layers_clear),
                      tooltip: 'Clear KML from Liquid Galaxy',
                      onPressed: provider.isLoading
                          ? null
                          : () => provider.clearLGVisuals(trackLgService),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultsSection(
    TrackIpProvider provider,
    TrackIpLgService trackLgService,
    bool isDark,
  ) {
    if (provider.isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 60.0),
        child: Center(
          child: Column(
            children: [
              CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(
                'Fetching records & generating KML maps...',
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.errorMessage != null) {
      return Card(
        color: Colors.red.shade900.withOpacity(0.15),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: Colors.red.shade900.withOpacity(0.5)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.redAccent,
                size: 36,
              ),
              const SizedBox(height: 8),
              const Text(
                'Intel Query Error',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  color: Colors.redAccent,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                provider.errorMessage!,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: Colors.red.shade200),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.report == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 40.0),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.radar_rounded, color: Colors.grey, size: 48),
              SizedBox(height: 12),
              Text(
                'No active tracked IP.',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.grey,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Enter an IP above to lookup threat logs and visualize them.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    final report = provider.report!;
    final sevColor = _getSeverityColor(report.abuseConfidenceScore);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Premium App Summary Card representing overlay visual content
        Card(
          elevation: 4,
          color: const Color(0xFF0F111A),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: Colors.blueGrey.shade800, width: 2),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'IP TRACKER ANALYSIS',
                      style: TextStyle(
                        fontFamily: 'Outfit',
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        color: Colors.blue.shade400,
                        letterSpacing: 1.0,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.close,
                        color: Colors.grey,
                        size: 20,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      tooltip: 'Close Card and Clear Visuals',
                      onPressed: () =>
                          provider.clearState(lgService: trackLgService),
                    ),
                  ],
                ),
                const Divider(height: 16, color: Colors.blueGrey),
                Text(
                  report.ipAddress,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    fontFamily: 'monospace',
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: sevColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        _getBadgeText(report.abuseConfidenceScore),
                        style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (provider.isVisualized)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue.shade900.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.blue, width: 1),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.tv_rounded,
                              size: 10,
                              color: Colors.cyanAccent,
                            ),
                            SizedBox(width: 4),
                            Text(
                              'Visualizing on LG',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.cyanAccent,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildCardInfoRow(
                  'Country',
                  report.countryName.isNotEmpty
                      ? report.countryName
                      : report.countryCode,
                ),
                _buildCardInfoRow('ISP', report.isp),
                _buildCardInfoRow(
                  'Domain',
                  report.domain.isEmpty ? 'N/A' : report.domain,
                ),
                _buildCardInfoRow(
                  'Confidence',
                  '${report.abuseConfidenceScore}%',
                  valColor: sevColor,
                  isBold: true,
                ),
                _buildCardInfoRow(
                  'Total Reports',
                  '${report.totalReports} reports',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'THREAT LOG DETAILS (${report.reports.length})',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: isDark ? Colors.blue.shade200 : Colors.indigo.shade800,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 8),
        if (report.reports.isEmpty)
          Card(
            color: isDark ? const Color(0xFF141622) : Colors.grey.shade100,
            child: const Padding(
              padding: EdgeInsets.symmetric(vertical: 40.0, horizontal: 16.0),
              child: Center(
                child: Text(
                  'No reports returned within the search window.',
                  style: TextStyle(
                    color: Colors.grey,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: report.reports.length,
            itemBuilder: (context, index) {
              final item = report.reports[index];
              return Card(
                margin: const EdgeInsets.only(bottom: 10.0),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                  side: BorderSide(
                    color: isDark
                        ? Colors.blueGrey.shade900
                        : Colors.grey.shade300,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.calendar_today,
                                size: 12,
                                color: Colors.grey,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                item.reportedAt.toLocal().toString().split(
                                  ' ',
                                )[0],
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.shade800.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              item.reporterCountryName.isNotEmpty
                                  ? item.reporterCountryName
                                  : item.reporterCountryCode,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (item.categoryNames.isNotEmpty) ...[
                        Wrap(
                          spacing: 4,
                          runSpacing: 4,
                          children: item.categoryNames.map((name) {
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.red.shade900.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(4),
                                border: Border.all(
                                  color: Colors.red.shade900.withOpacity(0.3),
                                ),
                              ),
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.redAccent.shade100,
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 8),
                      ],
                      Text(
                        item.comment.trim().isEmpty
                            ? 'No comment provided.'
                            : item.comment.trim(),
                        style: TextStyle(
                          fontSize: 12,
                          fontStyle: item.comment.trim().isEmpty
                              ? FontStyle.italic
                              : FontStyle.normal,
                          color: isDark ? Colors.grey.shade300 : Colors.black87,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildCardInfoRow(
    String label,
    String val, {
    Color? valColor,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 13,
                color: Colors.grey,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: Text(
              val,
              style: TextStyle(
                fontSize: 13,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                color: valColor ?? Colors.white70,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
