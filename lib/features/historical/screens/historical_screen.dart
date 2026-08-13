import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cyber_visualiser/services/gemini_service.dart';
import 'package:cyber_visualiser/services/lg_service.dart';
import 'package:cyber_visualiser/services/text_to_speech_service.dart';
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
  late final TextToSpeechService _ttsService;
  late final LgService _lgService;
  late final HistoricalProvider _historicalProvider;

  @override
  void initState() {
    super.initState();
    _ttsService = Provider.of<TextToSpeechService>(context, listen: false);
    _lgService = Provider.of<LgService>(context, listen: false);
    _historicalProvider = Provider.of<HistoricalProvider>(
      context,
      listen: false,
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    if (!Platform.environment.containsKey('FLUTTER_TEST')) {
      _pulseController.repeat(reverse: true);
    }
    // Load historical attacks data after the frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _historicalProvider.loadHistoricalAttacks();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _historicalProvider.stopTour(_ttsService, _lgService);
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

  String _buildSearchContextText(HistoricalProvider provider) {
    final List<String> parts = [];
    if (provider.searchQuery.isNotEmpty) {
      parts.add('Search: "${provider.searchQuery}"');
    }
    if (provider.selectedYear != null) {
      parts.add('Year: ${provider.selectedYear}');
    }
    if (provider.selectedCategory != null) {
      parts.add('Category: ${provider.selectedCategory}');
    }
    if (provider.selectedCountry != null) {
      parts.add('Country: ${provider.selectedCountry}');
    }
    if (provider.selectedSector != null) {
      parts.add('Sector: ${provider.selectedSector}');
    }
    if (parts.isEmpty) {
      return 'All Incidents';
    }
    return parts.join(', ');
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final lgService = context.watch<LgService>();
    final activeColor = isDark
        ? const Color(0xFF00E5FF)
        : Theme.of(context).colorScheme.primary;

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

                      // Contextual Tour Request Banner or Tour Playback Panel
                      if (provider.isTourScriptLoading ||
                          provider.isTourPlaying ||
                          provider.isVisualized)
                        _buildCategoryTourPanel(
                          context,
                          provider,
                          _ttsService,
                          _lgService,
                          isDark,
                          activeColor,
                        )
                      else
                        _buildContextualTourRequestCard(
                          context,
                          provider,
                          Provider.of<GeminiService>(context, listen: false),
                          _lgService,
                          isDark,
                          activeColor,
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

  Widget _buildContextualTourRequestCard(
    BuildContext context,
    HistoricalProvider provider,
    GeminiService geminiService,
    LgService lgService,
    bool isDark,
    Color activeColor,
  ) {
    final hasSearchOrFilter =
        provider.searchQuery.isNotEmpty ||
        provider.selectedYear != null ||
        provider.selectedCategory != null ||
        provider.selectedCountry != null ||
        provider.selectedSector != null;

    if (!hasSearchOrFilter || provider.filteredAttacks.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: Card(
        color: isDark
            ? const Color(0xFF0D1124)
            : Colors.blue.shade50.withOpacity(0.3),
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isDark ? const Color(0xFF1F294D) : Colors.blue.shade100,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: activeColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.auto_awesome_motion,
                      color: activeColor,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Visualize Filtered as 3D Tour',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: isDark
                                ? Colors.white
                                : const Color(0xFF0F172A),
                          ),
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Generates a KML map and narrator script. Note: Uses only the top 10 incidents to optimize tokens.',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: activeColor,
                  foregroundColor: isDark ? Colors.black : Colors.white,
                  minimumSize: const Size.fromHeight(40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.explore_rounded, size: 18),
                label: const Text(
                  'GENERATE CATEGORY TOUR',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                onPressed: () {
                  final categoryText = _buildSearchContextText(provider);
                  provider.generateCategoryTour(
                    categoryText,
                    provider.filteredAttacks,
                    geminiService,
                    lgService,
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryTourPanel(
    BuildContext context,
    HistoricalProvider provider,
    TextToSpeechService ttsService,
    LgService lgService,
    bool isDark,
    Color activeColor,
  ) {
    if (provider.isTourScriptLoading) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1124) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF1F294D) : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  provider.statusMessage,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (provider.isTourPlaying) {
      final currentStep = provider.tourSteps[provider.currentTourStepIndex];
      final totalSteps = provider.tourSteps.length;
      final narration = currentStep['narration'] ?? '';
      final title = currentStep['title'] ?? 'Tour Step';

      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1124) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF1F294D) : Colors.grey.shade200,
            ),
            boxShadow: [
              BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: totalSteps == 0
                      ? 0.0
                      : (provider.currentTourStepIndex + 1) / totalSteps,
                  backgroundColor: isDark
                      ? Colors.blueGrey.shade900
                      : Colors.grey.shade200,
                  valueColor: AlwaysStoppedAnimation<Color>(activeColor),
                  minHeight: 4,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '3D CATEGORY TOUR',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: activeColor,
                      letterSpacing: 0.5,
                    ),
                  ),
                  Text(
                    'Step ${provider.currentTourStepIndex + 1} of $totalSteps',
                    style: const TextStyle(fontSize: 10, color: Colors.grey),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                title,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(10),
                constraints: const BoxConstraints(maxHeight: 60),
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF141A35) : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF1F294D)
                        : Colors.grey.shade100,
                  ),
                ),
                child: SingleChildScrollView(
                  child: Text(
                    narration,
                    style: TextStyle(
                      fontSize: 11,
                      height: 1.4,
                      color: isDark ? Colors.grey.shade300 : Colors.black87,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.skip_previous_rounded, size: 22),
                    color: isDark ? Colors.white70 : Colors.black87,
                    onPressed: provider.currentTourStepIndex == 0
                        ? null
                        : () => provider.previousStep(ttsService, lgService),
                  ),
                  const SizedBox(width: 12),
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: activeColor,
                    child: IconButton(
                      icon: Icon(
                        provider.isTourPaused
                            ? Icons.play_arrow_rounded
                            : Icons.pause_rounded,
                        size: 24,
                        color: isDark ? Colors.black : Colors.white,
                      ),
                      onPressed: () {
                        if (provider.isTourPaused) {
                          provider.resumeTour(ttsService, lgService);
                        } else {
                          provider.pauseTour(ttsService);
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  IconButton(
                    icon: Icon(
                      provider.currentTourStepIndex == totalSteps - 1
                          ? Icons.check_rounded
                          : Icons.skip_next_rounded,
                      size: 22,
                    ),
                    color: isDark ? Colors.white70 : Colors.black87,
                    onPressed: () => provider.nextStep(ttsService, lgService),
                  ),
                  const SizedBox(width: 20),
                  IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.redAccent.withOpacity(0.15),
                      foregroundColor: Colors.redAccent,
                      padding: const EdgeInsets.all(8),
                    ),
                    icon: const Icon(Icons.stop_rounded, size: 18),
                    onPressed: () => provider.stopTour(ttsService, lgService),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    if (provider.isVisualized) {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0D1124) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF1F294D) : Colors.grey.shade200,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: activeColor,
                    foregroundColor: isDark ? Colors.black : Colors.white,
                    minimumSize: const Size.fromHeight(40),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded, size: 20),
                  label: const Text(
                    'START TOUR',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => provider.startTour(ttsService, lgService),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.redAccent,
                  side: const BorderSide(color: Colors.redAccent),
                  minimumSize: const Size(100, 40),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                icon: const Icon(Icons.clear, size: 16),
                label: const Text('CLEAR', style: TextStyle(fontSize: 12)),
                onPressed: () {
                  provider.clearTourState();
                  lgService.cleanKML();
                },
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
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
