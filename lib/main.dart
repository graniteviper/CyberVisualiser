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
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()..loadThemeMode()),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (int index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_rounded),
            label: 'Connection Settings',
          ),
          NavigationDestination(
            icon: Icon(Icons.location_on_rounded),
            label: 'Track IP',
          ),
        ],
      ),
    );
  }
}
