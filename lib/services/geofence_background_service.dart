import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofence_service/geofence_service.dart' as gf;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart';

import '../services/alert_service.dart';
import '../services/zone_config.dart';

/// Headless-style geofencing handler that stays active regardless of the UI screen.
/// It listens to auth state and starts/stops accordingly. On Android, the
/// geofence_service package handles background callbacks.
class GeofenceBackgroundService {
  GeofenceBackgroundService._();
  static final GeofenceBackgroundService instance = GeofenceBackgroundService._();

  final gf.GeofenceService _service = gf.GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    loiteringDelayMs: 60000,
    statusChangeDelayMs: 10000,
    useActivityRecognition: false,
    allowMockLocations: false,
    printDevLog: true,
  );

  final _auth = FirebaseAuth.instance;
  StreamSubscription<User?>? _authSub;
  bool _started = false;

  final FlutterLocalNotificationsPlugin _notifications = FlutterLocalNotificationsPlugin();
  bool _notificationsInit = false;

  Future<void> init() async {
    // Initialize notifications once
    if (!_notificationsInit) {
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);
      await _notifications.initialize(initializationSettings);
      _notificationsInit = true;
    }

    _authSub ??= _auth.authStateChanges().listen((u) async {
      if (u != null) {
        await start();
      } else {
        await stop();
      }
    });
  }

  Future<void> start() async {
    if (_started) return;

    // Permissions (best-effort; UI should have requested persistent permissions earlier)
    final locAlways = await Permission.locationAlways.request();
    if (!locAlways.isGranted) {
      debugPrint('[GeofenceBG] locationAlways not granted; geofencing may not run in background.');
    }
    await Permission.notification.request();

    // Build geofence list from config
    final List<gf.Geofence> geofenceList = [
      ...kUnsafeZones.map((LatLng zone) => gf.Geofence(
            id: formatZoneId(zone),
            latitude: zone.latitude,
            longitude: zone.longitude,
            radius: [gf.GeofenceRadius(id: 'r1', length: kGeofenceRadiusMeters)],
          )),
      ...kSafeZones.map((LatLng zone) => gf.Geofence(
            id: zone.toString(),
            latitude: zone.latitude,
            longitude: zone.longitude,
            radius: [gf.GeofenceRadius(id: 'r1', length: kGeofenceRadiusMeters)],
          )),
    ];

    _service.addGeofenceStatusChangeListener(
      (gf.Geofence geofence, gf.GeofenceRadius radius, gf.GeofenceStatus status, gf.Location location) async {
        final bool isUnsafeZone = geofence.id.startsWith('zone_');
        if (status == gf.GeofenceStatus.ENTER) {
          if (isUnsafeZone) {
            await _notify('⚠️ Entered Unsafe Zone', 'You entered ${geofence.id}');
            AlertService.instance.createGeofencingAlert(
              zoneId: geofence.id,
              latitude: location.latitude,
              longitude: location.longitude,
            );
          } else {
            await _notify('ℹ️ Entered Safe Zone', 'You entered a designated safe area');
          }
        } else if (status == gf.GeofenceStatus.EXIT) {
          if (isUnsafeZone) {
            AlertService.instance.resolveGeofencingAlert(geofence.id);
            await _notify('✅ Left Unsafe Zone', 'You exited ${geofence.id}');
          } else {
            await _notify('ℹ️ Left Safe Zone', 'You left a safe area');
          }
        }
      },
    );

    try {
      await _service.start(geofenceList);
      _started = true;
      // Evaluate immediately if already inside an unsafe zone.
      await _evaluateInitialInside();
    } catch (e) {
      debugPrint('[GeofenceBG] start failed: $e');
    }
  }

  Future<void> stop() async {
    if (!_started) return;
    await _service.stop();
    _started = false;
  }

  Future<void> _notify(String title, String body) async {
    final android = AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Alerts',
      channelDescription: 'Notifications for geofence events',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 1000, 500]),
    );
    final platform = NotificationDetails(android: android);
    await _notifications.show(0, title, body, platform);
  }

  Future<void> _evaluateInitialInside() async {
    try {
      final pos = await geo.Geolocator.getCurrentPosition(
        desiredAccuracy: geo.LocationAccuracy.high,
      );
      for (final zone in kUnsafeZones) {
        final distance = geo.Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          zone.latitude,
          zone.longitude,
        );
        if (distance <= kGeofenceRadiusMeters) {
          final zoneId = formatZoneId(zone);
          debugPrint('[GeofenceBG] Already inside unsafe zone $zoneId at service start.');
          AlertService.instance.createGeofencingAlert(
            zoneId: zoneId,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
          await _notify('⚠️ Inside Unsafe Zone', 'You are inside $zoneId');
          break; // only first matching zone
        }
      }
    } catch (e) {
      debugPrint('[GeofenceBG] initial-inside evaluation failed: $e');
    }
  }
}
