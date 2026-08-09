import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'services/lg_service.dart';
import 'services/lg_adapter.dart';
import 'services/honeylabs_service.dart';
import 'services/abuseipdb_service.dart';
import 'services/track_ip_lg_service.dart';
import 'services/gemini_service.dart';
import 'services/text_to_speech_service.dart';
import 'repositories/attack_repository.dart';
import 'repositories/track_ip_repository.dart';
import 'providers/attack_provider.dart';
import 'providers/track_ip_provider.dart';
import 'theme/theme_notifier.dart';
import 'theme/app_theme.dart';
import 'screens/dashboard_screen.dart';
import 'screens/onboarding_screen.dart';
import 'pages/settings_page.dart';
import 'pages/track_ip_page.dart';
import 'pages/simulate_attack_page.dart';
import 'utils/config.dart';
import 'features/historical/repository/historical_repository.dart';
import 'features/historical/providers/historical_provider.dart';
import 'features/historical/screens/historical_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load API Key configurations from assets/.env
  await AppConfig.loadConfig();

  final apiService = HoneyLabsService();
  final repository = AttackRepository(apiService);

  final abuseDbService = AbuseIpDbService();
  final trackRepository = TrackIpRepository(abuseDbService);
  final historicalRepository = HistoricalRepository();

  final prefs = await SharedPreferences.getInstance();
  final completedOnboarding = prefs.getBool('completed_onboarding') ?? false;

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeNotifier>(
          create: (_) => ThemeNotifier()..loadThemeMode(),
        ),
        ChangeNotifierProvider<LgService>(create: (_) => LgService()),
        ChangeNotifierProvider<TextToSpeechService>(
          create: (_) => TextToSpeechService(),
        ),
        ProxyProvider<LgService, LgAdapter>(
          update: (_, lgService, __) => LgAdapter(lgService),
        ),
        ProxyProvider<LgService, TrackIpLgService>(
          update: (_, lgService, __) => TrackIpLgService(lgService),
        ),
        Provider<GeminiService>(create: (_) => GeminiService()),
        ChangeNotifierProvider<AttackProvider>(
          create: (_) => AttackProvider(repository),
        ),
        ChangeNotifierProvider<TrackIpProvider>(
          create: (_) => TrackIpProvider(trackRepository),
        ),
        ChangeNotifierProvider<HistoricalProvider>(
          create: (_) => HistoricalProvider(historicalRepository),
        ),
      ],
      child: MainApp(completedOnboarding: completedOnboarding),
    ),
  );
}

class MainApp extends StatelessWidget {
  final bool completedOnboarding;
  const MainApp({super.key, required this.completedOnboarding});

  @override
  Widget build(BuildContext context) {
    final themeNotifier = context.watch<ThemeNotifier>();
    return MaterialApp(
      title: 'cyber visualiser Dashboard',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: themeNotifier.themeMode,
      home: completedOnboarding ? const AppShell() : const OnboardingScreen(),
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
    SimulateAttackPage(),
    HistoricalScreen(),
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
              padding: const EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 8.0),
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
                    size: 32,
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'CYBER VISUALISER',
                    style: TextStyle(
                      fontSize: 20,
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
                    icon: Icons.history_edu_rounded,
                    title: 'Historical Attacks',
                    index: 4,
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    icon: Icons.location_on_rounded,
                    title: 'Track IP',
                    index: 2,
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    icon: Icons.psychology_outlined,
                    title: 'Attack Simulator',
                    index: 3,
                    isDark: isDark,
                  ),
                  _buildDrawerItem(
                    icon: Icons.settings_rounded,
                    title: 'Connection Settings',
                    index: 1,
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
