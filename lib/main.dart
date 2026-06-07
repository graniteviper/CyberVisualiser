import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'services/lg_service.dart';
import 'theme/theme_notifier.dart';
import 'theme/app_theme.dart';
import 'pages/home_page.dart';
import 'pages/settings_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeNotifier>(create: (_) => ThemeNotifier()..loadThemeMode()),
        ChangeNotifierProvider<LgService>(create: (_) => LgService()),
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
      title: 'Cyber Attack Visualiser',
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
    HomePage(),
    SettingsPage(),
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
            icon: Icon(Icons.home),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
