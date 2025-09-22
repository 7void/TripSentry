import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:shared_preferences/shared_preferences.dart';
// zone_config is no longer needed for this screen; using hazard_zones instead.
import '../services/hazard_zones.dart';

class GeoFencingScreen extends StatefulWidget {
  const GeoFencingScreen({super.key});

  @override
  State<GeoFencingScreen> createState() => _GeoFencingScreenState();
}

class _GeoFencingScreenState extends State<GeoFencingScreen> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(12.8447, 80.1537); // default start
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  bool _soundEnabled = true;
  late SharedPreferences _prefs;
  StreamSubscription<geo.Position>? _positionSub;
  bool _disposed = false;

  @override
  void initState() {
    super.initState();
    _loadPreferences();
    _checkPermissionAndStartTracking();
    _buildHazardCircles();
  }

  // Load toggle state
  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _soundEnabled = _prefs.getBool('soundEnabled') ?? true;
    setState(() {});
  }

  Future<void> _saveSoundPreference(bool value) async {
    await _prefs.setBool('soundEnabled', value);
  }

  Future<void> _checkPermissionAndStartTracking() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      return Future.error('Location services are disabled.');
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    _positionSub?.cancel();
    _positionSub = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((geo.Position position) {
      if (!mounted || _disposed) return;
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _updateMarker();
      });
      if (!mounted || _disposed) return;
      _moveCameraToCurrentPosition();
      // Removed manual _checkUnsafeZones() to avoid duplicate alert creation; relying on geofence ENTER events.
    });
  }

  // Build hazard circles with color by severity
  void _buildHazardCircles() {
    _circles.clear();
    for (final hz in hazardZones) {
      final color = () {
        switch (hz.severity) {
          case HazardSeverity.mild:
            return Colors.yellow;
          case HazardSeverity.moderate:
            return Colors.orange;
          case HazardSeverity.severe:
            return Colors.red;
        }
      }();
      _circles.add(
        Circle(
          circleId: CircleId(hz.id),
          center: hz.center,
          radius: hz.radiusMeters.toDouble(),
          fillColor: color.withOpacity(0.25),
          strokeColor: color,
          strokeWidth: 2,
        ),
      );
    }
    if (mounted && !_disposed) setState(() {});
  }

  void _updateMarker() {
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('currentLocation'),
        position: _currentPosition,
        infoWindow: const InfoWindow(title: 'You are here'),
      ),
    );
  }

  void _moveCameraToCurrentPosition() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition, zoom: 16),
        ),
      );
    }
  }

  // Removed distance-based polling and background geofence setup from the screen.

  // Initial-inside evaluation and notifications removed from the screen; background service is the source of truth.

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geo Fencing Map'),
        actions: [
          Row(
            children: [
              const Text("Sound"),
              Switch(
                value: _soundEnabled,
                onChanged: (val) {
                  _soundEnabled = val;
                  if (mounted && !_disposed) setState(() {});
                  _saveSoundPreference(val);
                },
              ),
            ],
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition:
            CameraPosition(target: _currentPosition, zoom: 16),
        markers: _markers,
        circles: _circles,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
          _moveCameraToCurrentPosition();
        },
        onLongPress: (position) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Zone editing not available in this view'),
                backgroundColor: Colors.blue),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
    _disposed = true;
    _positionSub?.cancel();
    _mapController?.dispose();
    super.dispose();
  }
}
