import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/lg_service.dart';
import '../theme/theme_notifier.dart';
import '../utils/config.dart';
import '../widgets/qr_scanner.dart';
import '../screens/onboarding_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _ipController;
  late final TextEditingController _portController;
  late final TextEditingController _usernameController;
  late final TextEditingController _passwordController;
  late final TextEditingController _screensController;
  late final TextEditingController _honeyLabsKeyController;
  late final TextEditingController _abuseIpDbKeyController;
  late final TextEditingController _geminiKeyController;

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
    super.dispose();
  }

  Future<bool> _saveSettings({bool showSnackBar = true}) async {
    final service = context.read<LgService>();
    final ip = _ipController.text.trim();
    final port = int.tryParse(_portController.text.trim()) ?? 22;
    final username = _usernameController.text.trim();
    final password = _passwordController.text.trim();
    final screens = int.tryParse(_screensController.text.trim()) ?? 3;

    if (ip.isEmpty || username.isEmpty || password.isEmpty || screens < 1) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please enter valid settings.')),
        );
      }
      return false;
    }

    service.updateConnectionSettings(
      ip: ip,
      port: port,
      username: username,
      password: password,
      screens: screens,
    );

    await service.saveConnectionSettings();

    // Save custom user API keys
    final honeyKey = _honeyLabsKeyController.text.trim();
    final abuseKey = _abuseIpDbKeyController.text.trim();
    final geminiKey = _geminiKeyController.text.trim();
    await AppConfig.saveUserKeys(honeyKey, abuseKey, geminiKey);

    if (showSnackBar && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Connection settings and API keys saved.'),
        ),
      );
    }
    return true;
  }

  Future<void> _scanQrSettings() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (context) => const QrScanner()),
    );

    if (result != null && mounted) {
      final ip = result['ip']?.toString() ?? '';
      final port = int.tryParse(result['port']?.toString() ?? '22') ?? 22;
      final username = result['username']?.toString() ?? 'lg';
      final password = result['password']?.toString() ?? 'lqgalaxy';
      final screens = int.tryParse(result['screens']?.toString() ?? '3') ?? 3;

      setState(() {
        _ipController.text = ip;
        _portController.text = port.toString();
        _usernameController.text = username;
        _passwordController.text = password;
        _screensController.text = screens.toString();
      });

      // Save connection settings
      await _saveSettings();

      // Trigger automatic connection to Liquid Galaxy rig
      final service = context.read<LgService>();
      if (service.isConnected) {
        service.disconnect();
      }

      // Show connecting status
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Attempting to connect to Liquid Galaxy...'),
          duration: Duration(seconds: 2),
        ),
      );

      final success = await service.connectToLG();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              success == true
                  ? 'Connected successfully!'
                  : 'Connection failed.',
            ),
            backgroundColor: success == true ? Colors.green : Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LgService>();
    final themeNotifier = context.watch<ThemeNotifier>();
    final themeMode = themeNotifier.themeMode;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF0D1124) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: isDark
                          ? const Color(0xFF1F294D)
                          : Colors.grey.shade200,
                    ),
                  ),
                  child: Icon(
                    Icons.settings_outlined,
                    color: isDark
                        ? const Color(0xFF00E5FF)
                        : const Color(0xFF3B82F6),
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Text(
                  'SETTINGS',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                    letterSpacing: 2.0,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  tooltip: 'Scan QR Settings',
                  onPressed: _scanQrSettings,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Connection Settings Panel
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1124) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1F294D)
                      : Colors.grey.shade200,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.12)
                        : Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rig Connection Settings',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFF3B82F6),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'IP address',
                    controller: _ipController,
                    hintText: 'e.g. 192.168.1.100',
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: _buildTextField(
                          label: 'Port',
                          controller: _portController,
                          hintText: '22',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 3,
                        child: _buildTextField(
                          label: 'Screens',
                          controller: _screensController,
                          hintText: '3',
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: 'Username',
                    controller: _usernameController,
                    hintText: 'lg',
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: 'Password',
                    controller: _passwordController,
                    obscureText: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // API Credentials Panel
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1124) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1F294D)
                      : Colors.grey.shade200,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.12)
                        : Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'API Credentials',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFF3B82F6),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Custom keys override defaults loaded from the assets/.env file',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  _buildTextField(
                    label: 'HoneyLabs API Key',
                    controller: _honeyLabsKeyController,
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: 'AbuseIPDB API Key',
                    controller: _abuseIpDbKeyController,
                    obscureText: true,
                  ),
                  const SizedBox(height: 12),
                  _buildTextField(
                    label: 'Gemini API Key',
                    controller: _geminiKeyController,
                    obscureText: true,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () => _saveSettings(),
                    child: const Text(
                      'Save Settings',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      backgroundColor: service.isConnected
                          ? Colors.redAccent.withOpacity(0.12)
                          : (isDark
                                ? const Color(0xFF00E5FF).withOpacity(0.12)
                                : const Color(0xFF3B82F6).withOpacity(0.08)),
                      foregroundColor: service.isConnected
                          ? Colors.redAccent
                          : (isDark
                                ? const Color(0xFF00E5FF)
                                : const Color(0xFF3B82F6)),
                      side: BorderSide(
                        color: service.isConnected
                            ? Colors.redAccent
                            : (isDark
                                  ? const Color(0xFF00E5FF).withOpacity(0.3)
                                  : const Color(0xFF3B82F6).withOpacity(0.3)),
                        width: 1.2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    onPressed: () async {
                      if (service.isConnected) {
                        service.disconnect();
                      } else {
                        final saved = await _saveSettings(showSnackBar: false);
                        if (!saved) return;
                        
                        await service.connectToLG();
                        final msg = service.isConnected
                            ? 'Connected successfully'
                            : 'Connection failed';
                        if (mounted) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(msg)));
                        }
                      }
                    },
                    child: Text(
                      service.isConnected ? 'Disconnect' : 'Connect to LG',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Command Center Panel
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1124) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1F294D)
                      : Colors.grey.shade200,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.12)
                        : Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Rig Command Center',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFF3B82F6),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Direct actions to clean KML states and graphics overlays',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.redAccent.withOpacity(0.12),
                            foregroundColor: Colors.redAccent,
                            side: const BorderSide(
                              color: Colors.redAccent,
                              width: 1.2,
                            ),
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(
                            Icons.delete_sweep_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Clear KML',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: service.isConnected
                              ? () async {
                                  final success = await service.cleanKML();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: Text(
                                          success
                                              ? 'KML vectors cleared successfully.'
                                              : 'Failed to clear KMLs.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orangeAccent.withOpacity(
                              0.12,
                            ),
                            foregroundColor: Colors.orangeAccent,
                            side: const BorderSide(
                              color: Colors.orangeAccent,
                              width: 1.2,
                            ),
                            minimumSize: const Size(0, 44),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            elevation: 0,
                          ),
                          icon: const Icon(
                            Icons.layers_clear_rounded,
                            size: 18,
                          ),
                          label: const Text(
                            'Clear Logos',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed: service.isConnected
                              ? () async {
                                  await service.cleanLogos();
                                  if (mounted) {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Overlays and logos cleared.',
                                        ),
                                      ),
                                    );
                                  }
                                }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Theme Panel
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1124) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1F294D)
                      : Colors.grey.shade200,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.12)
                        : Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Theme',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFF3B82F6),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<ThemeMode>(
                    value: themeMode,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: ThemeMode.system,
                        child: Text('System default'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.light,
                        child: Text('Light mode'),
                      ),
                      DropdownMenuItem(
                        value: ThemeMode.dark,
                        child: Text('Dark mode'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) {
                        themeNotifier.setThemeMode(value);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Tutorial Panel
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0D1124) : Colors.white,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF1F294D)
                      : Colors.grey.shade200,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: isDark
                        ? Colors.black.withOpacity(0.12)
                        : Colors.black.withOpacity(0.02),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Tutorial & Setup',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isDark
                          ? const Color(0xFF00E5FF)
                          : const Color(0xFF3B82F6),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Replay the onboarding tour to review feature highlights or reconfigure settings.',
                    style: TextStyle(fontSize: 11, color: Colors.grey),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      icon: const Icon(Icons.rocket_launch_rounded),
                      label: const Text(
                        'Replay Onboarding Tour',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) =>
                                const OnboardingScreen(isReplaying: true),
                          ),
                        );
                      },
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

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    String? hintText,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        hintText: hintText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
    );
  }
}
