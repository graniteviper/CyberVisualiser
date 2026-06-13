import 'package:flutter/foundation.dart';
import '../models/attack_event.dart';
import '../utils/country_coordinates.dart';
import 'lg_service.dart';

class LgAdapter {
  final LgService _lgService;

  // Predefined target coordinates (Default: Delhi, India)
  String _targetCountry = 'India (Delhi)';
  double _targetLat = 28.6139;
  double _targetLon = 77.2090;

  LgAdapter(this._lgService);

  String get targetCountry => _targetCountry;
  double get targetLat => _targetLat;
  double get targetLon => _targetLon;

  /// Update target coordinates configuration
  void updateTarget({required String country, required double lat, required double lon}) {
    _targetCountry = country;
    _targetLat = lat;
    _targetLon = lon;
  }

  /// Projects the attack vector KML and overlay card on Liquid Galaxy rig
  Future<bool> visualizeOnLG(AttackEvent event) async {
    if (!_lgService.isConnected) {
      debugPrint('HoneyVision LG Adapter: Liquid Galaxy is not connected.');
      return false;
    }

    try {
      // 1. Resolve source coordinate using country code
      final sourceCoord = CountryCoordinatesLookup.getCoordinate(event.countryCode);

      debugPrint('HoneyVision LG Adapter: Visualizing attack vector on LG '
          'from ${event.countryCode} (${sourceCoord.latitude}, ${sourceCoord.longitude}) '
          'to $_targetCountry ($_targetLat, $_targetLon)');

      // 2. Call KML projection method on the black-box LgService
      await _lgService.sendCyberAttackKML(
        attackName: event.displayTitle,
        sourceCountry: event.countryName.isNotEmpty ? event.countryName : event.countryCode,
        sourceLat: sourceCoord.latitude,
        sourceLon: sourceCoord.longitude,
        targetCountry: _targetCountry,
        targetLat: _targetLat,
        targetLon: _targetLon,
        severity: event.severity,
      );

      // 3. Call Overlay projection method on the black-box LgService
      // Commented out to prevent overwriting cyber_attack.kML in kmls.txt and displaying broken red cross overlays on offline VMs
      /*
      await _lgService.sendCyberAttackOverlayKML(
        attackName: event.displayTitle,
        sourceCountry: event.countryName.isNotEmpty ? event.countryName : event.countryCode,
        targetCountry: _targetCountry,
        severity: event.severity,
        ipAddress: event.sourceIp,
      );
      */

      return true;
    } catch (e) {
      debugPrint('HoneyVision LG Adapter Error: Failed to send KML visualization: $e');
      return false;
    }
  }
}
