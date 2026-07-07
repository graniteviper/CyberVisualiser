import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
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
        '<altitude>0</altitude>'
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
  late GoogleMapController mapController;

  final LatLng _center = const LatLng(41.6177, 0.6200);

  double bearingvalue = 0.0;
  double longvalue = 0.6200;
  double latvalue = 41.6177;
  double tiltvalue = 0.0;
  late double zoomvalue;

  @override
  void initState() {
    super.initState();
    zoomvalue = 591657550.500000 / pow(2, 12.0);
  }

  void _onMapCreated(GoogleMapController controller) {
    mapController = controller;
  }

  void _onCameraMove(CameraPosition position) {
    bearingvalue = position.bearing;
    longvalue = position.target.longitude;
    latvalue = position.target.latitude;
    tiltvalue = position.tilt;
    zoomvalue = 591657550.500000 / pow(6, position.zoom);
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
    return Scaffold(
      body: GoogleMap(
        onMapCreated: (controller) {
          setState(() {
            mapController = controller;
          });
        },
        initialCameraPosition: CameraPosition(
          target: _center,
          zoom: 12,
          bearing: bearingvalue,
          tilt: tiltvalue,
        ),
        onCameraMove: _onCameraMove,
        onCameraIdle: _onCameraIdle,
      ),
    );
  }
}
