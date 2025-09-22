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
  final Duration debounce = Duration.zero; // Debounce disabled to allow immediate re-alerts
  bool _inFlight = false; // simple in-memory mutex for concurrent triggers
  final Duration staleThreshold = const Duration(minutes: 5);
  // Keep track of most recent active alert docId per zone to enable fast resolution without query.
  final Map<String, String> _activeZoneAlertDocIds = {}; // zoneId -> docId

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
      // Prefer direct doc update if we have it cached.
      if (_activeZoneAlertDocIds.containsKey(zoneId)) {
        final docId = _activeZoneAlertDocIds[zoneId]!;
        final docRef = activeItems.doc(docId);
        final snap = await docRef.get();
        if (snap.exists) {
          final data = snap.data();
          if (data != null && data['resolvedAt'] == null) {
            await docRef.update({'resolvedAt': FieldValue.serverTimestamp()});
            debugPrint('[AlertService] Resolved (cached) geofence alert zoneId=$zoneId docId=$docId');
            await _archiveToPast(docRef);
            _activeZoneAlertDocIds.remove(zoneId);
          } else {
            debugPrint('[AlertService] Cached alert already resolved or missing field zoneId=$zoneId');
            // ensure it's archived if still in active
            try { await _archiveToPast(docRef); } catch (e) {
              debugPrint('[AlertService] Archive (cached) skipped/failed: $e');
            }
            _activeZoneAlertDocIds.remove(zoneId);
          }
        } else {
          debugPrint('[AlertService] Cached docId not found; falling back to query zoneId=$zoneId');
          _activeZoneAlertDocIds.remove(zoneId);
        }
      }

      if (!_activeZoneAlertDocIds.containsKey(zoneId)) {
        final snapshot = await activeItems
            .where('type', isEqualTo: 'geofencing')
            .where('extra.zoneId', isEqualTo: zoneId)
            .where('resolvedAt', isNull: true)
            .limit(1)
            .get();
        if (snapshot.docs.isEmpty) return;
        final docRef = snapshot.docs.first.reference;
        await docRef.update({
          'resolvedAt': FieldValue.serverTimestamp(),
        });
        debugPrint('[AlertService] Resolved (queried) geofence alert zoneId=$zoneId');
  await _archiveToPast(docRef);
        _activeZoneAlertDocIds.remove(zoneId); // remove mapping to avoid stale reference
      }
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
          try { await _archiveToPast(doc.reference); } catch (e) {
            debugPrint('[AlertService] Failed archiving stale alert: $e');
          }
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
      _activeZoneAlertDocIds[zoneId] = docRef.id; // cache for fast resolution
    } catch (e, st) {
      debugPrint('[AlertService] ERROR creating geofence alert: $e');
      debugPrint(st.toString());
    } finally {
      _inFlight = false;
    }
  }

  /// Create an immediate emergency alert under users/{uid}/alerts/active/items
  /// The payload mirrors other alerts with:
  /// - type: 'emergency'
  /// - triggeredAt: server timestamp
  /// - resolvedAt: null
  /// - location: { latitude, longitude } if provided
  /// - extra: optional map for additional context
  Future<void> createEmergencyAlert({
    double? latitude,
    double? longitude,
    Map<String, dynamic>? extra,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[AlertService] Skipped createEmergencyAlert – no authenticated user.');
      return;
    }

    final activeItems = _fs
        .collection('users')
        .doc(user.uid)
        .collection('alerts')
        .doc('active')
        .collection('items');

    try {
      final payload = <String, dynamic>{
        'type': 'emergency',
        'triggeredAt': FieldValue.serverTimestamp(),
        'resolvedAt': null,
      };
      if (latitude != null && longitude != null) {
        payload['location'] = {
          'latitude': latitude,
          'longitude': longitude,
        };
      }
      if (extra != null && extra.isNotEmpty) {
        payload['extra'] = extra;
      }
      final docRef = await activeItems.add(payload);
      debugPrint('[AlertService] Emergency alert created with id=${docRef.id}');
    } catch (e, st) {
      debugPrint('[AlertService] ERROR creating emergency alert: $e');
      debugPrint(st.toString());
    }
  }
  
  /// Copy active alert to users/{uid}/alerts/past/items/{id} and delete from active.
  Future<void> _archiveToPast(DocumentReference<Map<String, dynamic>> activeDocRef) async {
    final user = _auth.currentUser;
    if (user == null) {
      debugPrint('[AlertService] _archiveToPast skipped – no user.');
      return;
    }

    try {
      final pastDocRef = _fs
          .collection('users').doc(user.uid)
          .collection('alerts').doc('past')
          .collection('items').doc(activeDocRef.id);

      // Fetch once, then batch write to avoid transaction quirks and ensure immediate action
      final snap = await activeDocRef.get();
      if (!snap.exists) {
        debugPrint('[AlertService] _archiveToPast: active doc missing (already archived/deleted?) id=${activeDocRef.id}');
        return;
      }
      final data = Map<String, dynamic>.from(snap.data() ?? <String, dynamic>{});
      if (data['resolvedAt'] == null) {
        data['resolvedAt'] = FieldValue.serverTimestamp();
      }

      final batch = _fs.batch();
      batch.set(pastDocRef, data, SetOptions(merge: true));
      batch.delete(activeDocRef);
      await batch.commit();
      debugPrint('[AlertService] Archived alert to past and deleted active id=${activeDocRef.id}');
    } catch (e, st) {
      debugPrint('[AlertService] ERROR in _archiveToPast: $e');
      debugPrint(st.toString());
      rethrow;
    }
  }
}
