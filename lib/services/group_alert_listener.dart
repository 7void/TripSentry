import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

/// Listens to group alerts for the current user and shows local notifications.
class GroupAlertListener {
  GroupAlertListener._();
  static final GroupAlertListener instance = GroupAlertListener._();

  final FirebaseFirestore _fs = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FlutterLocalNotificationsPlugin _notifs = FlutterLocalNotificationsPlugin();

  final List<StreamSubscription> _groupAlertSubs = [];
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _groupsIndexSub;
  bool _initialized = false;
  Future<void> initialize() async {
    if (_initialized) return;
    _initialized = true;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const init = InitializationSettings(android: android);
    await _notifs.initialize(init);
    // Android 13+ requires runtime notification permission. Use permission_handler for portability.
    try {
      final status = await Permission.notification.status;
      if (!status.isGranted) {
        await Permission.notification.request();
      }
    } catch (_) {}
  }

  Future<void> start() async {
    await initialize();
    await stop();
    final uid = _auth.currentUser?.uid;
    if (uid == null) return;

    // Subscribe to user's groups index, then attach listeners per group alerts
    _groupsIndexSub = _fs
        .collection('users')
        .doc(uid)
        .collection('groups')
        .snapshots()
        .listen((snap) {
      // Rebuild per-group alert listeners only (keep index subscription)
      for (final s in _groupAlertSubs.toList()) {
        s.cancel();
        _groupAlertSubs.remove(s);
      }
      for (final d in snap.docs) {
        final groupId = d.id;
        final s = _fs
            .collection('groups')
            .doc(groupId)
            .collection('alerts')
            .where('resolvedAt', isNull: true)
            .orderBy('triggeredAt', descending: true)
            .limit(5)
            .snapshots()
            .listen((alerts) {
          for (final a in alerts.docChanges) {
            if (a.type == DocumentChangeType.added) {
              final data = a.doc.data();
              if (data == null) continue;
              _showAlertNotification(groupId, data);
            }
          }
        });
        _groupAlertSubs.add(s);
      }
    });
  }

  Future<void> stop() async {
    for (final s in _groupAlertSubs) {
      await s.cancel();
    }
    _groupAlertSubs.clear();
    await _groupsIndexSub?.cancel();
    _groupsIndexSub = null;
  }

  Future<void> _showAlertNotification(String groupId, Map<String, dynamic> data) async {
    try {
      final type = (data['type'] ?? 'alert').toString();
      final title = type == 'geofencing'
          ? 'Group Alert: Hazard Entered'
          : type == 'emergency'
              ? 'Group Alert: Emergency'
              : 'Group Alert';
      final body = _buildBody(data);
      const androidDetails = AndroidNotificationDetails(
        'group_alerts',
        'Group Alerts',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
      );
      const details = NotificationDetails(android: androidDetails);
      await _notifs.show(0, title, body, details);
    } catch (e) {
      debugPrint('[GroupAlertListener] notification failed: $e');
    }
  }

  String _buildBody(Map<String, dynamic> data) {
    final triggeredBy = data['triggeredBy']?.toString() ?? 'a member';
    final type = (data['type'] ?? 'alert').toString();
    if (type == 'geofencing') {
      final zone = data['extra']?['zoneId']?.toString() ?? 'hazard zone';
      return '$triggeredBy entered $zone';
    }
    return '$triggeredBy triggered $type';
  }
}


