import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cyber_visualiser/services/lg_service.dart';
import '../models/historical_attack.dart';
import '../providers/historical_provider.dart';
import '../widgets/historical_filter_bar.dart';
import '../widgets/historical_search_bar.dart';
import '../widgets/statistics_card.dart';
import '../widgets/incident_card.dart';
import '../widgets/historical_gemini_dialog.dart';
import 'historical_details_screen.dart';

/// Screen displaying the historical cyber attacks database with search, filter, and stats overview.
class HistoricalScreen extends StatefulWidget {
  const HistoricalScreen({super.key});

  @override
  State<HistoricalScreen> createState() => _HistoricalScreenState();
}

class _HistoricalScreenState extends State<HistoricalScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _pulseController.repeat(reverse: true);
    }
    // Load historical attacks data after the frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoricalProvider>().loadHistoricalAttacks();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  void _openGeminiAssistant(
    BuildContext context, {
    int? year,
    String? category,
    required List<HistoricalAttack> contextAttacks,
  }) {
    showDialog(
      context: context,
      builder: (context) => HistoricalGeminiDialog(
        year: year,
        category: category,
        contextAttacks: contextAttacks,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lgService = context.watch<LgService>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeaderBanner(context, isDark),
            _buildRigConnectionBar(lgService, isDark),
            Expanded(
              child: Consumer<HistoricalProvider>(
                builder: (context, provider, child) {
                  if (provider.loading && provider.allAttacks.isEmpty) {
                    return const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircularProgressIndicator(),
                          SizedBox(height: 16),
                          Text(
                            'Loading incidents database...',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ),
                    );
                  }

                  // Dynamically compute stats from filtered results
                  final totalIncidents = provider.filteredAttacks.length;
                  final uniqueCountriesCount = provider.filteredAttacks
                      .map((e) => e.victim.country)
                      .where((c) => c.isNotEmpty)
                      .toSet()
                      .length;
                  final uniqueCategoriesCount = provider.filteredAttacks
                      .map((e) => e.attack.category)
                      .where((c) => c.isNotEmpty)
                      .toSet()
                      .length;

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Search Bar
                      HistoricalSearchBar(
                        initialQuery: provider.searchQuery,
                        onChanged: (query) => provider.search(query),
                      ),

                      // Filter Chips Bar
                      HistoricalFilterBar(
                        countries: provider.countries,
                        categories: provider.categories,
                        sectors: provider.sectors,
                        years: provider.years,
                        selectedCountry: provider.selectedCountry,
                        selectedCategory: provider.selectedCategory,
                        selectedSector: provider.selectedSector,
                        selectedYear: provider.selectedYear,
                        onCountryChanged: (c) => provider.filterCountry(c),
                        onCategoryChanged: (c) => provider.filterCategory(c),
                        onSectorChanged: (s) => provider.filterSector(s),
                        onYearChanged: (y) => provider.filterYear(y),
                        onClearAll: () => provider.clearFilters(),
                      ),

                      const SizedBox(height: 8),

                      // Statistics Section
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 8.0,
                        ),
                        child: Row(
                          children: [
                            StatisticsCard(
                              title: 'Total Incidents',
                              value: totalIncidents.toString(),
                              icon: Icons.security,
                              color: isDark
                                  ? const Color(0xFF00E5FF)
                                  : const Color(0xFF3B82F6),
                            ),
                            const SizedBox(width: 12),
                            StatisticsCard(
                              title: 'Countries',
                              value: uniqueCountriesCount.toString(),
                              icon: Icons.public,
                              color: Colors.green,
                            ),
                            const SizedBox(width: 12),
                            StatisticsCard(
                              title: 'Categories',
                              value: uniqueCategoriesCount.toString(),
                              icon: Icons.category,
                              color: Colors.orange,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 8),

                      // Incident List Header
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16.0,
                          vertical: 4.0,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'INCIDENTS FEED',
                              style: TextStyle(
                                letterSpacing: 1.0,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                                color: isDark
                                    ? const Color(0xFF00E5FF)
                                    : const Color(0xFF3B82F6),
                              ),
                            ),
                            if (provider.loading)
                              const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            else
                              Text(
                                'Showing $totalIncidents of ${provider.allAttacks.length}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.grey,
                                ),
                              ),
                          ],
                        ),
                      ),

                      // Scrollable Incident List or Empty State
                      Expanded(
                        child: provider.filteredAttacks.isEmpty
                            ? Center(
                                child: SingleChildScrollView(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.find_in_page_outlined,
                                        size: 64,
                                        color: isDark
                                            ? Colors.grey.shade700
                                            : Colors.grey.shade400,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No cyber incidents found',
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleMedium
                                            ?.copyWith(
                                              fontWeight: FontWeight.bold,
                                            ),
                                      ),
                                      const SizedBox(height: 8),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 32.0,
                                        ),
                                        child: Text(
                                          'Try adjusting your search queries or clearing active filter chips.',
                                          textAlign: TextAlign.center,
                                          style: TextStyle(color: Colors.grey),
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      ElevatedButton.icon(
                                        style: ElevatedButton.styleFrom(
                                          minimumSize: const Size(160, 40),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                        ),
                                        onPressed: () =>
                                            provider.clearFilters(),
                                        icon: const Icon(Icons.refresh),
                                        label: const Text('Reset All Filters'),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                            : ListView.builder(
                                itemCount: provider.filteredAttacks.length,
                                physics: const AlwaysScrollableScrollPhysics(),
                                itemBuilder: (context, index) {
                                  final attack =
                                      provider.filteredAttacks[index];
                                  return IncidentCard(
                                    attack: attack,
                                    onTap: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              HistoricalDetailsScreen(
                                                attack: attack,
                                              ),
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final provider = context.read<HistoricalProvider>();
          _openGeminiAssistant(
            context,
            year: provider.selectedYear,
            category: provider.selectedCategory,
            contextAttacks: provider.filteredAttacks,
          );
        },
        backgroundColor: isDark
            ? const Color(0xFF00E5FF)
            : const Color(0xFF3B82F6),
        foregroundColor: isDark ? Colors.black : Colors.white,
        icon: const Icon(Icons.auto_awesome),
        label: const Text(
          'Ask Gemini',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }

  Widget _buildHeaderBanner(BuildContext context, bool isDark) {
    final titleColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final subtitleColor = isDark ? Colors.grey.shade400 : Colors.black54;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16.0, 16.0, 16.0, 8.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0D1124) : Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark ? const Color(0xFF1F294D) : Colors.grey.shade200,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? const Color(0xFF00E5FF).withOpacity(0.05)
                      : Colors.black.withOpacity(0.02),
                  blurRadius: 10,
                ),
              ],
            ),
            child: Icon(
              Icons.history_toggle_off,
              color: isDark ? const Color(0xFF00E5FF) : const Color(0xFF3B82F6),
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'HISTORICAL DATABASE',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    color: titleColor,
                    letterSpacing: 1.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Cyber Incident Archives & Reports',
                  style: TextStyle(
                    fontSize: 11,
                    color: subtitleColor,
                    fontWeight: FontWeight.w500,
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
    final statusColor = lgService.isConnected
        ? const Color(0xFF00FFC2)
        : Colors.redAccent;
    final statusText = lgService.isConnected ? "Rig Connected" : "Rig Offline";
    final activeGlowColor = lgService.isConnected
        ? const Color(0xFF00FFC2)
        : Colors.redAccent;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF0D1124) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? const Color(0xFF1F294D) : Colors.grey.shade200,
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, child) {
                    return Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: statusColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: activeGlowColor.withOpacity(
                              0.6 * _pulseController.value,
                            ),
                            blurRadius: 8 * _pulseController.value,
                            spreadRadius: 2 * _pulseController.value,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 10),
                Text(
                  '$statusText • ${lgService.connectionModel.ip}:${lgService.connectionModel.port}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : const Color(0xFF0F172A),
                  ),
                ),
              ],
            ),
            Text(
              lgService.isConnected ? 'Ready' : 'Offline',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: lgService.isConnected
                    ? const Color(0xFF00FFC2)
                    : Colors.grey,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
