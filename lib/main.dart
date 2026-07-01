import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/lg_service.dart';
import 'services/lg_adapter.dart';
import 'services/honeylabs_service.dart';
import 'services/abuseipdb_service.dart';
import 'services/track_ip_lg_service.dart';
import 'repositories/attack_repository.dart';
import 'repositories/track_ip_repository.dart';
import 'providers/attack_provider.dart';
import 'providers/track_ip_provider.dart';
import 'theme/theme_notifier.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'pages/settings_page.dart';
import 'pages/track_ip_page.dart';
import 'utils/config.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load API Key configurations from assets/.env
  await AppConfig.loadConfig();

  final apiService = HoneyLabsService();
  final repository = AttackRepository(apiService);

  final abuseDbService = AbuseIpDbService();
  final trackRepository = TrackIpRepository(abuseDbService);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeNotifier>(
          create: (_) => ThemeNotifier()..loadThemeMode(),
        ),
        ChangeNotifierProvider<LgService>(create: (_) => LgService()),
        ProxyProvider<LgService, LgAdapter>(
          update: (_, lgService, __) => LgAdapter(lgService),
        ),
        ProxyProvider<LgService, TrackIpLgService>(
          update: (_, lgService, __) => TrackIpLgService(lgService),
        ),
        ChangeNotifierProvider<AttackProvider>(
          create: (_) => AttackProvider(repository),
        ),
        ChangeNotifierProvider<TrackIpProvider>(
          create: (_) => TrackIpProvider(trackRepository),
        ),
      ],
      child: const MainApp(),
    ),
  );
}

class MainApp extends StatelessWidget {
  const MainApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    return MaterialApp(
      title: 'HoneyVision Dashboard',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeNotifier.themeMode,
      home: const AppShell(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class AppShell extends StatefulWidget {
  final bool autoInitializeConnection;

  const AppShell({super.key, this.autoInitializeConnection = true});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [
    DashboardScreen(),
    SettingsPage(),
    TrackIpPage(),
  ];

  @override
  void initState() {
    super.initState();
    if (widget.autoInitializeConnection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<LgService>().initializeConnection().catchError((e) {
          debugPrint('Failed to auto-initialize LG connection: $e');
        });
      });
    }
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required int index,
    required bool isDark,
  }) {
    final isSelected = _selectedIndex == index;
    final activeColor = isDark ? Colors.cyanAccent : Colors.indigo;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        tileColor: isSelected
            ? (isDark ? Colors.cyan.withOpacity(0.1) : Colors.indigo.shade50)
            : Colors.transparent,
        leading: Icon(icon, color: isSelected ? activeColor : Colors.grey),
        title: Text(
          title,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected
                ? (isDark ? Colors.white : Colors.indigo.shade900)
                : (isDark ? Colors.grey.shade400 : Colors.black87),
          ),
        ),
        onTap: () {
          setState(() {
            _selectedIndex = index;
          });
          Navigator.pop(context);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _pages),
      // bottomNavigationBar: NavigationBar(
      //   selectedIndex: _selectedIndex,
      //   onDestinationSelected: (int index) {
      //     setState(() {
      //       _selectedIndex = index;
      //     });
      //   },
      //   destinations: const [
      //     NavigationDestination(
      //       icon: Icon(Icons.dashboard_rounded),
      //       label: 'Dashboard',
      //     ),
      //     NavigationDestination(
      //       icon: Icon(Icons.settings_rounded),
      //       label: 'Connection Settings',
      //     ),
      //     NavigationDestination(
      //       icon: Icon(Icons.location_on_rounded),
      //       label: 'Track IP',
      //     ),
      //   ],
      // ),
      drawer: Drawer(
        backgroundColor: isDark ? const Color(0xFF0F111A) : Colors.white,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F111A)
                    : Colors.indigo.shade900,
                border: Border(
                  bottom: BorderSide(
                    color: isDark
                        ? Colors.blue.shade900.withOpacity(0.5)
                        : Colors.indigo.shade800,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Icon(
                    Icons.shield,
                    color: isDark ? Colors.cyanAccent : Colors.amberAccent,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'HONEYVISION',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 2.0,
                    ),
                  ),
                  Text(
                    'Cyber Threat Intelligence',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.grey.shade400 : Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: [
                  _buildDrawerItem(
                    icon: Icons.dashboard_rounded,
                    title: 'Dashboard',
                    index: 0,
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings_rounded,
                    title: 'Connection Settings',
                    index: 1,
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    icon: Icons.location_on_rounded,
                    title: 'Track IP',
                    index: 2,
                    isDark: isDark,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
