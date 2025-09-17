import 'dart:async';

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../services/alert_service.dart';

class EmergencyCountdownScreen extends StatefulWidget {
  const EmergencyCountdownScreen({super.key});

  @override
  State<EmergencyCountdownScreen> createState() => _EmergencyCountdownScreenState();
}

class _EmergencyCountdownScreenState extends State<EmergencyCountdownScreen> {
  static const int _initialSeconds = 10;
  int _secondsLeft = _initialSeconds;
  Timer? _timer;
  bool _sent = false;
  bool _loadingLocation = true;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _primeLocation();
    _startTimer();
  }

  Future<void> _primeLocation() async {
    try {
      // Check and request permissions gracefully; we assume app already handles permissions broadly.
      LocationPermission perm = await Geolocator.checkPermission();
      if (perm == LocationPermission.denied) {
        perm = await Geolocator.requestPermission();
      }
      if (perm == LocationPermission.deniedForever || perm == LocationPermission.denied) {
        setState(() => _loadingLocation = false);
        return;
      }
      final enabled = await Geolocator.isLocationServiceEnabled();
      if (!enabled) {
        setState(() => _loadingLocation = false);
        return;
      }
      final pos = await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
      if (!mounted) return;
      setState(() {
        _lat = pos.latitude;
        _lng = pos.longitude;
        _loadingLocation = false;
      });
    } catch (_) {
      if (mounted) setState(() => _loadingLocation = false);
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (!mounted) return;
      if (_secondsLeft <= 1) {
        t.cancel();
        await _sendSOS();
        return;
      }
      setState(() {
        _secondsLeft--;
      });
    });
  }

  Future<void> _sendSOS() async {
    if (_sent) return;
    _sent = true;
    try {
      await AlertService.instance.createEmergencyAlert(
        latitude: _lat,
        longitude: _lng,
        extra: {
          'source': 'manual',
        },
      );
    } finally {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Emergency SOS sent')), 
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  void _cancel() {
    _timer?.cancel();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Emergency SOS'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'sending emergency sos in',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                '$_secondsLeft',
                style: Theme.of(context).textTheme.displayLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 24),
              if (_loadingLocation)
                const Padding(
                  padding: EdgeInsets.only(bottom: 8.0),
                  child: Text('Fetching current location...'),
                )
              else if (_lat != null && _lng != null)
                Text('Location: ${_lat!.toStringAsFixed(5)}, ${_lng!.toStringAsFixed(5)}',
                    style: Theme.of(context).textTheme.bodyMedium),
              const SizedBox(height: 32),
              FilledButton.tonalIcon(
                onPressed: _cancel,
                icon: const Icon(Icons.cancel),
                label: const Text('Cancel'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.red.shade700,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
