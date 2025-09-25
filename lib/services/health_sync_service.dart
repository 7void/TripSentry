import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'health_connect_service.dart';

/// Simple foreground sync loop that triggers a health sync every [interval].
///
/// Notes:
/// - Runs only while the app process is alive (foreground or with any foreground service you manage).
/// - Android system background schedulers (e.g., WorkManager) cannot run every 1 minute; this is a best-effort
///   in-process timer. For guaranteed background cadence, use a foreground service or accept >=15 min intervals.
class HealthSyncService {
  HealthSyncService._();
  static final HealthSyncService instance = HealthSyncService._();

  Timer? _timer;
  Duration _interval = const Duration(minutes: 1);
  bool _inFlight = false;

  bool get isRunning => _timer != null;
  Duration get interval => _interval;

  Future<void> start({Duration interval = const Duration(minutes: 1)}) async {
    _interval = interval;
    await _ensureConfigured();
    _timer?.cancel();
    _timer = Timer.periodic(_interval, (_) => _tick());
    // Kick an immediate sync on start
    // ignore: discarded_futures
    _tick();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  Future<void> _ensureConfigured() async {
    try {
      await HealthConnectService.instance.configure();
    } catch (e) {
      debugPrint('HealthSyncService configure error: $e');
    }
  }

  Future<void> _tick() async {
    if (_inFlight) return;
    if (FirebaseAuth.instance.currentUser == null) return;
    _inFlight = true;
    try {
      await HealthConnectService.instance.syncLatestHeartRate();
    } catch (e) {
      debugPrint('HealthSyncService tick error: $e');
    } finally {
      _inFlight = false;
    }
  }
}
