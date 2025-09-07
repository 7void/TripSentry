import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'providers/blockchain_provider.dart';
import 'screens/splash_screen.dart';
import 'screens/wallet_setup_screen.dart';
import 'screens/home_screen.dart';
import 'screens/tourist_id_registration_screen.dart';
import 'screens/tourist_id_details_screen.dart';
import 'screens/error_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => BlockchainProvider()),
      ],
      child: MaterialApp(
        title: 'Tourist Safety App',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            foregroundColor: Colors.black,
          ),
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        home: const SplashScreen(),
        routes: {
          '/wallet-setup': (context) => const WalletSetupScreen(),
          '/home': (context) => const HomeScreen(),
          '/tourist-id-registration': (context) =>
              const TouristIDRegistrationScreen(),
          '/tourist-id-details': (context) => const TouristIDDetailsScreen(),
          '/error': (context) => const ErrorScreen(),
        },
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
