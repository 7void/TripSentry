import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class TestMapScreen extends StatefulWidget {
  const TestMapScreen({super.key});

  @override
  State<TestMapScreen> createState() => _TestMapScreenState();
}

class _TestMapScreenState extends State<TestMapScreen> {
  GoogleMapController? _mapController;

  static const LatLng _initialPosition = LatLng(37.4219999, -122.0840575); // Google HQ

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Google Maps Test")),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(
          target: _initialPosition,
          zoom: 14,
        ),
        onMapCreated: (controller) {
          setState(() {
            _mapController = controller;
          });
        },
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
      ),
    );
  }
}
