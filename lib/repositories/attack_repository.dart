import '../models/attack_event.dart';
import '../services/honeylabs_service.dart';

class AttackRepository {
  final HoneyLabsService _apiService;
  final Set<String> _processedIds = {};

  AttackRepository(this._apiService);

  /// Clears the processed cache (useful for testing or full refresh)
  void clearCache() {
    _processedIds.clear();
  }

  /// Fetches events from HoneyLabs and filters out duplicates based on eventId
  Future<List<AttackEvent>> fetchNewEvents({
    required DateTime since,
    required DateTime until,
    int limit = 100,
  }) async {
    final rawList = await _apiService.fetchRawEvents(
      since: since,
      until: until,
      limit: limit,
    );

    final List<AttackEvent> newEvents = [];
    for (final item in rawList) {
      try {
        final event = AttackEvent.fromJson(item);
        // Deduplicate: check if eventId is already processed
        if (event.eventId.isNotEmpty && !_processedIds.contains(event.eventId)) {
          _processedIds.add(event.eventId);
          newEvents.add(event);
        }
      } catch (e) {
        // Skip malformed records to ensure robustness
        print('HoneyVision Repository Warning: Skipped parsing malformed record: $e');
      }
    }

    return newEvents;
  }
}
