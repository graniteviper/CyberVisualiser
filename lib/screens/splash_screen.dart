import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import 'onboarding_screen.dart';
import '../utils/config.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    _fadeAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeIn,
    );

    _animationController.forward();

    // Start timer to navigate after 3.5 seconds
    Timer(const Duration(milliseconds: 3500), _handleNavigation);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _handleNavigation() async {
    final prefs = await SharedPreferences.getInstance();
    final completedOnboarding = prefs.getBool('completed_onboarding') ?? false;

    final hasApiKeys =
        AppConfig.userApiKey.isNotEmpty &&
        AppConfig.userAbuseIpDbApiKey.isNotEmpty &&
        AppConfig.userGeminiApiKey.isNotEmpty;

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            (completedOnboarding && hasApiKeys)
            ? const AppShell()
            : const OnboardingScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = isDark
        ? const Color(0xFF00E5FF)
        : const Color(0xFF3B82F6);
    final backgroundColor = isDark
        ? const Color(0xFF070B19)
        : const Color(0xFFF8FAFC);
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: backgroundColor,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fadeAnimation,
          child: Stack(
            children: [
              // Main content in the center
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Central Dual Branding (GSoC Main and Mascot beside it)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // GSoC Image (Main)
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: activeColor.withOpacity(0.25),
                                blurRadius: 25,
                                spreadRadius: 3,
                              ),
                            ],
                            border: Border.all(
                              color: activeColor.withOpacity(0.4),
                              width: 2.0,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: Image.asset(
                              'assets/images/gesoc.webp',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        // Mascot Image (Beside it)
                        Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: activeColor.withOpacity(0.25),
                                blurRadius: 25,
                                spreadRadius: 3,
                              ),
                            ],
                            border: Border.all(
                              color: activeColor.withOpacity(0.4),
                              width: 2.0,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(60),
                            child: Image.asset(
                              'assets/images/liquidgalaxymascot.jpg',
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Title
                    Text(
                      'CYBER VISUALISER',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: titleColor,
                        letterSpacing: 2.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Subtitle
                    Text(
                      'Real-time Threat Maps & Globe Visuals',
                      style: TextStyle(
                        fontSize: 12,
                        color: subtitleColor,
                        fontWeight: FontWeight.w500,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    // Fading dot loader
                    SizedBox(
                      width: 40,
                      child: LinearProgressIndicator(
                        backgroundColor: activeColor.withOpacity(0.1),
                        valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                        minHeight: 3,
                      ),
                    ),
                  ],
                ),
              ),
              // Partner branding at the bottom
              Align(
                alignment: Alignment.bottomCenter,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'POWERED BY',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: subtitleColor.withOpacity(0.7),
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildLogoItem(
                            'assets/images/liquidgalaxy.png',
                            'Liquid Galaxy',
                          ),
                          const SizedBox(width: 16),
                          _buildLogoItem(
                            'assets/images/gemini.jpg',
                            'Google Gemini',
                          ),
                          const SizedBox(width: 16),
                          _buildLogoItem(
                            'assets/images/abuseipdb.png',
                            'AbuseIPDB',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoItem(String assetPath, String tooltip) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 85,
        height: 70,
        padding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 8,
        ), // Padding tailored for logos
        decoration: BoxDecoration(
          color: Colors
              .white, // Solid white background makes all logos fully visible
          borderRadius: BorderRadius.circular(
            16,
          ), // Premium rounded corners instead of circle
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
          border: Border.all(
            color: isDark
                ? Colors.white.withOpacity(0.15)
                : Colors.black.withOpacity(0.08),
            width: 1.2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain, // Fit fully within the container card
            errorBuilder: (context, error, stackTrace) {
              return const Icon(
                Icons.broken_image_rounded,
                size: 28,
                color: Colors.grey,
              );
            },
          ),
        ),
      ),
    );
  }
}
