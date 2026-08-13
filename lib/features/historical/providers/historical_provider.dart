import 'package:flutter/material.dart';
import '../models/historical_attack.dart';
import '../repository/historical_repository.dart';

/// Provider for managing state and business logic of the Historical Attacks feature.
class HistoricalProvider extends ChangeNotifier {
  final HistoricalRepository _repository;

  bool _loading = false;
  List<HistoricalAttack> _allAttacks = [];
  List<HistoricalAttack> _filteredAttacks = [];

  String? _selectedCountry;
  String? _selectedCategory;
  String? _selectedSector;
  int? _selectedYear;
  String _searchQuery = "";

  HistoricalProvider(this._repository);

  // Getters for states
  bool get loading => _loading;
  List<HistoricalAttack> get allAttacks => _allAttacks;
  List<HistoricalAttack> get filteredAttacks => _filteredAttacks;
  String? get selectedCountry => _selectedCountry;
  String? get selectedCategory => _selectedCategory;
  String? get selectedSector => _selectedSector;
  int? get selectedYear => _selectedYear;
  String get searchQuery => _searchQuery;

  // Computed getters derived dynamically from all attacks
  List<String> get countries {
    final uniqueCountries = _allAttacks
        .map((a) => a.victim.country)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    uniqueCountries.sort();
    return uniqueCountries;
  }

  List<String> get categories {
    final uniqueCategories = _allAttacks
        .map((a) => a.attack.category)
        .where((c) => c.isNotEmpty)
        .toSet()
        .toList();
    uniqueCategories.sort();
    return uniqueCategories;
  }

  List<String> get sectors {
    final uniqueSectors = _allAttacks
        .map((a) => a.attack.targetSector)
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();
    uniqueSectors.sort();
    return uniqueSectors;
  }

  List<int> get years {
    final uniqueYears = _allAttacks.map((a) => a.year).toSet().toList();
    uniqueYears.sort(
      (a, b) => b.compareTo(a),
    ); // Descending order (newest years first)
    return uniqueYears;
  }

  /// Loads historical cyber attacks from the repository.
  Future<void> loadHistoricalAttacks() async {
    _loading = true;
    notifyListeners();

    try {
      _allAttacks = await _repository.getHistoricalAttacks();
      _applyFilters();
    } catch (e) {
      debugPrint("Error in HistoricalProvider.loadHistoricalAttacks: $e");
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Filters the incidents list using search query.
  void search(String query) {
    _searchQuery = query;
    _applyFilters();
  }

  /// Filters the incidents list by victim country.
  void filterCountry(String? country) {
    _selectedCountry = country;
    _applyFilters();
  }

  /// Filters the incidents list by attack category.
  void filterCategory(String? category) {
    _selectedCategory = category;
    _applyFilters();
  }

  /// Filters the incidents list by target sector.
  void filterSector(String? sector) {
    _selectedSector = sector;
    _applyFilters();
  }

  /// Filters the incidents list by attack year.
  void filterYear(int? year) {
    _selectedYear = year;
    _applyFilters();
  }

  /// Resets all filters and search query.
  void clearFilters() {
    _selectedCountry = null;
    _selectedCategory = null;
    _selectedSector = null;
    _selectedYear = null;
    _searchQuery = "";
    _applyFilters();
  }

  /// Combines all active filters and search query, updating [filteredAttacks].
  void _applyFilters() {
    var attacks = _allAttacks;

    // Apply search query (case-insensitive) on: title, victim.name, attacker.name, summary, tags
    if (_searchQuery.trim().isNotEmpty) {
      final query = _searchQuery.toLowerCase().trim();
      attacks = attacks.where((attack) {
        final titleMatch = attack.title.toLowerCase().contains(query);
        final victimMatch = attack.victim.name.toLowerCase().contains(query);
        final attackerMatch = attack.attacker.name.toLowerCase().contains(
          query,
        );
        final summaryMatch = attack.summary.toLowerCase().contains(query);
        final tagsMatch = attack.tags.any(
          (tag) => tag.toLowerCase().contains(query),
        );
        return titleMatch ||
            victimMatch ||
            attackerMatch ||
            summaryMatch ||
            tagsMatch;
      }).toList();
    }

    // Apply country filter
    if (_selectedCountry != null) {
      attacks = attacks
          .where((a) => a.victim.country == _selectedCountry)
          .toList();
    }

    // Apply category filter
    if (_selectedCategory != null) {
      attacks = attacks
          .where((a) => a.attack.category == _selectedCategory)
          .toList();
    }

    // Apply target sector filter
    if (_selectedSector != null) {
      attacks = attacks
          .where((a) => a.attack.targetSector == _selectedSector)
          .toList();
    }

    // Apply year filter
    if (_selectedYear != null) {
      attacks = attacks.where((a) => a.year == _selectedYear).toList();
    }

    _filteredAttacks = attacks;
    notifyListeners();
  }
}
