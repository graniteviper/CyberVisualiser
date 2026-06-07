import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/lg_service.dart';
import '../theme/theme_notifier.dart';

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

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController();
    _portController = TextEditingController();
    _usernameController = TextEditingController();
    _passwordController = TextEditingController();
    _screensController = TextEditingController();
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
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _screensController.dispose();
    super.dispose();
  }

  Future<void> _saveSettings() async {
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
      return;
    }

    service.updateConnectionSettings(
      ip: ip,
      port: port,
      username: username,
      password: password,
      screens: screens,
    );

    await service.saveConnectionSettings();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Connection settings saved.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final service = context.watch<LgService>();
    final themeNotifier = context.watch<ThemeNotifier>();
    final themeMode = themeNotifier.themeMode;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Liquid Galaxy Settings', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 16),
            _buildTextField(label: 'IP address', controller: _ipController, hintText: 'e.g. 192.168.1.100'),
            const SizedBox(height: 12),
            _buildTextField(label: 'Port', controller: _portController, hintText: '22', keyboardType: TextInputType.number),
            const SizedBox(height: 12),
            _buildTextField(label: 'Username', controller: _usernameController, hintText: 'lg'),
            const SizedBox(height: 12),
            _buildTextField(label: 'Password', controller: _passwordController, obscureText: true),
            const SizedBox(height: 12),
            _buildTextField(label: 'Screens', controller: _screensController, hintText: '3', keyboardType: TextInputType.number),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _saveSettings,
                    child: const Text('Save Settings'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: service.isConnected ? Colors.green.withOpacity(0.2) : null,
                    ),
                    onPressed: () async {
                      if (service.isConnected) {
                        service.disconnect();
                      } else {
                        await service.connectToLG();
                        final msg = service.isConnected ? 'Connected successfully' : 'Connection failed';
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(msg)),
                          );
                        }
                      }
                    },
                    child: Text(service.isConnected ? 'Disconnect' : 'Connect to LG'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('App Theme', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    DropdownButton<ThemeMode>(
                      value: themeMode,
                      isExpanded: true,
                      items: const [
                        DropdownMenuItem(value: ThemeMode.system, child: Text('System default')),
                        DropdownMenuItem(value: ThemeMode.light, child: Text('Light mode')),
                        DropdownMenuItem(value: ThemeMode.dark, child: Text('Dark mode')),
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
      decoration: InputDecoration(
        border: const OutlineInputBorder(),
        labelText: label,
        hintText: hintText,
      ),
    );
  }
}
