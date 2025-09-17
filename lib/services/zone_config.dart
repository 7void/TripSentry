import 'package:google_maps_flutter/google_maps_flutter.dart';

// Centralized geofence configuration so both background service and UI use the same data.

const double kGeofenceRadiusMeters = 115.0;

// Unsafe zones (red)
const List<LatLng> kUnsafeZones = [
  LatLng(12.844254, 80.151632),
];

// Safe zones (green)
const List<LatLng> kSafeZones = [
  LatLng(13.0827, 80.2707),
];

String formatZoneId(LatLng zone) =>
    'zone_${zone.latitude.toStringAsFixed(6)}_${zone.longitude.toStringAsFixed(6)}';
