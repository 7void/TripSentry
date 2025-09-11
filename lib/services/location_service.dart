import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  static final LocationService _i = LocationService._();
  LocationService._();
  factory LocationService() => _i;

  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  late final FirebaseDatabase _rtdb = FirebaseDatabase.instanceFor(
    app: Firebase.app(),
    databaseURL: 'https://touristapp-2941f-default-rtdb.asia-southeast1.firebasedatabase.app',
  );

  StreamSubscription<User?>? _authSub;
  Timer? _timer;
  String? _uid;

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
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return;
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied || perm == LocationPermission.deniedForever) return;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 8), (_) => _update());
    await _update();
  }

  Future<void> _update() async {
    if (_uid == null) return;
    try {
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      await _rtdb.ref('liveLocations/$_uid').set({
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'timestamp': ServerValue.timestamp,
      });
      await _firestore.collection('users').doc(_uid!).set({
        'lastKnownLocation': {
          'lat': pos.latitude,
          'lng': pos.longitude,
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

  Future<void> dispose() async {
    _stop();
    await _authSub?.cancel();
    _authSub = null;
  }
}
