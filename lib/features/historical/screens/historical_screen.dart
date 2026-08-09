import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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

class _HistoricalScreenState extends State<HistoricalScreen> {
  @override
  void initState() {
    super.initState();
    // Load historical attacks data after the frame renders
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HistoricalProvider>().loadHistoricalAttacks();
    });
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

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'HISTORICAL DATABASE',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.5,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.menu),
          tooltip: 'Open drawer',
          onPressed: () {
            Scaffold.of(context).openDrawer();
          },
        ),
      ),
      body: Consumer<HistoricalProvider>(
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
                      color: isDark ? Colors.cyanAccent : Colors.indigo,
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
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.bold,
                        color: isDark
                            ? Colors.cyanAccent
                            : Colors.indigo.shade800,
                      ),
                    ),
                    if (provider.loading)
                      const SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    else
                      Text(
                        'Showing $totalIncidents of ${provider.allAttacks.length}',
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Colors.grey),
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
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 32.0),
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
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                ),
                                onPressed: () => provider.clearFilters(),
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
                          final attack = provider.filteredAttacks[index];
                          return IncidentCard(
                            attack: attack,
                            onTap: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) =>
                                      HistoricalDetailsScreen(attack: attack),
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
        backgroundColor: isDark ? Colors.cyanAccent : Colors.indigo,
        foregroundColor: isDark ? Colors.black : Colors.white,
        icon: const Icon(Icons.auto_awesome),
        label: const Text(
          'Ask Gemini',
          style: TextStyle(fontWeight: FontWeight.bold, letterSpacing: 0.5),
        ),
      ),
    );
  }
}
