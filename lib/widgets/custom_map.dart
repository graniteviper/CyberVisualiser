import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'dart:math';
import 'package:provider/provider.dart';
import '../services/lg_service.dart';

class LookAt {
  final double longitude;
  final double latitude;
  final String range;
  final String tilt;
  final String heading;

  LookAt(this.longitude, this.latitude, this.range, this.tilt, this.heading);

  String generateLinearString() {
    return '<LookAt>'
        '<longitude>$longitude</longitude>'
        '<latitude>$latitude</latitude>'
        '<altitude>10</altitude>'
        '<heading>$heading</heading>'
        '<tilt>$tilt</tilt>'
        '<range>$range</range>'
        '<gx:altitudeMode>relativeToGround</gx:altitudeMode>'
        '</LookAt>';
  }
}

class MapPage extends StatefulWidget {
  const MapPage({super.key});

  @override
  State<MapPage> createState() => _MapPageState();
}

class _MapPageState extends State<MapPage> {
  late final MapController mapController;

  final LatLng _center = const LatLng(41.6177, 0.6200);

  double bearingvalue = 0.0;
  double longvalue = 0.6200;
  double latvalue = 41.6177;
  double tiltvalue = 0.0;
  late double zoomvalue;

  @override
  void initState() {
    super.initState();
    mapController = MapController();
    zoomvalue = 591657550.500000 / pow(2, 12.0 + 3);
  }

  void _onCameraMove(MapCamera camera) {
    longvalue = camera.center.longitude;
    latvalue = camera.center.latitude;
    bearingvalue = camera.rotation;
    zoomvalue = 591657550.500000 / pow(2, camera.zoom + 3);
  }

  void _onCameraIdle() async {
    final lgService = Provider.of<LgService>(context, listen: false);
    LookAt flyto = LookAt(
      longvalue,
      latvalue,
      zoomvalue.toString(),
      tiltvalue.toString(),
      bearingvalue.toString(),
    );
    try {
      await lgService.query('flytoview=${flyto.generateLinearString()}');
    } catch (e) {
      // Empty catch block as per original implementation
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Choose beautiful CartoDB map style matching current theme
    final urlTemplate = isDark
        ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
        : 'https://{s}.basemaps.cartocdn.com/rastertiles/voyager/{z}/{x}/{y}{r}.png';

    return Scaffold(
      body: FlutterMap(
        mapController: mapController,
        options: MapOptions(
          initialCenter: _center,
          initialZoom: 12.0,
          onPositionChanged: (camera, hasGesture) {
            _onCameraMove(camera);
          },
          onMapEvent: (event) {
            if (event is MapEventMoveEnd || event is MapEventRotateEnd) {
              _onCameraIdle();
            }
          },
        ),
        children: [
          TileLayer(
            urlTemplate: urlTemplate,
            subdomains: const ['a', 'b', 'c', 'd'],
            userAgentPackageName: 'com.graniteviper.cyber_visualiser',
          ),
          Positioned(
            bottom: 4,
            right: 4,
            child: Container(
              color: isDark ? Colors.black54 : Colors.white70,
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Text(
                '© CARTO, © OpenStreetMap contributors',
                style: TextStyle(
                  fontSize: 8,
                  color: isDark ? Colors.grey[400] : Colors.grey[800],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
