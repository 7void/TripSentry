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
    center: LatLng(12.8442, 80.1541),
    radiusMeters: 40,
    severity: HazardSeverity.mild,
  ),
  // Moderate (Orange)
  HazardZone(
    id: 'hz_moderate_1',
    center: LatLng(12.8432, 80.154),
    radiusMeters: 50,
    severity: HazardSeverity.moderate,
  ),
  // Severe (Red)
  HazardZone(
    id: 'hz_severe_1',
    center: LatLng(12.843, 80.1525),
    radiusMeters: 100,
    severity: HazardSeverity.severe,
  ),
];
