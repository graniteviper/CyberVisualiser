import '../models/abuse_report_model.dart';
import '../services/abuseipdb_service.dart';

class TrackIpRepository {
  final AbuseIpDbService _service;

  TrackIpRepository(this._service);

  /// Fetch threat details and attack logs for a specific IP address.
  Future<AbuseIpReport> getIpReport(String ipAddress, int maxAgeInDays) async {
    return await _service.fetchIpReport(
      ipAddress: ipAddress,
      maxAgeInDays: maxAgeInDays,
    );
  }
}
