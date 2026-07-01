import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/attack_event.dart';
import '../repositories/attack_repository.dart';
import '../services/lg_adapter.dart';
import '../utils/config.dart';

class AttackProvider extends ChangeNotifier {
  final AttackRepository _repository;
  final List<AttackEvent> _events = [];

  bool _isLoading = false;
  String? _errorMessage;
  DateTime? _lastFetchTime;
  Timer? _pollTimer;

  List<AttackEvent> get events => _events;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  DateTime? get lastFetchTime => _lastFetchTime;
  bool get isPollingActive => _pollTimer != null;

  // Live Statistics Getters
  int get totalEvents => _events.length;

  int get uniqueSourceIps {
    final ips = _events
        .map((e) => e.sourceIp)
        .where((ip) => ip.isNotEmpty)
        .toSet();
    return ips.length;
  }

  int get uniqueCountries {
    final countries = _events
        .map((e) => e.countryCode)
        .where((c) => c.isNotEmpty)
        .toSet();
    return countries.length;
  }

  int get uniqueAsns {
    final asns = _events.map((e) => e.asnNumber).where((a) => a > 0).toSet();
    return asns.length;
  }

  AttackProvider(this._repository) {
    // Do not automatically start polling on initialization.
    // The API is only hit when the update button is pressed.
  }

  /// Starts polling threat events every 5 seconds (disabled for manual updates)
  void startPolling() {
    // Disabled: Telemetry is fetched manually via the update button.
  }

  /// Stops periodic polling
  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
    notifyListeners();
  }

  /// Fetches new threat events and appends them to the live feed
  Future<void> fetchRecentTelemetry({int minutes = 15}) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final now = DateTime.now();
      // Look back a few minutes to catch any scan logs in the queue
      final since = now.subtract(Duration(minutes: minutes));

      final newEvents = await _repository.fetchNewEvents(
        since: since,
        until: now,
      );

      if (newEvents.isNotEmpty) {
        // Prepend new events so that newest attacks display first
        _events.insertAll(0, newEvents);

        // Keep feed memory in check (max 500 events)
        if (_events.length > 100) {
          _events.removeRange(100, _events.length);
        }
      }

      _lastFetchTime = DateTime.now();
      _errorMessage = null;
    } catch (e) {
      debugPrint('HoneyVision Provider Error: $e');
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Triggers Liquid Galaxy visualization via the adapter
  Future<bool> triggerVisualization(
    LgAdapter adapter,
    AttackEvent event,
  ) async {
    return await adapter.visualizeOnLG(event);
  }

  /// List of distinct attack categories supported by the application
  static const List<String> categories = [
    'DDOS attacks',
    'SSH attacks',
    'malware',
    'brute force',
    'other',
  ];

  /// Groups currently fetched events by their categorized type
  Map<String, List<AttackEvent>> getGroupedEvents() {
    final Map<String, List<AttackEvent>> groups = {
      'DDOS attacks': [],
      'SSH attacks': [],
      'malware': [],
      'brute force': [],
      'other': [],
    };
    for (final event in _events) {
      final category = event.attackCategory;
      if (groups.containsKey(category)) {
        groups[category]!.add(event);
      } else {
        groups['other']!.add(event);
      }
    }
    return groups;
  }

  @override
  void dispose() {
    stopPolling();
    super.dispose();
  }
}
