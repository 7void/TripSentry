import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:geofence_service/geofence_service.dart' as gf;
import 'package:geolocator/geolocator.dart' as geo;
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../services/alert_service.dart';
import '../services/hazard_zones.dart';
import '../services/risk_score_service.dart';

/// Headless-style geofencing handler that stays active regardless of the UI screen.
/// It listens to auth state and starts/stops accordingly. On Android, the
/// geofence_service package handles background callbacks.
class GeofenceBackgroundService {
  GeofenceBackgroundService._();
  static final GeofenceBackgroundService instance =
      GeofenceBackgroundService._();

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
  StreamSubscription<RiskScoreUpdate>? _riskSub;

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
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
        // Initialize risk score service when a user signs in.
        await RiskScoreService.instance.init();
        // Subscribe to risk score updates and sync to Firestore
        _riskSub?.cancel();
        _riskSub = RiskScoreService.instance.stream.listen((update) async {
          final uid = _auth.currentUser?.uid;
          if (uid == null) return;
          try {
            await FirebaseFirestore.instance.collection('users').doc(uid).set({
              'safetyScore':
                  double.parse(update.safetyScore.toStringAsFixed(2)),
              'riskExposure':
                  double.parse(update.riskExposure.toStringAsFixed(4)),
              'safetyCategory': update.category,
              'riskFactor': RiskScoreService.instance.factor,
              'safetyScoreUpdatedAt': FieldValue.serverTimestamp(),
            }, SetOptions(merge: true));
          } catch (e) {
            debugPrint('[GeofenceBG] Failed to sync Safety Score: $e');
          }
        });
        // Ensure Firestore has an initial snapshot
        await _syncCurrentRiskScoreIfAny();
        await start();
      } else {
        await _riskSub?.cancel();
        _riskSub = null;
        await stop();
      }
    });
  }

  Future<void> start() async {
    if (_started) return;

    // Permissions (best-effort; UI should have requested persistent permissions earlier)
    final locAlways = await Permission.locationAlways.request();
    if (!locAlways.isGranted) {
      debugPrint(
          '[GeofenceBG] locationAlways not granted; geofencing may not run in background.');
    }
    await Permission.notification.request();

    // Build geofence list from hazard zones (all severities are treated as hazards)
    final List<gf.Geofence> geofenceList = hazardZones
        .map((hz) => gf.Geofence(
              id: hz.id,
              latitude: hz.center.latitude,
              longitude: hz.center.longitude,
              radius: [
                gf.GeofenceRadius(
                    id: 'r_${hz.radiusMeters}',
                    length: hz.radiusMeters.toDouble())
              ],
            ))
        .toList(growable: false);

    _service.addGeofenceStatusChangeListener(
      (gf.Geofence geofence, gf.GeofenceRadius radius, gf.GeofenceStatus status,
          gf.Location location) async {
        // Resolve severity for nicer notification text
        HazardSeverity? severityFor(String id) {
          for (final hz in hazardZones) {
            if (hz.id == id) return hz.severity;
          }
          return null;
        }

        final sev = severityFor(geofence.id);
        final isHazard = sev != null; // all listed zones are hazards
        if (status == gf.GeofenceStatus.ENTER) {
          if (isHazard) {
            final title = switch (sev) {
              HazardSeverity.mild => '⚠️ Entered Mild Hazard',
              HazardSeverity.moderate => '⚠️ Entered Moderate Hazard',
              HazardSeverity.severe => '🚨 Entered Severe Hazard',
            };
            await _notify(title, 'You entered ${geofence.id}');
            // Start risk session on ENTER
            await RiskScoreService.instance.onEnter(
              geofence.id,
              sev,
              startTime: DateTime.now(),
            );
            AlertService.instance.createGeofencingAlert(
              zoneId: geofence.id,
              latitude: location.latitude,
              longitude: location.longitude,
            );
          } else {
            await _notify('ℹ️ Entered Zone', 'You entered ${geofence.id}');
          }
        } else if (status == gf.GeofenceStatus.EXIT) {
          if (isHazard) {
            // End risk session on EXIT
            await RiskScoreService.instance.onExit(
              geofence.id,
              sev,
              endTime: DateTime.now(),
            );
            AlertService.instance.resolveGeofencingAlert(geofence.id);
            await _notify('✅ Left Hazard Zone', 'You exited ${geofence.id}');
          } else {
            await _notify('ℹ️ Left Zone', 'You left ${geofence.id}');
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
    // Finalize ongoing risk sessions up to now
    try {
      await RiskScoreService.instance.finalizeAllActive();
    } catch (e) {
      debugPrint('[GeofenceBG] finalizeAllActive failed: $e');
    }
    await _service.stop();
    _started = false;
  }

  Future<void> _syncCurrentRiskScoreIfAny() async {
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;
    try {
      final snap = RiskScoreService.instance.snapshot();
      await FirebaseFirestore.instance.collection('users').doc(uid).set({
        'safetyScore': double.parse(
            (snap['safetyScore'] as double? ?? 100.0).toStringAsFixed(2)),
        'riskExposure': double.parse(
            (snap['riskExposure'] as double? ?? 0.0).toStringAsFixed(4)),
        'safetyCategory': (snap['category'] as String? ?? 'Safe'),
        'riskFactor': (snap['factor'] as double? ?? 2.0),
        'safetyScoreUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[GeofenceBG] Initial Safety Score sync failed: $e');
    }
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
      for (final hz in hazardZones) {
        final distance = geo.Geolocator.distanceBetween(
          pos.latitude,
          pos.longitude,
          hz.center.latitude,
          hz.center.longitude,
        );
        if (distance <= hz.radiusMeters) {
          debugPrint(
              '[GeofenceBG] Already inside hazard ${hz.id} at service start.');
          // Begin a risk session from "now" for the zone we're already inside
          await RiskScoreService.instance.onEnter(hz.id, hz.severity);
          AlertService.instance.createGeofencingAlert(
            zoneId: hz.id,
            latitude: pos.latitude,
            longitude: pos.longitude,
          );
          await _notify('⚠️ Inside Hazard Zone', 'You are inside ${hz.id}');
          break; // only first matching zone
        }
      }
    } catch (e) {
      debugPrint('[GeofenceBG] initial-inside evaluation failed: $e');
    }
  }
}
