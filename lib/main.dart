import 'dart:ui';
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
  late final PageController _pageController;

  final List<Widget> _pages = const [
    DashboardScreen(),
    HistoricalScreen(),
    TrackIpPage(),
    SimulateAttackPage(),
    SettingsPage(),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    if (widget.autoInitializeConnection) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        context.read<LgService>().initializeConnection().catchError((e) {
          debugPrint('Failed to auto-initialize LG connection: $e');
        });
      });
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    if (_selectedIndex == index) return;
    setState(() {
      _selectedIndex = index;
    });
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeInOutCubic,
    );
  }

  Widget _buildBottomNavBar(bool isDark) {
    final activeColor = isDark
        ? const Color(0xFF00E5FF)
        : const Color(0xFF3B82F6);
    final inactiveColor = isDark ? Colors.white38 : Colors.black38;
    final backgroundColor = isDark
        ? const Color(0xCC0D1124)
        : Colors.white.withOpacity(0.85);
    final borderColor = isDark
        ? Colors.white.withOpacity(0.08)
        : Colors.black.withOpacity(0.05);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      height: 68,
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: borderColor, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: isDark
                ? const Color(0xFF00E5FF).withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10.0, sigmaY: 10.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                0,
                Icons.dashboard_rounded,
                'Dashboard',
                activeColor,
                inactiveColor,
              ),
              _buildNavItem(
                1,
                Icons.history_edu_rounded,
                'Historical',
                activeColor,
                inactiveColor,
              ),
              _buildNavItem(
                2,
                Icons.location_on_rounded,
                'Track IP',
                activeColor,
                inactiveColor,
              ),
              _buildNavItem(
                3,
                Icons.psychology_rounded,
                'Simulator',
                activeColor,
                inactiveColor,
              ),
              _buildNavItem(
                4,
                Icons.settings_rounded,
                'Settings',
                activeColor,
                inactiveColor,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem(
    int index,
    IconData icon,
    String label,
    Color activeColor,
    Color inactiveColor,
  ) {
    final isSelected = _selectedIndex == index;
    return Expanded(
      child: GestureDetector(
        onTap: () => _onItemTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected
                    ? activeColor.withOpacity(0.08)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: isSelected ? activeColor : inactiveColor,
                size: 22,
              ),
            ),
            const SizedBox(height: 2),
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: TextStyle(
                fontSize: 9,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? activeColor : inactiveColor,
                letterSpacing: 0.5,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      extendBody: true,
      body: PageView(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        children: _pages,
      ),
      bottomNavigationBar: _buildBottomNavBar(isDark),
    );
  }
}
