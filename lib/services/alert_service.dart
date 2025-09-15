import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

class AlertService {
  AlertService._();
  static final instance = AlertService._();
  final _fs = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  DateTime? _lastGeofenceAlertTime;
  String? _lastZoneId;
  final Duration debounce = const Duration(minutes: 2);
  bool _inFlight = false; // simple in-memory mutex for concurrent triggers
  final Duration staleThreshold = const Duration(minutes: 5);

  /// Resolve (archive) an existing active geofencing alert for a given zone.
  Future<void> resolveGeofencingAlert(String zoneId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    final activeItems = _fs
        .collection('users')
        .doc(user.uid)
        .collection('alerts')
        .doc('active')
        .collection('items');
    try {
      final snapshot = await activeItems
          .where('type', isEqualTo: 'geofencing')
          .where('extra.zoneId', isEqualTo: zoneId)
          .where('resolvedAt', isNull: true)
          .limit(1)
          .get();
      if (snapshot.docs.isEmpty) return;
      await snapshot.docs.first.reference.update({
        'resolvedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[AlertService] Resolved geofence alert zoneId=$zoneId');
    } catch (e) {
      debugPrint('[AlertService] ERROR resolving geofence alert: $e');
    }
  }

  /// Force create ignoring debounce & existing unresolved (used only for testing/manual override)
  Future<void> forceCreateGeofencingAlert({required String zoneId, required double latitude, required double longitude}) async {
    _lastGeofenceAlertTime = null;
    await createGeofencingAlert(zoneId: zoneId, latitude: latitude, longitude: longitude, allowStaleRewrite: true);
  }

  Future<void> createGeofencingAlert({
    required String zoneId,
    required double latitude,
    required double longitude,
    bool allowStaleRewrite = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[AlertService] Skipped createGeofencingAlert – no authenticated user.');
      return;
    }

    final now = DateTime.now();
    if (_inFlight) {
      debugPrint('[AlertService] Another alert creation in-flight; skipping. zoneId=$zoneId');
      return;
    }
    if (_lastZoneId == zoneId && _lastGeofenceAlertTime != null && now.difference(_lastGeofenceAlertTime!) < debounce) {
      debugPrint('[AlertService] Debounced geofence alert for zoneId=$zoneId');
      return;
    }

    final activeItems = _fs
        .collection('users')
        .doc(user.uid)
        .collection('alerts')
        .doc('active')
        .collection('items');

    try {
      _inFlight = true;
      debugPrint('[AlertService] Checking existing active geofence alerts for zoneId=$zoneId ...');
      final existing = await activeItems
          .where('type', isEqualTo: 'geofencing')
          .where('extra.zoneId', isEqualTo: zoneId)
          .where('resolvedAt', isNull: true)
          .limit(1)
          .get();
      if (existing.docs.isNotEmpty) {
        final doc = existing.docs.first;
        final rawTriggered = doc.data()['triggeredAt'];
        DateTime? triggeredAt;
        if (rawTriggered is Timestamp) {
          triggeredAt = rawTriggered.toDate();
        }
        final isStale = triggeredAt != null && now.difference(triggeredAt) > staleThreshold;
        if (!allowStaleRewrite && !isStale) {
          debugPrint('[AlertService] Existing unresolved alert (fresh) zoneId=$zoneId – skipping.');
          _lastZoneId = zoneId;
          _lastGeofenceAlertTime = now;
          return;
        }
        if (isStale) {
          debugPrint('[AlertService] Existing alert is stale (> ${staleThreshold.inMinutes}m). Resolving then creating new.');
          await doc.reference.update({'resolvedAt': FieldValue.serverTimestamp()});
        }
      }

      debugPrint('[AlertService] Writing new geofence alert (zoneId=$zoneId, lat=$latitude, lng=$longitude) ...');
      final docRef = await activeItems.add({
        'type': 'geofencing',
        'triggeredAt': FieldValue.serverTimestamp(),
        'resolvedAt': null,
        'location': {
          'latitude': latitude,
          'longitude': longitude,
        },
        'extra': {
          'zoneId': zoneId,
        }
      });
      debugPrint('[AlertService] Geofence alert created with id=${docRef.id}');
      _lastZoneId = zoneId;
      _lastGeofenceAlertTime = now;
    } catch (e, st) {
      debugPrint('[AlertService] ERROR creating geofence alert: $e');
      debugPrint(st.toString());
    } finally {
      _inFlight = false;
    }
  }
}
