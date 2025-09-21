import 'dart:async';
import 'dart:io'
    show Platform; // platform check to avoid double tracking on Android
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
// removed realtime database imports
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _i = LocationService._();
  LocationService._();
  factory LocationService() => _i;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  // realtime database removed

  StreamSubscription<User?>? _authSub;
  Timer? _timer;
  String? _uid;
  bool _paused =
      false; // unified pause state (used mainly for non-Android platforms)

  void init() {
    _authSub ??= _auth.authStateChanges().listen((u) {
      if (u != null) {
        _uid = u.uid;
        _start();
      } else {
        _uid = null;
        _stop();
      }
    });
  }

  Future<void> _start() async {
    // On Android we rely on the native foreground service for continuous tracking.
    // Avoid starting a parallel Dart timer to prevent duplicate Firestore writes.
    if (Platform.isAndroid) return;
    if (_paused) return;
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      return;
    }
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _update());
    await _update();
  }

  Future<void> _update() async {
    if (_uid == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      await _firestore.collection('users').doc(_uid!).set({
        'lastKnownLocation': {
          'latitude': pos.latitude,
          'longitude': pos.longitude,
          'timestamp': FieldValue.serverTimestamp(),
        }
      }, SetOptions(merge: true));
    } catch (e) {
      // Minimal logging without prints in release; could integrate with existing logger if desired
    }
  }

  Future<void> forceUpdate() => _update();

  void _stop() {
    _timer?.cancel();
    _timer = null;
  }

  // Public control API (no-ops on Android because native service is authoritative)
  Future<void> pause() async {
    _paused = true;
    if (!Platform.isAndroid) {
      _stop();
    }
  }

  Future<void> resume() async {
    if (!_paused) return;
    _paused = false;
    if (!Platform.isAndroid) {
      await _start();
    }
  }

  Future<void> dispose() async {
    _stop();
    await _authSub?.cancel();
    _authSub = null;
  }
}
