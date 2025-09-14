import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';
import '../providers/blockchain_provider.dart';
import '../services/location_service_helper.dart';
import '../utils/permission_utils.dart'; // ✅ added import

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Wait a bit for splash effect
    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        Navigator.of(context).pushReplacementNamed('/login');
        return;
      }

      // ✅ Request permissions before starting service
      final granted = await PermissionUtils.requestLocationPermissions();
      if (granted) {
        await LocationServiceHelper.startServiceIfAllowed();
      }

      // Initialize other services
      final blockchainProvider =
          Provider.of<BlockchainProvider>(context, listen: false);
      await blockchainProvider.initialize();

      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (e, st) {
      // Log error and navigate to an error/fallback screen
      debugPrint('Error during app initialization: $e\n$st');
      if (!mounted) return;
      Navigator.of(context).pushReplacementNamed('/error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
