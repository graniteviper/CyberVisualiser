import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/lg_service.dart';
import '../utils/config.dart';
import '../widgets/qr_scanner.dart';
import '../main.dart';

class OnboardingScreen extends StatefulWidget {
  final bool isReplaying;
  final bool autoInitializeConnectionOnFinish;
  const OnboardingScreen({
    super.key,
    this.isReplaying = false,
    this.autoInitializeConnectionOnFinish = true,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final int _numPages = 4;

  // Controllers for LG SSH Setup
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _screensController;

  // Controllers for API Credentials
  late final TextEditingController _honeyLabsKeyController;
  late final TextEditingController _abuseIpDbKeyController;
  late final TextEditingController _geminiKeyController;

  bool _isTestingConnection = false;
  bool? _connectionSuccess;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController();
    _portController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _screensController = TextEditingController();
    _honeyLabsKeyController = TextEditingController();
    _abuseIpDbKeyController = TextEditingController();
    _geminiKeyController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final connection = context.read<LgService>().connectionModel;
    _ipController.text = connection.ip;
    _portController.text = connection.port.toString();
    _usernameController.text = connection.username;
    _passwordController.text = connection.password;
    _screensController.text = connection.screens.toString();
    _honeyLabsKeyController.text = AppConfig.userApiKey;
    _abuseIpDbKeyController.text = AppConfig.userAbuseIpDbApiKey;
    _geminiKeyController.text = AppConfig.userGeminiApiKey;
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _screensController.dispose();
    _honeyLabsKeyController.dispose();
    _abuseIpDbKeyController.dispose();
    _geminiKeyController.dispose();
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _testConnection() async {
    setState(() {
      _isTestingConnection = true;
      _connectionSuccess = null;
    });

    final service = context.read<LgService>();
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 22;
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final screens = int.tryParse(_screensController.text.trim()) ?? 3;

    if (ip.isEmpty || username.isEmpty || password.isEmpty) {
      setState(() {
        _isTestingConnection = false;
        _connectionSuccess = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter valid connection details.')),
      );
      return;
    }

    // Temporarily apply connection settings to try to connect
    service.updateConnectionSettings(
      ip: ip,
      port: port,
      username: username,
      password: password,
      screens: screens,
    );

    if (service.isConnected) {
      service.disconnect();
    }

    final success = await service.connectToLG();
    setState(() {
      _isTestingConnection = false;
      _connectionSuccess = success == true;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            success == true
                ? 'Connected successfully to Liquid Galaxy!'
                : 'Connection failed. Please check details and try again.',
          ),
          backgroundColor: success == true ? Colors.green : Colors.red,
        ),
      );
    }
  }

  Future<void> _scanQrSettings() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (context) => const QrScanner()),
    );

    if (result != null && mounted) {
      setState(() {
        _ipController.text = result['ip']?.toString() ?? '';
        _portController.text = result['port']?.toString() ?? '22';
        _usernameController.text = result['username']?.toString() ?? 'lg';
        _passwordController.text = result['password']?.toString() ?? 'lqgalaxy';
        _screensController.text = result['screens']?.toString() ?? '3';
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection details imported from QR code.'),
        ),
      );

      // Trigger automatic connection test
      await _testConnection();
    }
  }

  Future<void> _saveAllSettings() async {
    final service = context.read<LgService>();
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 22;
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final screens = int.tryParse(_screensController.text.trim()) ?? 3;

    // Save LG Service Connection details if not empty
    if (ip.isNotEmpty && username.isNotEmpty && password.isNotEmpty) {
      service.updateConnectionSettings(
        ip: ip,
        port: port,
        username: username,
        password: password,
        screens: screens,
      );
      await service.saveConnectionSettings();
    }

    // Save Custom API credentials
    final honeyKey = _honeyLabsKeyController.text.trim();
    final abuseKey = _abuseIpDbKeyController.text.trim();
    final geminiKey = _geminiKeyController.text.trim();
    await AppConfig.saveUserKeys(honeyKey, abuseKey, geminiKey);
  }

  Future<void> _finishOnboarding() async {
    final honeyKey = _honeyLabsKeyController.text.trim();
    final abuseKey = _abuseIpDbKeyController.text.trim();
    final geminiKey = _geminiKeyController.text.trim();

    if (honeyKey.isEmpty || abuseKey.isEmpty || geminiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'All API keys (HoneyLabs, AbuseIPDB, Gemini) are mandatory and required.',
          ),
          backgroundColor: Colors.red,
        ),
      );
      _pageController.animateToPage(
        2,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
      return;
    }

    await _saveAllSettings();

    // Mark onboarding as completed in SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('completed_onboarding', true);

    // If replaying, pop this screen back to settings; otherwise launch AppShell
    if (mounted) {
      if (widget.isReplaying) {
        Navigator.of(context).pop();
      } else {
        // Clear navigation stack and load AppShell
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => AppShell(
              autoInitializeConnection: widget.autoInitializeConnectionOnFinish,
            ),
          ),
          (route) => false,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? Colors.cyanAccent : Colors.indigo;
    final accentColor = isDark
        ? const Color(0xFF0F111A)
        : Colors.indigo.shade50;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF070913) : Colors.grey.shade50,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar with Skip Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 8.0,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // App branding
                  Row(
                    children: [
                      Icon(
                        Icons.shield,
                        color: isDark ? Colors.cyanAccent : Colors.indigo,
                        size: 24,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'CYBER VISUALISER',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          color: isDark ? Colors.white : Colors.indigo.shade900,
                          letterSpacing: 1.5,
                        ),
                      ),
                    ],
                  ),
                  if (_currentPage < _numPages - 1 && !widget.isReplaying)
                    TextButton(
                      onPressed: _finishOnboarding,
                      child: Text(
                        'Skip',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.indigo.shade600,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    )
                  else if (widget.isReplaying)
                    IconButton(
                      icon: Icon(
                        Icons.close,
                        color: isDark ? Colors.white70 : Colors.black87,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                ],
              ),
            ),

            // Onboarding Slides
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (int page) {
                  setState(() {
                    _currentPage = page;
                  });
                },
                children: [
                  _buildWelcomeSlide(isDark, primaryColor),
                  _buildLgSetupSlide(isDark, primaryColor, accentColor),
                  _buildApiKeysSlide(isDark, primaryColor, accentColor),
                  _buildFeaturesSlide(isDark, primaryColor, accentColor),
                ],
              ),
            ),

            // Controls Panel at bottom
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back Button (hidden on first page)
                  Opacity(
                    opacity: _currentPage == 0 ? 0.0 : 1.0,
                    child: IgnorePointer(
                      ignoring: _currentPage == 0,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded),
                        color: isDark ? Colors.white70 : Colors.black87,
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                      ),
                    ),
                  ),

                  // Indicator Dots
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _numPages,
                      (index) => _buildPageIndicator(index, isDark),
                    ),
                  ),

                  // Next / Finish Button
                  _currentPage == _numPages - 1
                      ? ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryColor,
                            foregroundColor: isDark
                                ? Colors.black
                                : Colors.white,
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 24,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                            elevation: 4,
                            shadowColor: primaryColor.withOpacity(0.4),
                          ),
                          onPressed: _finishOnboarding,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'Get Started',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.rocket_launch_rounded, size: 18),
                            ],
                          ),
                        )
                      : ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: isDark
                                ? Colors.grey.shade900
                                : Colors.indigo.shade900,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(0, 40),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(20),
                            ),
                          ),
                          onPressed: () {
                            if (_currentPage == 2) {
                              final honeyKey = _honeyLabsKeyController.text
                                  .trim();
                              final abuseKey = _abuseIpDbKeyController.text
                                  .trim();
                              final geminiKey = _geminiKeyController.text
                                  .trim();

                              if (honeyKey.isEmpty ||
                                  abuseKey.isEmpty ||
                                  geminiKey.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'All API keys (HoneyLabs, AbuseIPDB, Gemini) are mandatory and required.',
                                    ),
                                    backgroundColor: Colors.red,
                                  ),
                                );
                                return;
                              }
                            }
                            _pageController.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          },
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Text(
                                'Next',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              SizedBox(width: 8),
                              Icon(Icons.arrow_forward_ios_rounded, size: 14),
                            ],
                          ),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPageIndicator(int index, bool isDark) {
    final isActive = index == _currentPage;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      margin: const EdgeInsets.symmetric(horizontal: 4.0),
      height: 8.0,
      width: isActive ? 24.0 : 8.0,
      decoration: BoxDecoration(
        color: isActive
            ? (isDark ? Colors.cyanAccent : Colors.indigo)
            : (isDark ? Colors.grey.shade800 : Colors.grey.shade300),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  // Slide 1: Welcome
  Widget _buildWelcomeSlide(bool isDark, Color primaryColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 40),
          // Animated glowing shield
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isDark
                  ? Colors.cyan.withOpacity(0.05)
                  : Colors.indigo.withOpacity(0.05),
              border: Border.all(
                color: isDark
                    ? Colors.cyanAccent.withOpacity(0.2)
                    : Colors.indigo.withOpacity(0.2),
                width: 2,
              ),
              boxShadow: isDark
                  ? [
                      BoxShadow(
                        color: Colors.cyanAccent.withOpacity(0.05),
                        blurRadius: 30,
                        spreadRadius: 5,
                      ),
                    ]
                  : null,
            ),
            child: Icon(
              Icons.shield_outlined,
              size: 100,
              color: isDark ? Colors.cyanAccent : Colors.indigo.shade900,
            ),
          ),
          const SizedBox(height: 40),
          Text(
            'Immersive Threat Intel',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.indigo.shade900,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Cyber Visualiser enables real-time global cyber threat visualization on Liquid Galaxy multi-display rigs. Track IP addresses, simulate attacks, and explore threat history with AI support.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: isDark ? Colors.grey.shade400 : Colors.black87,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 40),
          // Highlighting feature summary row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _buildBriefFeatureIcon(
                Icons.dashboard_rounded,
                'Visualize',
                isDark,
                primaryColor,
              ),
              const SizedBox(width: 24),
              _buildBriefFeatureIcon(
                Icons.location_on_rounded,
                'Track',
                isDark,
                primaryColor,
              ),
              const SizedBox(width: 24),
              _buildBriefFeatureIcon(
                Icons.psychology_outlined,
                'Simulate',
                isDark,
                primaryColor,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBriefFeatureIcon(
    IconData icon,
    String label,
    bool isDark,
    Color primaryColor,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? Colors.grey.shade900 : Colors.grey.shade200,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: primaryColor, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey.shade400 : Colors.black87,
          ),
        ),
      ],
    );
  }

  // Slide 2: Liquid Galaxy SSH Setup
  Widget _buildLgSetupSlide(
    bool isDark,
    Color primaryColor,
    Color accentColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Liquid Galaxy Rig Connection',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: isDark ? Colors.white : Colors.indigo.shade900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Provide SSH credentials to coordinate maps and KML displays.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? Colors.grey.shade400 : Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded),
                color: primaryColor,
                tooltip: 'Scan QR Settings',
                onPressed: _scanQrSettings,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInputField(
            controller: _ipController,
            label: 'IP Address',
            hintText: 'e.g. 192.168.1.100',
            icon: Icons.lan_outlined,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: _buildInputField(
                  controller: _portController,
                  label: 'Port',
                  hintText: '22',
                  icon: Icons.door_sliding_outlined,
                  keyboardType: TextInputType.number,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: _buildInputField(
                  controller: _screensController,
                  label: 'Screens Count',
                  hintText: '3',
                  icon: Icons.monitor_rounded,
                  keyboardType: TextInputType.number,
                  isDark: isDark,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildInputField(
            controller: _usernameController,
            label: 'SSH Username',
            hintText: 'lg',
            icon: Icons.person_outline,
            isDark: isDark,
          ),
          const SizedBox(height: 12),
          _buildInputField(
            controller: _passwordController,
            label: 'SSH Password',
            obscureText: true,
            icon: Icons.lock_outline,
            isDark: isDark,
          ),
          const SizedBox(height: 20),
          // Test Connection Status and Action button
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: accentColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? Colors.blue.shade900.withOpacity(0.4)
                    : Colors.indigo.shade100,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (_isTestingConnection)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else if (_connectionSuccess == true)
                        const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                          size: 20,
                        )
                      else if (_connectionSuccess == false)
                        const Icon(
                          Icons.error_rounded,
                          color: Colors.red,
                          size: 20,
                        )
                      else
                        Icon(
                          Icons.help_outline_rounded,
                          color: isDark ? Colors.grey.shade400 : Colors.indigo,
                          size: 20,
                        ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _isTestingConnection
                              ? 'Connecting...'
                              : _connectionSuccess == true
                              ? 'Connected'
                              : _connectionSuccess == false
                              ? 'Connection failed'
                              : 'Not verified yet',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : Colors.indigo.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                TextButton.icon(
                  onPressed: _isTestingConnection ? null : _testConnection,
                  icon: const Icon(Icons.sync_alt_rounded, size: 16),
                  label: const Text(
                    'Test Connection',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(foregroundColor: primaryColor),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Slide 3: API Credentials
  Widget _buildApiKeysSlide(
    bool isDark,
    Color primaryColor,
    Color accentColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'API Integrations',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.indigo.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'All API keys are mandatory and required to use the app. Default credentials are not provided.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          _buildInputField(
            controller: _honeyLabsKeyController,
            label: 'HoneyLabs API Key',
            obscureText: true,
            icon: Icons.api_rounded,
            isDark: isDark,
            subtitle: 'Powers honeypot live threat feeds & active threat data.',
          ),
          const SizedBox(height: 16),
          _buildInputField(
            controller: _abuseIpDbKeyController,
            label: 'AbuseIPDB API Key',
            obscureText: true,
            icon: Icons.bug_report_outlined,
            isDark: isDark,
            subtitle:
                'Enables IP address profiling and safety score inquiries.',
          ),
          const SizedBox(height: 16),
          _buildInputField(
            controller: _geminiKeyController,
            label: 'Gemini API Key',
            obscureText: true,
            icon: Icons.psychology_outlined,
            isDark: isDark,
            subtitle: 'Empowers historical attack summarization & insights.',
          ),
        ],
      ),
    );
  }

  // Slide 4: Features Tour
  Widget _buildFeaturesSlide(
    bool isDark,
    Color primaryColor,
    Color accentColor,
  ) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Explore Cyber Visualiser Features',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.indigo.shade900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Familiarize yourself with the tools provided in this workspace.',
            style: TextStyle(
              fontSize: 13,
              color: isDark ? Colors.grey.shade400 : Colors.black54,
            ),
          ),
          const SizedBox(height: 20),
          _buildFeatureTourCard(
            icon: Icons.dashboard_rounded,
            title: 'Threat Intel Dashboard',
            description:
                'View active global threat statistics, charts, and coordinate KML representations on the Liquid Galaxy.',
            isDark: isDark,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 12),
          _buildFeatureTourCard(
            icon: Icons.history_edu_rounded,
            title: 'Historical Incidents DB',
            description:
                'Read reports of massive historical cyber attacks and use Gemini AI to generate insights and query summaries.',
            isDark: isDark,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 12),
          _buildFeatureTourCard(
            icon: Icons.location_on_rounded,
            title: 'IP Tracker & Profiler',
            description:
                'Geolocate suspect IP addresses and send orbit fly-tos directly to your Liquid Galaxy rig.',
            isDark: isDark,
            primaryColor: primaryColor,
          ),
          const SizedBox(height: 12),
          _buildFeatureTourCard(
            icon: Icons.psychology_outlined,
            title: 'Attack Simulator',
            description:
                'Simulate packet flows, DDoS traffic, or server intrusions and view how they represent visually on screen.',
            isDark: isDark,
            primaryColor: primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureTourCard({
    required IconData icon,
    required String title,
    required String description,
    required bool isDark,
    required Color primaryColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1124) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isDark ? const Color(0xFF1F294D) : Colors.grey.shade200,
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? Colors.black.withOpacity(0.1)
                : Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF00E5FF).withOpacity(0.08)
                  : const Color(0xFF3B82F6).withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              icon,
              color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF3B82F6),
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.grey.shade400 : Colors.black87,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInputField({
    required TextEditingController controller,
    required String label,
    String? hintText,
    String? subtitle,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    required IconData icon,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          style: const TextStyle(fontSize: 14),
          decoration: InputDecoration(
            labelText: label,
            hintText: hintText,
            prefixIcon: Icon(
              icon,
              color: isDark
                  ? const Color(0xFF00E5FF).withOpacity(0.7)
                  : const Color(0xFF3B82F6),
              size: 20,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 8.0),
            child: Text(
              subtitle,
              style: TextStyle(
                fontSize: 11,
                color: isDark ? Colors.grey.shade500 : Colors.grey.shade600,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
