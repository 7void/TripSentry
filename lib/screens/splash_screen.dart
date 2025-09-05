import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/blockchain_provider.dart';

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
    final blockchainProvider = Provider.of<BlockchainProvider>(context, listen: false);

    try {
      // Initialize blockchain services
      await blockchainProvider.initialize();

      // Wait a bit for splash effect
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted) return;

      // Check if wallet exists
      if (blockchainProvider.wallet != null) {
        // Wallet exists, go to home
        Navigator.of(context).pushReplacementNamed('/home');
      } else {
        // No wallet, show wallet setup
        Navigator.of(context).pushReplacementNamed('/wallet-setup');
      }
    } catch (e, st) {
      // Log error and navigate to an error/fallback screen (adjust as needed)
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
