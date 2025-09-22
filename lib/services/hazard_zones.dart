import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Severity levels for hazard zones displayed on the map.
enum HazardSeverity { mild, moderate, severe }

/// A single hazard zone definition.
class HazardZone {
  final String id;
  final LatLng center;
  final int radiusMeters;
  final HazardSeverity severity;

  const HazardZone({
    required this.id,
    required this.center,
    required this.radiusMeters,
    required this.severity,
  });
}

/// Centralized list of hazard zones to render on the GeoFencing screen.
/// Colors are applied in the UI based on the [severity].
const List<HazardZone> hazardZones = [
  // Mild (Yellow)
  HazardZone(
    id: 'hz_mild_1',
    center: LatLng(12.843592151449828, 80.15248982338552),
    radiusMeters: 50,
    severity: HazardSeverity.mild,
  ),
  // Moderate (Orange)
  HazardZone(
    id: 'hz_moderate_1',
    center: LatLng(12.842498245996257, 80.15327882298878),
    radiusMeters: 50,
    severity: HazardSeverity.moderate,
  ),
  // Severe (Red)
  HazardZone(
    id: 'hz_severe_1',
    center: LatLng(12.844422732442604, 80.15258905201247),
    radiusMeters: 30,
    severity: HazardSeverity.severe,
  ),
];
