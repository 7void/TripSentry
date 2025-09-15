import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:geofence_service/geofence_service.dart' as gf;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/alert_service.dart';

class GeoFencingScreen extends StatefulWidget {
  const GeoFencingScreen({super.key});

  @override
  State<GeoFencingScreen> createState() => _GeoFencingScreenState();
}

class _GeoFencingScreenState extends State<GeoFencingScreen> {
  GoogleMapController? _mapController;
  LatLng _currentPosition = const LatLng(12.8447, 80.1537); // default start
  final Set<Marker> _markers = {};
  final Set<Circle> _circles = {};

  // Safe zones
  final List<LatLng> _safezones = [
    const LatLng(13.0827, 80.2707), // example
  ];

  // Unsafe zones (red)
  final List<LatLng> _unsafeZones = [
    const LatLng(12.844254, 80.151632),
  ];

  final double _geoFenceRadius = 115.0; // meters

  // Helper to standardize zone id formatting (prevents duplicates with differing string forms)
  String formatZoneId(LatLng zone) => 'zone_${zone.latitude.toStringAsFixed(6)}_${zone.longitude.toStringAsFixed(6)}';

  // Geofence service
  final gf.GeofenceService geofenceService = gf.GeofenceService.instance.setup(
    interval: 5000,
    accuracy: 100,
    loiteringDelayMs: 60000,
    statusChangeDelayMs: 10000,
    useActivityRecognition: false,
    allowMockLocations: false,
    printDevLog: true,
  );

  bool _soundEnabled = true;
  late SharedPreferences _prefs;
  StreamSubscription<geo.Position>? _positionSub;
  bool _disposed = false;

  // Notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    super.initState();
    _initNotifications();
    _loadPreferences();
    _checkPermissionAndStartTracking();
    _addGeofenceCircles();
    _startBackgroundGeofencing();
  }

  // 🔔 Init notifications
  Future<void> _initNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);

    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Load toggle state
  Future<void> _loadPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    _soundEnabled = _prefs.getBool('soundEnabled') ?? true;
    setState(() {});
  }

  Future<void> _saveSoundPreference(bool value) async {
    await _prefs.setBool('soundEnabled', value);
  }

  Future<void> _checkPermissionAndStartTracking() async {
    if (!await geo.Geolocator.isLocationServiceEnabled()) {
      return Future.error('Location services are disabled.');
    }

    geo.LocationPermission permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
      if (permission == geo.LocationPermission.denied) {
        return Future.error('Location permissions are denied');
      }
    }

    if (permission == geo.LocationPermission.deniedForever) {
      return Future.error('Location permissions are permanently denied.');
    }

    _positionSub?.cancel();
    _positionSub = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.high,
        distanceFilter: 5,
      ),
    ).listen((geo.Position position) {
      if (!mounted || _disposed) return;
      setState(() {
        _currentPosition = LatLng(position.latitude, position.longitude);
        _updateMarker();
      });
      if (!mounted || _disposed) return;
  _moveCameraToCurrentPosition();
  // Removed manual _checkUnsafeZones() to avoid duplicate alert creation; relying on geofence ENTER events.
    });
  }

  // Add red and green geofence circles
  void _addGeofenceCircles() {
    _circles.clear();
    for (var zone in _unsafeZones) {
      _circles.add(
        Circle(
          circleId: CircleId('unsafe_${zone.latitude}_${zone.longitude}'),
          center: zone,
          radius: _geoFenceRadius,
          fillColor: Colors.red.withOpacity(0.3),
          strokeColor: Colors.red,
          strokeWidth: 2,
        ),
      );
    }
    for (var safeZone in _safezones) {
      _circles.add(
        Circle(
          circleId: CircleId('safe_${safeZone.latitude}_${safeZone.longitude}'),
          center: safeZone,
          radius: _geoFenceRadius,
          fillColor: Colors.green.withOpacity(0.1),
          strokeColor: Colors.green,
          strokeWidth: 2,
        ),
      );
    }
  if (mounted && !_disposed) setState(() {});
  }

  void _updateMarker() {
    _markers.clear();
    _markers.add(
      Marker(
        markerId: const MarkerId('currentLocation'),
        position: _currentPosition,
        infoWindow: const InfoWindow(title: 'You are here'),
      ),
    );
  }

  void _moveCameraToCurrentPosition() {
    if (_mapController != null) {
      _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: _currentPosition, zoom: 16),
        ),
      );
    }
  }

  // Removed distance-based unsafe zone polling alert method (was _checkUnsafeZones) to ensure single source of truth.

  Future<void> _startBackgroundGeofencing() async {
    final status = await Permission.locationAlways.status;
    if (!status.isGranted) {
      await Permission.locationAlways.request();
    }

    if (await Permission.notification.isDenied) {
      await Permission.notification.request();
    }

    final List<gf.Geofence> geofenceList = [
  ..._unsafeZones.map((zone) => gf.Geofence(
    id: formatZoneId(zone),
            latitude: zone.latitude,
            longitude: zone.longitude,
            radius: [gf.GeofenceRadius(id: 'r1', length: _geoFenceRadius)],
          )),
      ..._safezones.map((zone) => gf.Geofence(
            id: zone.toString(),
            latitude: zone.latitude,
            longitude: zone.longitude,
            radius: [gf.GeofenceRadius(id: 'r1', length: _geoFenceRadius)],
          )),
    ];

    geofenceService.addGeofenceStatusChangeListener(
      (gf.Geofence geofence, gf.GeofenceRadius radius, gf.GeofenceStatus status, gf.Location location) async {
        // We treat only unsafe zones (those we created with id prefix 'zone_') as alert-producing.
        final bool isUnsafeZone = geofence.id.startsWith('zone_');
        if (status == gf.GeofenceStatus.ENTER) {
          if (isUnsafeZone) {
            await _showNotification("⚠️ Entered Unsafe Zone", "You entered ${geofence.id}");
            AlertService.instance.createGeofencingAlert(
              zoneId: geofence.id,
              latitude: location.latitude,
              longitude: location.longitude,
            );
          } else {
            // Optional: different notification for entering a safe zone (can be muted or removed later)
            await _showNotification("ℹ️ Entered Safe Zone", "You entered a designated safe area");
          }
        } else if (status == gf.GeofenceStatus.EXIT) {
          if (isUnsafeZone) {
            // Resolve the existing alert (if any) when the user leaves the unsafe zone so re-entry can trigger a fresh one.
            AlertService.instance.resolveGeofencingAlert(geofence.id);
            await _showNotification("✅ Left Unsafe Zone", "You exited ${geofence.id}");
          } else {
            await _showNotification("ℹ️ Left Safe Zone", "You left a safe area");
          }
        }
      },
    );



  // (kept older reference placeholder removed)
    try {
      await geofenceService.start(geofenceList);
      // After starting, immediately evaluate if current position already lies within any unsafe zone.
      await _evaluateInitialInside();
    } catch (e) {
      debugPrint('Start failed: $e');
    }
  }

  Future<void> _evaluateInitialInside() async {
    // If user is already inside an unsafe geofence when the service starts, ENTER may not fire.
    // We manually check distance once and create an alert if needed (without spamming duplicates).
    if (_unsafeZones.isEmpty) return;
    final pos = _currentPosition;
    for (final zone in _unsafeZones) {
      final distance = geo.Geolocator.distanceBetween(
        pos.latitude,
        pos.longitude,
        zone.latitude,
        zone.longitude,
      );
      if (distance <= _geoFenceRadius) {
        final zoneId = formatZoneId(zone);
        debugPrint('[Geofence] Already inside zone $zoneId at startup; creating alert if not existing.');
        AlertService.instance.createGeofencingAlert(
          zoneId: zoneId,
          latitude: pos.latitude,
          longitude: pos.longitude,
        );
        await _showNotification("⚠️ Geofence Alert", "You are inside ${zoneId}");
        break; // only handle first matching zone
      }
    }
  }

  Future<void> _showNotification(String title, String body) async {
    final androidDetails = AndroidNotificationDetails(
      'geofence_channel',
      'Geofence Alerts',
      channelDescription: 'Notifications for geofence events',
      importance: Importance.max,
      priority: Priority.high,
      playSound: _soundEnabled,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 500, 1000, 500]),
    );

    final iosDetails = DarwinNotificationDetails(
      presentSound: _soundEnabled,
      sound: _soundEnabled ? 'default' : null,
    );

    final platformDetails = NotificationDetails(android: androidDetails, iOS: iosDetails);

    await flutterLocalNotificationsPlugin.show(
      0,
      title,
      body,
      platformDetails,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Geo Fencing Map'),
        actions: [
          Row(
            children: [
              const Text("Sound"),
              Switch(
                value: _soundEnabled,
                onChanged: (val) {
                  _soundEnabled = val;
                  if (mounted && !_disposed) setState(() {});
                  _saveSoundPreference(val);
                },
              ),
            ],
          ),
        ],
      ),
      body: GoogleMap(
        initialCameraPosition: CameraPosition(target: _currentPosition, zoom: 16),
        markers: _markers,
        circles: _circles,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        onMapCreated: (GoogleMapController controller) {
          _mapController = controller;
          _moveCameraToCurrentPosition();
        },
        onLongPress: (position) {
          _safezones.add(position);
          _addGeofenceCircles();
          _startBackgroundGeofencing();
          if (mounted && !_disposed) setState(() {});
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Safe zone added!'), backgroundColor: Colors.green),
          );
        },
      ),
    );
  }

  @override
  void dispose() {
  _disposed = true;
    _positionSub?.cancel();
    geofenceService.stop();
    _mapController?.dispose();
    super.dispose();
  }
}
