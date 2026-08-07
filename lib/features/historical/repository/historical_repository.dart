import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/historical_attack.dart';

/// Repository responsible for loading and parsing historical cyber attacks data from local assets.
class HistoricalRepository {
  List<HistoricalAttack>? _cachedAttacks;

  /// Loads, parses, and returns the list of historical attacks.
  /// Subsequent calls return the cached data in memory.
  Future<List<HistoricalAttack>> getHistoricalAttacks() async {
    if (_cachedAttacks != null) {
      return _cachedAttacks!;
    }

    try {
      final jsonString = await rootBundle.loadString(
        'assets/data/historical_attacks.json',
      );
      final List<dynamic> jsonList = json.decode(jsonString);
      _cachedAttacks = jsonList
          .map(
            (item) => HistoricalAttack.fromJson(item as Map<String, dynamic>),
          )
          .toList();
      return _cachedAttacks!;
    } catch (e) {
      // Propagate error up to be handled by the caller/Provider
      rethrow;
    }
  }
}
